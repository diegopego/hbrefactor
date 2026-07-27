// Os documentos que ENSINAM o loop de teste citam comando que existe?
//
// Por que isto é código, e por que em Go: em 2026-07-26 a classe A trocou de
// formato e a skill migrate-test seguiu ensinando `tools/scen-new.sh` e
// `make scenarios` depois de os dois morrerem — quem a seguisse rodaria um
// comando inexistente e concluiria que o REPO estava quebrado. O erro foi pego
// à mão. A primeira versão desta guarda foi em bash, e tinha o defeito clássico
// dela: se o regex parasse de casar, a guarda passava VERDE, calada.
//
// Aqui o extrator é uma função pura com teste próprio (TestExtrai). Se o regex
// quebrar, é esse teste que falha — e não a guarda que emudece.
//
// O que ele NÃO faz, de propósito: julgar se a prosa está certa. Só verifica
// que o que ela manda RODAR existe — a parte mecânica, a única decidível sem
// interpretar.
package docs

import (
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"testing"

	"github.com/google/go-cmp/cmp"
)

// Doc que manda rodar coisas. Doc que só descreve não entra.
var docsDoLoop = []string{
	"tests/README.md",
	".claude/skills/migrate-test/SKILL.md",
}

type Citacao struct {
	Tipo string // "script" | "make" | "caminho"
	Ref  string
}

var (
	reScript = regexp.MustCompile(`tools/[A-Za-z0-9_.-]+\.(?:sh|py)`)
	reMake   = regexp.MustCompile(`\bmake ([a-z][a-z-]*)`)
	// caminho do repo entre crases. O molde (`<nome>`) não casa por construção:
	// `<` está fora da classe, então a crase de fechamento não chega.
	reCaminho = regexp.MustCompile("`((?:tests|tests-go|src|tools|docs)/[A-Za-z0-9_./-]*)`")
)

// Extrai devolve, ordenado e sem repetição, o que o texto manda rodar.
func Extrai(texto string) []Citacao {
	vistas := map[Citacao]bool{}
	for _, m := range reScript.FindAllString(texto, -1) {
		vistas[Citacao{"script", m}] = true
	}
	for _, m := range reMake.FindAllStringSubmatch(texto, -1) {
		vistas[Citacao{"make", m[1]}] = true
	}
	for _, m := range reCaminho.FindAllStringSubmatch(texto, -1) {
		vistas[Citacao{"caminho", strings.TrimSuffix(m[1], "/")}] = true
	}
	fora := make([]Citacao, 0, len(vistas))
	for c := range vistas {
		fora = append(fora, c)
	}
	sort.Slice(fora, func(i, j int) bool {
		if fora[i].Tipo != fora[j].Tipo {
			return fora[i].Tipo < fora[j].Tipo
		}
		return fora[i].Ref < fora[j].Ref
	})
	return fora
}

// O CONTROLE NEGATIVO do extrator, e a razão de esta guarda não ser bash: uma
// guarda cujo extrator emudece passa verde sem verificar nada. Aqui, se o regex
// parar de casar, ESTE teste falha — e ele não depende do conteúdo dos
// documentos reais, que mudam a cada sessão.
func TestExtrai(t *testing.T) {
	const amostra = "rode `tools/caso-new.sh <nome>` e depois make caso NOME=x.\n" +
		"o contrato é `tests/README.md`; a suíte vive em `tests-go/suite/`.\n" +
		"o molde `tests-go/suite/<nome>_test.go` NÃO é citação, e `tests/*.prg` também não.\n" +
		"make test roda tudo; make test de novo não duplica.\n"

	quero := []Citacao{
		{"caminho", "tests-go/suite"},
		{"caminho", "tests/README.md"},
		{"make", "caso"},
		{"make", "test"},
		{"script", "tools/caso-new.sh"},
	}
	if d := cmp.Diff(quero, Extrai(amostra)); d != "" {
		t.Errorf("o extrator mudou de comportamento (-quero +tenho):\n%s", d)
	}
}

func TestDocsCitamSoOQueExiste(t *testing.T) {
	raiz := raiz(t)
	alvos := alvosDoMakefile(t, raiz)

	for _, doc := range docsDoLoop {
		t.Run(doc, func(t *testing.T) {
			b, err := os.ReadFile(filepath.Join(raiz, doc))
			if err != nil {
				t.Fatalf("documento do loop ilegível: %v", err)
			}
			for _, c := range Extrai(string(b)) {
				switch c.Tipo {
				case "make":
					if !alvos[c.Ref] {
						t.Errorf("cita `make %s`, que não é alvo do Makefile", c.Ref)
					}
				default:
					if _, err := os.Stat(filepath.Join(raiz, c.Ref)); err != nil {
						t.Errorf("cita %q, que não existe", c.Ref)
					}
				}
			}
		})
	}
}

var reAlvo = regexp.MustCompile(`(?m)^([a-zA-Z][a-zA-Z0-9_-]*):`)

func alvosDoMakefile(t *testing.T, raiz string) map[string]bool {
	t.Helper()
	b, err := os.ReadFile(filepath.Join(raiz, "Makefile"))
	if err != nil {
		t.Fatal(err)
	}
	alvos := map[string]bool{}
	for _, m := range reAlvo.FindAllStringSubmatch(string(b), -1) {
		alvos[m[1]] = true
	}
	if len(alvos) == 0 {
		t.Fatal("nenhum alvo lido do Makefile — o regex quebrou")
	}
	return alvos
}

func raiz(t *testing.T) string {
	t.Helper()
	abs, err := filepath.Abs(filepath.Join("..", ".."))
	if err != nil {
		t.Fatal(err)
	}
	return abs
}
