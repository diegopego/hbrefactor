package suite

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

// ast-22 — PROCEDÊNCIA: o dump declara de que arquivos foi feito.
//
// Este teste olha o DUMP, não a ferramenta, e é de propósito: a procedência é
// fato do core, e é sobre ela que a fase W.3 vai decidir se um dump ainda serve.
// Se o core parar de emitir (ou emitir errado), quem consumir vai concluir que
// um dump velho corresponde ao fonte — e "agiu sobre fato velho" é o único
// defeito que esta ferramenta promete nunca ter. O portão fica aqui, junto do
// resto do `make test`, e não numa verificação manual que ninguém repete.

type provenancia struct {
	Sum   string `json:"sum"`
	Files []struct {
		Path       string `json:"path"`
		Size       int64  `json:"size"`
		Sum        string `json:"sum"`
		Unreadable bool   `json:"unreadable"`
	} `json:"files"`
	Defines []struct {
		Name  string `json:"name"`
		Value string `json:"value"`
	} `json:"defines"`
}

// fnv1a64 é a MESMA conta que o compilador faz (compast.c, hb_compAstFileSum).
// Reimplementada aqui de propósito: se o core mudar de algoritmo sem mudar o
// campo "sum", este teste falha — que é exatamente o aviso que se quer.
func fnv1a64(t *testing.T, caminho string) string {
	t.Helper()
	b, err := os.ReadFile(caminho)
	if err != nil {
		t.Fatal(err)
	}
	h := uint64(14695981039346656037)
	for _, c := range b {
		h ^= uint64(c)
		h *= 1099511628211
	}
	const hexa = "0123456789abcdef"
	out := make([]byte, 16)
	for i := 15; i >= 0; i-- {
		out[i] = hexa[h&0xf]
		h >>= 4
	}
	return string(out)
}

// projetoProv monta um módulo com include TRANSITIVO (a.ch puxa b.ch) e um
// include que só entra sob -D — as duas formas em que uma lista ingênua erra.
func projetoProv(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	arquivos := map[string]string{
		"b.ch": "#define B_OK 1\n",
		"a.ch": "#include \"b.ch\"\n#xtranslate SAUDA( <x> ) => \"oi \" + <x>\n",
		"c.ch": "#define SO_COM_D 1\n",
		"m.prg": "#include \"a.ch\"\n" +
			"#ifdef LIGA_C\n   #include \"c.ch\"\n#endif\n\n" +
			"FUNCTION F( nV )\n\n   RETURN SAUDA( hb_ntos( nV + B_OK ) )\n",
	}
	for nome, texto := range arquivos {
		if err := os.WriteFile(filepath.Join(dir, nome), []byte(texto), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	return dir
}

func dumpa(t *testing.T, dir string, flags ...string) provenancia {
	t.Helper()
	saidaDir := filepath.Join(dir, "dump")
	if err := os.MkdirAll(saidaDir, 0o755); err != nil {
		t.Fatal(err)
	}
	args := append([]string{"m.prg", "-n2", "-q0", "-i" + dir,
		"-x" + saidaDir + string(os.PathSeparator), "-o" + saidaDir + string(os.PathSeparator)}, flags...)
	cmd := exec.Command(filepath.Join(hbBin(t), "harbour"), args...)
	cmd.Dir = dir
	if saida, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("harbour falhou: %v\n%s", err, saida)
	}
	b, err := os.ReadFile(filepath.Join(saidaDir, "m.ast.json"))
	if err != nil {
		t.Fatal(err)
	}
	var d struct {
		Schema     string      `json:"schema"`
		Provenance provenancia `json:"provenance"`
	}
	if err := json.Unmarshal(b, &d); err != nil {
		t.Fatal(err)
	}
	if len(d.Provenance.Files) == 0 {
		t.Fatalf("o dump não trouxe procedência (schema %q) — sem ela, um dump "+
			"velho é indistinguível de um atual", d.Schema)
	}
	return d.Provenance
}

func caminhos(p provenancia) []string {
	var out []string
	for _, f := range p.Files {
		out = append(out, f.Path)
	}
	return out
}

// A lista tem de ser a que o compilador leu de fato: com o include transitivo
// e SEM o que a compilação condicional não tomou. Uma lista que erre para menos
// deixa passar mudança que importa; para mais, invalida dump à toa.
func TestProcedenciaListaOsArquivosQueOCompiladorLeu(t *testing.T) {
	dir := projetoProv(t)

	p := dumpa(t, dir)
	quero := []string{"m.prg", "a.ch", "b.ch"}
	if got := caminhos(p); len(got) != len(quero) {
		t.Fatalf("arquivos = %v, quero %v (transitivo dentro, não-tomado fora)", got, quero)
	} else {
		for i := range quero {
			if got[i] != quero[i] {
				t.Errorf("arquivos = %v, quero %v", got, quero)
				break
			}
		}
	}
	if p.Sum != "fnv1a64" {
		t.Errorf("sum = %q — o algoritmo tem de vir NOMEADO, senão quem compara adivinha", p.Sum)
	}
	for _, f := range p.Files {
		if f.Unreadable {
			t.Errorf("%s veio como unreadable", f.Path)
			continue
		}
		if q := fnv1a64(t, filepath.Join(dir, f.Path)); f.Sum != q {
			t.Errorf("%s: sum %q, calculado %q", f.Path, f.Sum, q)
		}
	}

	// o mesmo fonte com -D toma o include condicional E registra o define:
	// identidade é {arquivos + conteúdo + flags}, nunca só o conteúdo
	pd := dumpa(t, dir, "-DLIGA_C")
	if got := caminhos(pd); len(got) != 4 || got[3] != "c.ch" {
		t.Errorf("com -DLIGA_C arquivos = %v, quero c.ch incluído", got)
	}
	if len(pd.Defines) != 1 || pd.Defines[0].Name != "LIGA_C" {
		t.Errorf("defines = %v, quero LIGA_C", pd.Defines)
	}
}

// O CASO QUE MOTIVOU A FASE: editar no mesmo segundo em que o módulo foi
// compilado é invisível para quem decide por timestamp (a comparação do build
// incremental tem resolução de ~1 s — medido). A procedência tem de pegar,
// COM O MTIME IDÊNTICO, senão ela não resolveu nada.
func TestProcedenciaPegaEdicaoComMtimeIdentico(t *testing.T) {
	dir := projetoProv(t)
	alvo := filepath.Join(dir, "b.ch")

	p := dumpa(t, dir)
	var gravado string
	for _, f := range p.Files {
		if f.Path == "b.ch" {
			gravado = f.Sum
		}
	}
	if gravado == "" {
		t.Fatal("b.ch não está na procedência")
	}

	fi, err := os.Stat(alvo)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(alvo, []byte("#define B_OK 2\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	// devolve o mtime EXATO de antes: é isto que engana quem decide pelo relógio
	if err := os.Chtimes(alvo, fi.ModTime(), fi.ModTime()); err != nil {
		t.Fatal(err)
	}
	depois, err := os.Stat(alvo)
	if err != nil {
		t.Fatal(err)
	}
	if !depois.ModTime().Equal(fi.ModTime()) {
		t.Fatalf("o teste não conseguiu preservar o mtime — sem isso ele não prova nada")
	}

	if agora := fnv1a64(t, alvo); agora == gravado {
		t.Error("o conteúdo mudou e o checksum não — a procedência diria que o dump " +
			"ainda serve, que é exatamente o defeito que a fase X existe para matar")
	}
}
