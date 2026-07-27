package suite

import (
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"testing"

	"github.com/google/go-cmp/cmp"
)

// As propriedades da FIXTURE (§7): verdades sobre o testdata/, não sobre um
// comando. Ficam como subtestes DO CASO, então rodar um caso sozinho já traz a
// rede junto.
func fixture(t *testing.T, nome string) {
	art := filepath.Join("testdata", nome)

	// 1. o estado AFIRMADO compila: source/ com expected/ por cima. Compila o
	// que EU escrevi, nunca o que a ferramenta produziu — é a rede que impede
	// "consertar" o esperado copiando a saída.
	t.Run("compila", func(t *testing.T) {
		dir := t.TempDir()
		for _, sub := range []string{"source", "expected"} {
			copia(t, filepath.Join(art, sub), dir) // expected/ POR CIMA de source/
		}
		harbour(t, dir, "-w3", "-es2", "-s")
	})

	// 2. a régua do caso 64: capacidade sobre uma DSL só conta como genérica se
	// o fonte da ferramenta não conhece as palavras da fixture.
	t.Run("vocabulário", func(t *testing.T) {
		fonte, err := os.ReadFile(filepath.Join("..", "..", "src", "hbrefactor.prg"))
		if err != nil {
			t.Fatal(err)
		}
		chs, _ := filepath.Glob(filepath.Join(art, "source", "*.ch"))
		for _, ch := range chs {
			b, err := os.ReadFile(ch)
			if err != nil {
				t.Fatal(err)
			}
			for _, m := range diretiva.FindAllStringSubmatch(string(b), -1) {
				palavra := m[3]
				if regexp.MustCompile(`(?i)\b` + regexp.QuoteMeta(palavra) + `\b`).Match(fonte) {
					t.Errorf("a palavra %q, da fixture, aparece em src/hbrefactor.prg", palavra)
				}
			}
		}
	})

	// 3. o retrato do core (§6): rastreia uma dependência EXTERNA — mexeu no pp
	// e o caso mostra o diff. Comparar e regravar pelo mesmo caminho.
	t.Run("retrato", func(t *testing.T) {
		gerado := retratoDoCore(t, art)
		alvo := filepath.Join(art, "oracle")
		if *update {
			if err := os.RemoveAll(alvo); err != nil {
				t.Fatal(err)
			}
			if err := os.MkdirAll(alvo, 0o755); err != nil {
				t.Fatal(err)
			}
			for nome, txt := range gerado {
				if err := os.WriteFile(filepath.Join(alvo, nome), []byte(txt), 0o644); err != nil {
					t.Fatal(err)
				}
			}
			t.Logf("retrato gravado: %d arquivo(s)", len(gerado))
			return
		}
		if _, err := os.Stat(alvo); err != nil {
			t.Fatalf("caso sem oracle/: rode `make oracle NOME=%s`, e LEIA o que o "+
				"core produziu — é ali que a lacuna dele aparece", nome)
		}
		if d := cmp.Diff(arvore(t, alvo), gerado, porLinha); d != "" {
			t.Errorf("o .ppo/.ppt do core mudou (-guardado +agora):\n%s", d)
		}
	})
}

// o grupo 1 é o `x` da família exata, o 2 é command/translate, o 3 é a CABEÇA —
// que é o que não pode vazar para o fonte da ferramenta
var diretiva = regexp.MustCompile(`(?im)^\s*#(x?)(command|translate)\s+([A-Za-z_]\w*)`)

// retratoDoCore: .ppo (no que o código vira) e .ppt (o que o pp fez, linha a
// linha) de cada módulo da source/.
func retratoDoCore(t *testing.T, art string) map[string]string {
	t.Helper()
	dir := t.TempDir()
	copia(t, filepath.Join(art, "source"), dir)
	harbour(t, dir, "-s", "-p", "-p+")
	retrato := map[string]string{}
	for nome, txt := range arvore(t, dir) {
		if ext := filepath.Ext(nome); ext == ".ppo" || ext == ".ppt" {
			retrato[nome] = txt
		}
	}
	if len(retrato) == 0 {
		t.Fatal("o compilador não emitiu .ppo/.ppt nenhum")
	}
	return retrato
}

func harbour(t *testing.T, dir string, flags ...string) {
	t.Helper()
	prgs, _ := filepath.Glob(filepath.Join(dir, "*.prg"))
	for _, prg := range prgs {
		args := append([]string{filepath.Base(prg), "-n", "-q0"}, flags...)
		args = append(args, "-I"+dir, "-I"+filepath.Join(core(t), "include"))
		cmd := exec.Command(filepath.Join(hbBin(t), "harbour"), args...)
		cmd.Dir = dir
		if saida, err := cmd.CombinedOutput(); err != nil {
			t.Errorf("%s não compila limpo:\n%s", filepath.Base(prg), saida)
		}
	}
}
