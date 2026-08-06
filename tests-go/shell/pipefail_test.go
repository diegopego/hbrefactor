// `grep -q` (ou qualquer consumidor que feche o pipe cedo) dentro de um
// pipeline cujo STATUS decide algo, num script com `pipefail`: MENTE.
//
// O -q fecha o pipe no primeiro casamento, o produtor leva SIGPIPE, e o
// pipeline sai NÃO-ZERO **mesmo tendo casado**. A guarda responde "não tem"
// sobre um binário que tem — e essa é a direção perigosa: deixa passar
// exatamente o que ela existe para barrar.
//
// Custou em 2026-08-06, no `tools/pcode-identity.sh`: a guarda que impede
// comparar o compilador remendado com ele mesmo (o que daria 100% de identidade
// e provaria NADA) foi escrita assim. O cenário certo passava — pelo motivo
// errado. Só apareceu porque rodei os três cenários ERRADOS e as mensagens não
// batiam com o caso. Ver cicatrizes §5.1b.
//
// Por que isto é código e por que em Go: a cicatriz é prosa, e a lei do repo
// (§1.6) diz que regra nova sem portão novo é regra que se viola de novo. E o
// extrator é função pura com teste próprio (TestClassifica) — a primeira versão
// do portão dos docs foi em bash e tinha o defeito clássico: se o regex parasse
// de casar, a guarda passava VERDE, calada.
//
// O que ele NÃO faz, de propósito: julgar shell em geral. Só a forma mecânica —
// pipeline + consumidor que fecha cedo + status consumido —, que é a única
// decidível sem interpretar o script.
package shell

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

// consumidores que FECHAM o pipe antes de o produtor terminar
var reFechaCedo = regexp.MustCompile(`^(?:grep\s+(?:-\w*q|\S*\s+-\w*q)|head\b|grep\s+-\w*m\b|sed\s+.*\b\d+q\b)`)

// o status do pipeline é consumido? (if/while/until/!/&&/||, ou comando nu,
// que sob `set -e` decide a vida do script)
var reStatusUsado = regexp.MustCompile(`^\s*(?:if|elif|while|until|!)\s`)

// Achado é uma linha suspeita de um arquivo.
type Achado struct {
	Linha int
	Texto string
}

