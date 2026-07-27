// A suíte da classe A — transformação: um projeto Harbour, os comandos do
// hbrefactor sobre ele, e o que o projeto e a ferramenta ficaram.
//
// O CONTRATO do formato está em tests/README.md. Aqui só a implementação, e ela
// usa o que o Go tem para esta tarefa: `testdata/` (pasta que o toolchain ignora
// de propósito), um subteste por caso, `t.TempDir`/`t.Parallel`, a flag `-update`
// do idioma golden, e `cmp.Diff` para a diferença.
//
//	suite_test.go     esta orquestração: o registro, a descoberta, as comparações
//	projeto_test.go   o projeto no tmp e a invocação da ferramenta
//	fixture_test.go   as propriedades do testdata/ (§7)
//	envelope_test.go  o envelope cli-2 como tipo
//	<caso>_test.go    um por caso: a fixture em testdata/<nome>/ e o que afirmar
package suite

import (
	"flag"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"testing"

	"github.com/google/go-cmp/cmp"
	"github.com/google/go-cmp/cmp/cmpopts"
)

// A ÚNICA coisa que se grava (README §6), e é flag do próprio teste: gerar e
// comparar passam a ser o mesmo caminho de código, então o retrato guardado não
// pode divergir do comparado.
var update = flag.Bool("update", false, "regrava o retrato .ppo/.ppt do core em testdata/<caso>/oracle/")

// O diff sai por LINHA, não por trecho de string: comparar fonte é comparar
// linha, e o `\n` escapado no meio de um chunk é ilegível justo quando mais se
// precisa dele.
var porLinha = cmpopts.AcyclicTransformer("linhas", func(s string) []string {
	return strings.Split(s, "\n")
})

// O registro. Cada caso mora no SEU arquivo e se inscreve daqui, no init() —
// assim nenhum arquivo cresce com a suíte e dois casos novos não disputam a
// mesma linha num merge.
var casos = map[string]func(t *testing.T, p *Projeto){}

func registra(nome string, exercita func(t *testing.T, p *Projeto)) {
	if _, repetido := casos[nome]; repetido {
		panic("caso registrado duas vezes: " + nome)
	}
	casos[nome] = exercita
}

// A pasta É a lista (§2) e o teste é CÓDIGO (§8) — então os dois lados se
// cobram: pasta sem caso registrado é fixture que ninguém exercita, caso sem
// pasta é teste que não roda. Os dois são silenciosos se ninguém os cobrar, e
// silêncio aqui é teste verde que não prova nada.
func TestCasos(t *testing.T) {
	entradas, err := os.ReadDir("testdata")
	if err != nil {
		t.Fatal(err)
	}
	visto := map[string]bool{}
	for _, e := range entradas {
		if !e.IsDir() {
			continue
		}
		nome := e.Name()
		exercita, ok := casos[nome]
		if !ok {
			t.Errorf("testdata/%s existe e nenhum caso o exercita", nome)
			continue
		}
		visto[nome] = true
		t.Run(nome, func(t *testing.T) {
			t.Parallel()
			t.Run("fixture", func(t *testing.T) { fixture(t, nome) })
			t.Run("transformação", func(t *testing.T) { transformacao(t, nome, exercita) })
		})
	}
	for nome := range casos {
		if !visto[nome] {
			t.Errorf("caso %q não tem testdata/", nome)
		}
	}
}

// As duas comparações do §5 são do HARNESS, não do caso: elas valem para todo
// caso, e o que vale para todos ninguém deve reescrever 148 vezes. O caso só
// acrescenta o que é dele. Efeito colateral que importa: não existe caso
// vacuoso, porque não há o que esquecer de escrever.
func transformacao(t *testing.T, nome string, exercita func(*testing.T, *Projeto)) {
	p := novo(t, nome)
	exercita(t, p)

	if len(p.envelopes) == 0 {
		t.Fatal("o caso não invocou a ferramenta — não há o que verificar")
	}

	quero, tenho := arvore(t, filepath.Join(p.art, "expected")), arvore(t, p.dir)

	// §5: artefato novo reprova, a menos que o caso o declare — a ferramenta não
	// suja o projeto do usuário. Vem ANTES do diff e sai só com os NOMES: um
	// .o binário no diff de conteúdo é ilegível e esconde o resto.
	var novos []string
	for nome := range tenho {
		if _, previsto := quero[nome]; previsto || p.declarado(nome) {
			continue
		}
		novos = append(novos, nome)
	}
	if len(novos) > 0 {
		sort.Strings(novos)
		t.Errorf("artefato novo não declarado no projeto (%d):\n  %s",
			len(novos), strings.Join(novos, "\n  "))
		return
	}
	for nome := range tenho {
		if p.declarado(nome) {
			delete(tenho, nome)
		}
	}
	if d := cmp.Diff(quero, tenho, porLinha); d != "" {
		t.Errorf("o projeto depois × expected/ (-quero +tenho):\n%s", d)
	}
	if d := cmp.Diff(p.esperados(t), p.relatado, porLinha); d != "" {
		t.Errorf("o relatado × outputs.json (-quero +tenho):\n%s", d)
	}
}
