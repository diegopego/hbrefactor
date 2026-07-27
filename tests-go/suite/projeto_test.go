package suite

import (
	"encoding/json"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// Projeto é a source/ de um caso copiada para um tmp, e a ferramenta rodando
// sobre ela.
type Projeto struct {
	t        *testing.T
	art, dir string
	// o envelope TIPADO, para o caso afirmar sobre ele com o compilador junto
	envelopes []Envelope
	// e o mesmo envelope CRU, para a comparação: decodificar no tipo descarta
	// campo que o tipo não conhece, e é justamente o campo novo e não previsto
	// que a comparação precisa pegar
	relatado []any
	// o que ESTE caso declara que a ferramenta cria (§5)
	cria []string
}

func novo(t *testing.T, nome string) *Projeto {
	art := filepath.Join("testdata", nome)
	dir := filepath.Join(t.TempDir(), "proj")
	copia(t, filepath.Join(art, "source"), dir)
	return &Projeto{t: t, art: art, dir: dir}
}

// O build do Harbour deixa o seu diretório incremental onde compila — o build
// do próprio usuário faz igual, e é por isso que ele está no .gitignore. Não é
// a ferramenta sujando o projeto: é o toolchain sendo o toolchain. Fica AQUI, e
// não declarado por caso, senão 148 casos repetiriam um fato sobre o hbmk2.
var lixoDeBuild = []string{".hbmk/"}

// Cria declara um artefato que ESTE caso espera ver no projeto (§5) — um
// arquivo que a FERRAMENTA cria e o caso afirma. Fica no caso, não no harness.
func (p *Projeto) Cria(prefixos ...string) { p.cria = append(p.cria, prefixos...) }

func (p *Projeto) declarado(nome string) bool {
	for _, pre := range append(lixoDeBuild, p.cria...) {
		if nome == pre || strings.HasPrefix(nome, pre) {
			return true
		}
	}
	return false
}

// Roda invoca a ferramenta e confere as invariantes de TODA invocação (§4)
// AQUI — no funil por onde toda chamada passa, e não numa lista que o caso
// percorre depois.
func (p *Projeto) Roda(argv ...string) Envelope {
	p.t.Helper()
	for _, a := range argv {
		if a == "--json" {
			p.t.Fatal("`--json` é implícito: o passo 3 da fase A.1 arranca a flag, " +
				"e o caso testa o que vai sobreviver")
		}
	}
	cmd := exec.Command(binario(p.t), append(argv, "--json")...)
	cmd.Dir = p.dir
	var saida, erro strings.Builder
	cmd.Stdout, cmd.Stderr = &saida, &erro
	_ = cmd.Run()
	exit := cmd.ProcessState.ExitCode()
	texto := p.normaliza(saida.String())

	if s := erro.String(); strings.TrimSpace(s) != "" {
		p.t.Fatalf("stderr não está vazio (aviso é diagnostics[] no envelope):\n%s", s)
	}
	corpo := strings.TrimRight(texto, "\n")
	if !strings.HasPrefix(corpo, "{") || !strings.HasSuffix(corpo, "}") {
		p.t.Fatalf("o stdout tem algo além do envelope:\n%.400s", texto)
	}
	if texto != corpo+"\n" {
		p.t.Fatalf("o stdout tem %d newline(s) no fim — o contrato é UM envelope e uma quebra de linha",
			len(texto)-len(corpo))
	}

	var env Envelope
	if err := json.Unmarshal([]byte(texto), &env); err != nil {
		p.t.Fatalf("envelope ilegível: %v", err)
	}
	var cru any
	if err := json.Unmarshal([]byte(texto), &cru); err != nil {
		p.t.Fatalf("envelope ilegível: %v", err)
	}
	if env.Exit != exit {
		p.t.Errorf("o processo saiu %d e o envelope diz exit=%d", exit, env.Exit)
	}
	p.envelopes = append(p.envelopes, env)
	p.relatado = append(p.relatado, cru)
	return env
}

// <CWD> e <CORE> são o que varia legitimamente de máquina para máquina.
func (p *Projeto) normaliza(txt string) string {
	txt = strings.ReplaceAll(txt, p.dir, "<CWD>")
	return strings.ReplaceAll(txt, core(p.t), "<CORE>")
}

func (p *Projeto) esperados(t *testing.T) []any {
	b, err := os.ReadFile(filepath.Join(p.art, "outputs.json"))
	if err != nil {
		t.Fatalf("sem outputs.json: %v", err)
	}
	var esperados []any
	if err := json.Unmarshal(b, &esperados); err != nil {
		t.Fatalf("outputs.json ilegível: %v", err)
	}
	for i, env := range esperados {
		h, ok := env.(map[string]any)
		if !ok {
			t.Fatalf("outputs.json[%d] não é um envelope", i)
		}
		// `unclassified` é o que a ferramenta emite quando a recusa NÃO tem
		// código. Congelá-lo no esperado transforma um buraco da ferramenta em
		// contrato - e é o campo pelo qual a IDE e o agente decidem o que fazer.
		// O código NASCE neste caso; é aqui que a migração paga.
		if h["reason"] == "unclassified" {
			t.Fatalf("outputs.json[%d] congela reason \"unclassified\": classifique a "+
				"recusa em src/hbrefactor.prg (#define RSN_*) e use o código novo", i)
		}
	}
	return esperados
}

// arvore lê uma árvore inteira, subdiretório inclusive: o caminho relativo é a
// chave, então arquivo em subpasta não some calado da comparação.
func arvore(t *testing.T, raiz string) map[string]string {
	t.Helper()
	fsys := os.DirFS(raiz)
	m := map[string]string{}
	err := fs.WalkDir(fsys, ".", func(caminho string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		b, err := fs.ReadFile(fsys, caminho)
		if err != nil {
			return err
		}
		m[caminho] = string(b)
		return nil
	})
	if err != nil {
		t.Fatalf("lendo %s: %v", raiz, err)
	}
	return m
}

// copia uma árvore SOBREPONDO o que já existe — é assim que expected/ entra por
// cima de source/. (O os.CopyFS da stdlib recusa destino existente.)
func copia(t *testing.T, origem, destino string) {
	t.Helper()
	fsys := os.DirFS(origem)
	err := fs.WalkDir(fsys, ".", func(caminho string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		alvo := filepath.Join(destino, caminho)
		if d.IsDir() {
			return os.MkdirAll(alvo, 0o755)
		}
		b, err := fs.ReadFile(fsys, caminho)
		if err != nil {
			return err
		}
		return os.WriteFile(alvo, b, 0o644)
	})
	if err != nil {
		t.Fatalf("copiando %s: %v", origem, err)
	}
}

// -- onde as coisas estão. Falta variável? O teste FALHA nomeando-a, nunca cai
// num binário do sistema — o sintoma disso é o enganoso "o projeto não compila".
func hbBin(t *testing.T) string {
	t.Helper()
	v := os.Getenv("HB_BIN")
	if v == "" {
		t.Fatal("HB_BIN não definido — aponte para os binários do harbour-core")
	}
	return v
}

func core(t *testing.T) string {
	return filepath.Dir(filepath.Dir(filepath.Dir(hbBin(t))))
}

func binario(t *testing.T) string {
	t.Helper()
	if v := os.Getenv("BIN"); v != "" {
		return v
	}
	abs, err := filepath.Abs(filepath.Join("..", "..", "bin", "hbrefactor"))
	if err != nil {
		t.Fatal(err)
	}
	return abs
}
