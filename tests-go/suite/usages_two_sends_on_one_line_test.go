package suite

import "testing"

// O terceiro canal que o `ast-20` conserta: `sends[]`. Duas mensagens do MESMO
// membro na mesma linha (`? o:Description, o:Description`), nas colunas 7 e 22
// — antes as duas eram relatadas em 7.
//
// E o caso trava, de quebra, a HONESTIDADE do veredito: o tipo do receptor não
// está declarado, então cada sítio sai `possible`, nunca `confirmed`. Despacho
// dinâmico sem fato é o lugar onde uma ferramenta heurística chutaria — esta
// diz que não sabe.
func init() {
	registra("usages-two-sends-on-one-line", func(t *testing.T, p *Projeto) {
		env := p.Roda("usages", "s.hbp", "Description")

		querColunas := []int{7, 22}
		var tenho []int
		for _, l := range env.Result.Locations {
			// o filtro por LINHA não é detalhe: sem ele a mensagem de falha
			// afirma "a linha 5" sobre uma contagem que ignorou a linha, e uma
			// regressão da classe "coluna certa, linha errada" — que é
			// exatamente o defeito do statement continuado — passaria verde
			// aqui. Os dois casos irmãos já filtram; este não filtrava.
			if l.Range.Start.Line != 4 {
				continue
			}
			tenho = append(tenho, l.Range.Start.Character)
			if l.Kind != "send" {
				t.Errorf("kind = %q, quero send", l.Kind)
			}
			if l.Certainty != "possible" {
				t.Errorf("certainty = %q, quero possible — o tipo do receptor não é declarado",
					l.Certainty)
			}
		}
		if len(tenho) != len(querColunas) {
			t.Fatalf("a linha 5 trouxe %d sends, quero %d", len(tenho), len(querColunas))
		}
		for i, quero := range querColunas {
			if tenho[i] != quero {
				t.Errorf("send %d na coluna %d, quero %d — dois sends, duas colunas",
					i+1, tenho[i], quero)
			}
		}
	})
}
