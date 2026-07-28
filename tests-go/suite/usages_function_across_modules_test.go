package suite

import "testing"

// `usages` de uma função ATRAVESSANDO módulos: a definição mora num arquivo e a
// chamada noutro, e o comando acha os dois porque pergunta ao PROJETO — não ao
// arquivo aberto.
//
// Comando de LEITURA: o `expected/` é o `source/` copiado, e é ele que prova
// que consultar não edita.
func init() {
	registra("usages-function-across-modules", func(t *testing.T, p *Projeto) {
		env := p.Roda("usages", "fix01.hbp", "Dupla")

		if env.Result.Total != 2 || env.Result.Returned != 2 || env.Result.Truncated {
			t.Errorf("total/returned/truncated = %d/%d/%v, quero 2/2/false",
				env.Result.Total, env.Result.Returned, env.Result.Truncated)
		}
		// `confirmed` em TODO sítio é o que separa isto de um grep: cada um veio
		// da compilação. Sítio com outra certeza seria a ferramenta relatando o
		// que não provou.
		for _, l := range env.Result.Locations {
			if l.Certainty != "confirmed" {
				t.Errorf("%s: certainty = %q, quero confirmed", l.URI, l.Certainty)
			}
		}
	})
}
