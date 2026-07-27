package suite

import "testing"

// RECUSA: o nome novo já é um LOCAL declarado na MESMA função. Renomear
// fundiria duas variáveis distintas numa só — e compilaria calado, que é o que
// torna esta a recusa mais importante da família.
func init() {
	registra("refuse-local-name-taken", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "fix01.hbp", "a.prg:5:10", "i")

		if r, a := env.Recusa(); r != "new-name-already-declared" || a != "stop-and-report" {
			t.Errorf("recusa = %q/%q, quero new-name-already-declared/stop-and-report", r, a)
		}
		if len(env.Edits) != 0 {
			t.Errorf("a recusa trouxe %d edição(ões)", len(env.Edits))
		}
	})
}