// Classifica devolve as linhas de `conteudo` que têm a forma perigosa.
// Só analisa se o script liga pipefail — sem ele o SIGPIPE não contamina nada.
func Classifica(conteudo string) []Achado {
	if !strings.Contains(conteudo, "pipefail") {
		return nil
	}
	var achados []Achado

	linhas := strings.Split(conteudo, "\n")
	// junta continuações de linha: o pipeline pode estar quebrado com `\`
	var buf string
	inicio := 0
	for i, l := range linhas {
		if buf == "" {
			inicio = i + 1
		}
		if strings.HasSuffix(strings.TrimRight(l, " \t"), `\`) {
			buf += strings.TrimSuffix(strings.TrimRight(l, " \t"), `\`) + " "
			continue
		}
		logica := buf + l
		buf = ""

		if a, ok := suspeita(logica, inicio); ok {
			achados = append(achados, a)
		}
	}
	return achados
}

func suspeita(logica string, linha int) (Achado, bool) {
	t := strings.TrimSpace(logica)
	if t == "" || strings.HasPrefix(t, "#") {
		return Achado{}, false
	}
	// status explicitamente DESCARTADO: o valor é que importa, e o valor está
	// certo. É o idioma correto quando se quer o conteúdo (anti-heuristica.sh).
	if strings.HasSuffix(t, "|| true") || strings.HasSuffix(t, "|| :") {
		return Achado{}, false
	}
	// `||` de curto-circuito com corpo (`... || { erro; exit 1; }`) usa o status
	if !strings.Contains(t, "|") {
		return Achado{}, false
	}
	// o último estágio do pipeline (ignorando `||`/`&&`, que não são pipe)
	semLogicos := regexp.MustCompile(`\|\||&&`).ReplaceAllString(t, "\x00")
	partes := strings.Split(semLogicos, "|")
	if len(partes) < 2 {
		return Achado{}, false // não era pipeline, era só `||`
	}
	ultimo := strings.TrimSpace(strings.SplitN(partes[len(partes)-1], "\x00", 2)[0])
	if !reFechaCedo.MatchString(ultimo) {
		return Achado{}, false
	}
	// dentro de `$( )` com o resultado atribuído, o status normalmente não é o
	// que decide — mas SÓ quando descartado, e isso já foi tratado acima.
	if reStatusUsado.MatchString(logica) || strings.Contains(t, "||") || strings.Contains(t, "&&") {
		return Achado{Linha: linha, Texto: t}, true
	}
	// comando nu: sob `set -e` o status decide a vida do script
	if !strings.Contains(t, "=$(") && !strings.Contains(t, "=`") {
		return Achado{Linha: linha, Texto: t}, true
	}
	return Achado{}, false
}

// O extrator tem teste PRÓPRIO: se ele parar de casar, é aqui que quebra — e
// não a guarda que emudece.
func TestClassifica(t *testing.T) {
	casos := []struct {
		nome     string
		src      string
		queroHit bool
	}{
		{"o bug real: if + grep -q em pipeline",
			"set -uo pipefail\nif strings \"$B\" | grep -qE '^ast-[0-9]+$'; then\n", true},
		{"negado: ! ... | grep -q",
			"set -o pipefail\n! strings $B | grep -qE 'x' || { echo nao; exit 1; }\n", true},
		{"curto-circuito: pipeline || { ... }",
			"set -o pipefail\nstrings $B | grep -q ast || { echo falta; exit 1; }\n", true},
		{"head no fim de pipeline com status usado",
			"set -o pipefail\nif ls | head -3; then :; fi\n", true},
		{"SEGURO: status descartado, o valor e' que importa",
			"set -o pipefail\nhits=$(printf '%s' \"$A\" | grep -nEi \"$R\" | head -3) || true\n", false},
		{"SEGURO: substituicao de comando sem status",
			"set -o pipefail\ngot=$(strings $B | grep -oE 'ast-[0-9]+' | sort -u)\n", false},
		{"SEGURO: sem pipefail, SIGPIPE nao contamina",
			"set -eu\nif strings $B | grep -q ast; then :; fi\n", false},
		{"SEGURO: grep -q sem pipeline",
			"set -o pipefail\nif grep -q ast \"$B\"; then :; fi\n", false},
		{"SEGURO: comentario",
			"set -o pipefail\n# nada de `x | grep -q y` aqui\n", false},
	}
	for _, c := range casos {
		t.Run(c.nome, func(t *testing.T) {
			got := Classifica(c.src)
			if (len(got) > 0) != c.queroHit {
				t.Errorf("Classifica() = %v, queria hit=%v", got, c.queroHit)
			}
		})
	}
}

func TestNenhumScriptCaiNaArmadilhaDoPipefail(t *testing.T) {
	raiz, err := filepath.Abs(filepath.Join("..", ".."))
	if err != nil {
		t.Fatal(err)
	}
	var vistos int
	err = filepath.Walk(raiz, func(p string, fi os.FileInfo, err error) error {
		if err != nil {
			return nil // diretório ilegível não é assunto deste portão
		}
		if fi.IsDir() {
			switch fi.Name() {
			case ".git", "bin", "tmp", "node_modules":
				return filepath.SkipDir
			}
			return nil
		}
		if !strings.HasSuffix(p, ".sh") {
			return nil
		}
		b, err := os.ReadFile(p)
		if err != nil {
			return nil
		}
		vistos++
		rel, _ := filepath.Rel(raiz, p)
		for _, a := range Classifica(string(b)) {
			t.Errorf("%s:%d: pipeline com consumidor que fecha o pipe, e o status decide algo,\n"+
				"  num script com pipefail — ele sai NAO-ZERO mesmo tendo casado:\n"+
				"    %s\n"+
				"  conserte com substituicao de comando: x=$(... | grep -oE ...) e teste -n/-z.\n"+
				"  (cicatrizes §5.1b)", rel, a.Linha, a.Texto)
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	// anti-vacuidade: guarda que não olhou nada passa verde e não protege ninguém
	if vistos < 5 {
		t.Fatalf("só %d scripts varridos — o walk não está achando os .sh", vistos)
	}
}
