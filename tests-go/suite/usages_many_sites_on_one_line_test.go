package suite

import "testing"

// O caso que a fase P20 abriu, e que fecha a lacuna: TRÊS ocorrências do mesmo
// nome numa ÚNICA linha (`nTotal := nTotal + nTotal`), nas colunas 3, 13 e 22.
//
// Antes do `ast-20` o dump dava `line` e não `col`, então a ferramenta não
// tinha como saber a qual token cada ocorrência pertencia e resolvia as três
// pelo PRIMEIRO — relatava 3, 3, 3, e dois sítios apontavam o lugar errado.
// Consertar isso na ferramenta seria inferência, e erraria: a ordem dos
// registros é `use, ref, read` enquanto a dos tokens é alvo-de-atribuição,
// leitura, leitura. O fato passou a existir no CORE.
//
// Este caso trava as três colunas distintas. Ele é o controle que impede a
// regressão silenciosa — com o dump antigo, ele reprova.
func init() {
	registra("usages-many-sites-on-one-line", func(t *testing.T, p *Projeto) {
		env := p.Roda("usages", "p.hbp", "nTotal", "--func", "Main")

		// as três da linha 6 (0-based 5), na ordem em que o dump as registra
		querColunas := []int{3, 13, 22}
		var tenho []int
		for _, l := range env.Result.Locations {
			if l.Range.Start.Line == 5 {
				tenho = append(tenho, l.Range.Start.Character)
			}
		}
		if len(tenho) != len(querColunas) {
			t.Fatalf("a linha 6 trouxe %d sítios, quero %d", len(tenho), len(querColunas))
		}
		for i, quero := range querColunas {
			if tenho[i] != quero {
				t.Errorf("sítio %d da linha 6 na coluna %d, quero %d — três tokens, três colunas",
					i+1, tenho[i], quero)
			}
		}
		// e o fim de cada sítio fecha o NOME, não um pedaço dele
		for _, l := range env.Result.Locations {
			if n := l.Range.End.Character - l.Range.Start.Character; n != len("nTotal") {
				t.Errorf("o sítio da linha %d cobre %d caracteres, quero %d",
					l.Range.Start.Line+1, n, len("nTotal"))
			}
		}
	})
}
