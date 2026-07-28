package suite

import "testing"

// O mesmo fato do `ast-20`, no canal `calls[]` — e é este o caso que aparece
// em código real todo dia: chamada ANINHADA mais uma terceira na mesma linha
// (`Dobro( Dobro( 2 ) ) + Dobro( 3 )`), nas colunas 8, 15 e 30.
//
// Achado ao varrer os outros consumidores depois da primeira correção
// *(pergunta do Diego: "procure se deixou passar algo parecido")*: `calls[]` e
// `sends[]` tinham a lacuna idêntica à de `occurrences[]`, e as três chamadas
// eram relatadas em 8, 8, 8.
func init() {
	registra("usages-nested-calls-on-one-line", func(t *testing.T, p *Projeto) {
		env := p.Roda("usages", "q.hbp", "Dobro")

		querColunas := []int{8, 15, 30}
		var tenho []int
		for _, l := range env.Result.Locations {
			if l.Range.Start.Line == 4 {
				tenho = append(tenho, l.Range.Start.Character)
			}
		}
		if len(tenho) != len(querColunas) {
			t.Fatalf("a linha 5 trouxe %d chamadas, quero %d", len(tenho), len(querColunas))
		}
		for i, quero := range querColunas {
			if tenho[i] != quero {
				t.Errorf("chamada %d na coluna %d, quero %d — três chamadas, três colunas",
					i+1, tenho[i], quero)
			}
		}
	})
}
