// Duas fases não podem carregar o MESMO número.
//
// Por que este portão existe (CLAUDE.md §6, cicatrizes do número disputado):
// duas sessões escrevem neste roadmap ao mesmo tempo, e o número de fase é
// recurso global entre elas — igual ao número de schema, que já foi disputado
// uma vez (a P24 reservou `ast-22`, outra fase consumiu primeiro, e ela virou
// `ast-23`). Em 2026-08-09 aconteceu com fase: a sessão paralela abriu a P33
// (LSP) às 19:14, e a outra escreveu a SUA P33 às 00:55 do dia seguinte sem
// reler o documento. O roadmap ficou com dois `### P33` e a suíte inteira
// passou verde — porque nada olhava para isso.
//
// O estrago não é estético: o roadmap é a fonte de verdade das specs, e um
// número duplicado quebra toda referência a ele (o CLAUDE.md, um comentário de
// teste, uma mensagem de commit apontam para "P33" e agora existem duas).
//
// O que ele NÃO faz: julgar a numeração (não exige sequência, não proíbe
// buraco). Só cobra a parte decidível — o mesmo número não aparece duas vezes.
package docs

import (
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"testing"

	"github.com/google/go-cmp/cmp"
)

// Duplicados devolve, em ordem, os IDs de fase que aparecem mais de uma vez.
func Duplicados(fases []Fase) []string {
	vezes := map[string]int{}
	for _, f := range fases {
		vezes[f.ID]++
	}
	var fora []string
	for id, n := range vezes {
		if n > 1 {
			fora = append(fora, id)
		}
	}
	sort.Strings(fora)
	return fora
}

// ProximoLivre devolve o primeiro número de fase acima do MAIOR em uso.
//
// Não reaproveita buraco de propósito: um número vago pode já ter sido citado
// por mensagem de commit, pelo CLAUDE.md ou por comentário de teste antes de a
// fase morrer ou ser renumerada — reusá-lo faria duas coisas diferentes
// atenderem pelo mesmo nome, que é o estrago que este arquivo existe para
// impedir.
func ProximoLivre(fases []Fase) string {
	maior := 0
	for _, f := range fases {
		if n, err := strconv.Atoi(strings.TrimPrefix(f.ID, "P")); err == nil && n > maior {
			maior = n
		}
	}
	return "P" + strconv.Itoa(maior+1)
}

// O CONTROLE NEGATIVO (o padrão do TestExtrai/TestFases): se a detecção parar
// de detectar, é ESTE teste que falha — e não a guarda emudecendo sobre um
// roadmap que ela deixou de conferir. A amostra reproduz a colisão real.
func TestDuplicados(t *testing.T) {
	const amostra = "### P33 — LSP como superfície de entrega *(aberto 2026-08-08; **A FAZER**)*\n" +
		"corpo\n" +
		"### P34 — IntelliSense *(**EXPLORATÓRIA**)*\n" +
		"corpo\n" +
		"### P33 — outra coisa escrita por outra sessão *(**FECHADO**)*\n" +
		"corpo\n"

	if d := cmp.Diff([]string{"P33"}, Duplicados(Fases(amostra))); d != "" {
		t.Errorf("a detecção de duplicata mudou de comportamento (-quero +tenho):\n%s", d)
	}
	if d := cmp.Diff([]string(nil), Duplicados(Fases("### P1 — só uma *(x)*\ncorpo\n"))); d != "" {
		t.Errorf("acusou duplicata onde não há (-quero +tenho):\n%s", d)
	}
	// o número que a recusa MANDA usar: acima do maior em uso (34), nunca o
	// buraco que a renumeração deixa para trás
	if got := ProximoLivre(Fases(amostra)); got != "P35" {
		t.Errorf("ProximoLivre = %q, quero P35 (maior em uso é P34)", got)
	}
}

func TestNumeroDeFaseNaoRepete(t *testing.T) {
	caminho := filepath.Join(raiz(t), "docs", "roadmap.md")
	b, err := os.ReadFile(caminho)
	if err != nil {
		t.Fatalf("roadmap ilegível: %v", err)
	}
	fases := Fases(string(b))
	if len(fases) == 0 {
		t.Fatal("nenhuma fase lida do roadmap — o regex quebrou")
	}
	if dup := Duplicados(fases); len(dup) > 0 {
		t.Errorf("número(s) de fase repetido(s) no roadmap: %v. Duas sessões "+
			"escrevem aqui: renumere a fase mais NOVA para %s (a mais antiga já "+
			"foi citada por commit, CLAUDE.md ou comentário de teste)",
			dup, ProximoLivre(fases))
	}
}
