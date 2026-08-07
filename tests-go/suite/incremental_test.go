// W.3 — o trabalho é reaproveitado, e NUNCA sobre fato velho.
//
// A fatia troca "regerar todo dump a cada comando" por "regerar o que não
// corresponde mais". O ganho é real mas modesto (medido no corpus: ~1,6x num
// projeto de 42 módulos, porque a geração é ~35% do custo de um `usages` — a
// fatia 1 da fase V já dizia isso); o RISCO é que não tem tamanho: um dump
// reaproveitado quando não devia faz a ferramenta decidir sobre um programa que
// não existe mais, e é o único defeito que ela promete nunca ter.
//
// Por isso o que este arquivo cobra não é velocidade — é que o reaproveitamento
// seja indistinguível de refazer tudo, inclusive nos casos em que o incremental
// do builder erra sozinho.
package suite

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func projetoInc(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	arq := map[string]string{
		"c.ch":     "#xtranslate SAUDA( <x> ) => \"oi \" + <x>\n",
		"a.prg":    "#include \"c.ch\"\n\nFUNCTION Alfa( n )\n\n   RETURN SAUDA( hb_ntos( n + 1 ) )\n",
		"b.prg":    "#include \"c.ch\"\n\nFUNCTION Beta( n )\n\n   RETURN SAUDA( hb_ntos( n + 2 ) )\n",
		"main.prg": "PROCEDURE Main()\n\n   ? Alfa( 1 ), Beta( 2 )\n\n   RETURN\n",
		"p.hbp":    "-i.\nmain.prg\na.prg\nb.prg\n",
	}
	for nome, texto := range arq {
		if err := os.WriteFile(filepath.Join(dir, nome), []byte(texto), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	return dir
}

func rodaInc(t *testing.T, dir string, argv ...string) string {
	t.Helper()
	cmd := exec.Command(binario(t), argv...)
	cmd.Dir = dir
	saida, _ := cmd.CombinedOutput()
	return string(saida)
}

// O resultado com trabalho reaproveitado tem de ser o MESMO de quando não há
// nada reaproveitável. Se divergir, o reaproveitamento está mentindo - e como
// ele é invisível para quem chama, ninguém perceberia sem este confronto.
func TestIncrementalNaoMudaOResultado(t *testing.T) {
	dir := projetoInc(t)

	primeira := rodaInc(t, dir, "usages", "p.hbp", "Alfa") // gera tudo
	segunda := rodaInc(t, dir, "usages", "p.hbp", "Alfa")  // reaproveita
	if primeira != segunda {
		t.Errorf("o resultado mudou ao reaproveitar:\n--- primeira:\n%s\n--- segunda:\n%s",
			primeira, segunda)
	}
	if !strings.Contains(primeira, "Alfa") {
		t.Fatalf("o comando nem respondeu sobre Alfa:\n%s", primeira)
	}
}

// O CASO QUE MOTIVOU A FASE X, agora ponta a ponta: editar dentro do mesmo
// segundo em que o módulo foi compilado é invisível para quem decide por
// timestamp. Aqui o mtime é devolvido byte a byte ao valor anterior, que é o
// pior caso possível - e a resposta ainda tem de refletir a edição.
func TestIncrementalVeEdicaoComMtimeIdentico(t *testing.T) {
	dir := projetoInc(t)
	alvo := filepath.Join(dir, "b.prg")

	rodaInc(t, dir, "usages", "p.hbp", "Beta") // popula o trabalho

	fi, err := os.Stat(alvo)
	if err != nil {
		t.Fatal(err)
	}
	novo := "#include \"c.ch\"\n\nFUNCTION BetaRenomeada( n )\n\n   RETURN SAUDA( hb_ntos( n + 2 ) )\n"
	if err := os.WriteFile(alvo, []byte(novo), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Chtimes(alvo, fi.ModTime(), fi.ModTime()); err != nil {
		t.Fatal(err)
	}
	if depois, _ := os.Stat(alvo); !depois.ModTime().Equal(fi.ModTime()) {
		t.Fatal("o teste não conseguiu preservar o mtime — sem isso ele não prova nada")
	}

	saida := rodaInc(t, dir, "usages", "p.hbp", "BetaRenomeada")
	if !strings.Contains(saida, "b.prg") {
		t.Errorf("a edição com mtime idêntico ficou invisível — a ferramenta "+
			"respondeu sobre o programa ANTERIOR:\n%s", saida)
	}
}

// Apagar um dump é o segundo caso que o incremental do builder não vê (ele
// decide sobre o .c). Acontece a cada limpeza de temporário, e tem de se
// resolver sozinho.
func TestIncrementalRefazDumpApagado(t *testing.T) {
	dir := projetoInc(t)

	saida := rodaInc(t, dir, "dump", "p.hbp")
	var work string
	for _, l := range strings.Split(saida, "\n") {
		if i := strings.Index(l, "dumps em: "); i >= 0 {
			work = strings.TrimSpace(l[i+len("dumps em: "):])
		}
	}
	if work == "" {
		t.Fatalf("o comando dump não disse onde escreveu:\n%s", saida)
	}
	alvo := filepath.Join(work, "a.ast.json")
	if _, err := os.Stat(alvo); err != nil {
		t.Fatalf("dump não está onde o comando disse: %v", err)
	}
	if err := os.Remove(alvo); err != nil {
		t.Fatal(err)
	}

	if out := rodaInc(t, dir, "usages", "p.hbp", "Alfa"); !strings.Contains(out, "Alfa") {
		t.Errorf("com um dump apagado a resposta se perdeu:\n%s", out)
	}
	if _, err := os.Stat(alvo); err != nil {
		t.Errorf("o dump apagado não voltou: %v", err)
	}
}

// O dump é função do fonte E das flags: o mesmo módulo sob outra flag produz
// outro dump. Trocar a flag e receber a resposta da flag anterior é fato velho
// com outra roupa.
func TestIncrementalNaoReusaEntreFlagsDiferentes(t *testing.T) {
	dir := projetoInc(t)
	hbp := filepath.Join(dir, "p.hbp")

	rodaInc(t, dir, "usages", "p.hbp", "Alfa")

	b, err := os.ReadFile(hbp)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(hbp, append(b, []byte("-DHBREF_MARCA=1\n")...), 0o644); err != nil {
		t.Fatal(err)
	}

	// o dump da compilação COM -D não pode ser o mesmo objeto da de antes dela;
	// o teste olha o efeito observável: o diretório de trabalho muda de lugar
	d1 := rodaInc(t, dir, "dump", "p.hbp")
	os.WriteFile(hbp, b, 0o644)
	d2 := rodaInc(t, dir, "dump", "p.hbp")
	dir1, dir2 := linhaDumpsEm(d1), linhaDumpsEm(d2)
	if dir1 == "" || dir2 == "" {
		t.Fatalf("o comando dump não disse onde escreveu:\n%s\n%s", d1, d2)
	}
	if dir1 == dir2 {
		t.Errorf("projetos com flags diferentes compartilham o mesmo trabalho (%s) — "+
			"o dump depende das flags, então reusar entre elas é responder pelo "+
			"mundo anterior", dir1)
	}
}

func linhaDumpsEm(saida string) string {
	for _, l := range strings.Split(saida, "\n") {
		if i := strings.Index(l, "dumps em: "); i >= 0 {
			return strings.TrimSpace(l[i+len("dumps em: "):])
		}
	}
	return ""
}
