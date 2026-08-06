package suite

import "testing"

// O par ESCRITA/LEITURA do mesmo membro numa linha — o caso que o
// `usages-two-sends-on-one-line` não alcança, porque lá os dois sends são
// LEITURAS.
//
//	o:Description := o:Description + "!"
//	  ^5              ^22
//
// Mensagem escrita como atribuição é registrada sob o nome manjado que o
// próprio compilador cria (`_` + nome) enquanto o token lê o nome puro. Os dois
// registros da linha têm, portanto, `sym` DIFERENTES — e qualquer contagem de
// "quantos sítios deste nome vieram antes" os conta em separado, dando a cada um
// o primeiro token. Medido antes do conserto: os dois na coluna 5, e a leitura
// da coluna 22 nunca relatada.
//
// A posição do nó não tem esse problema: cada sítio nasce do seu próprio nó, e o
// nome manjado não participa de conta nenhuma.
func init() {
	registra("usages-send-write-and-read-on-one-line", func(t *testing.T, p *Projeto) {
		env := p.Roda("usages", "m.hbp", "Description")

		var colunas []int
		for _, l := range env.Result.Locations {
			if l.Range.Start.Line == 4 {
				colunas = append(colunas, l.Range.Start.Character)
			}
			if l.Kind != "send" {
				t.Errorf("kind = %q, quero send", l.Kind)
			}
			// o tipo do receptor não é declarado: a ferramenta diz que não sabe
			if l.Certainty != "possible" {
				t.Errorf("certainty = %q, quero possible", l.Certainty)
			}
		}
		if len(colunas) != 2 {
			t.Fatalf("a linha 5 trouxe %d sends, quero 2 (a escrita e a leitura)", len(colunas))
		}
		if colunas[0] != 5 || colunas[1] != 22 {
			t.Errorf("os sends da linha 5 estão em %v, quero [5 22] — a escrita e a leitura "+
				"são tokens distintos", colunas)
		}
	})
}
