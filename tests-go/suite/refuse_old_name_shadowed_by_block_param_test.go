package suite

import "testing"

// RECUSA: um parâmetro de codeblock homônimo sombreia o LOCAL alvo — dentro do
// bloco o nome já é OUTRA variável, e renomear só o de fora deixaria os dois
// indistinguíveis no fonte. O `expected/` é o `source/` copiado de propósito:
// é ele que prova que a recusa não tocou em nada.
func init() {
	registra("refuse-old-name-shadowed-by-block-param", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "fix01.hbp", "a.prg:26:10", "xNovo")

		if r, a := env.Recusa(); r != "old-name-shadowed-by-codeblock-param" || a != "stop-and-report" {
			t.Errorf("recusa = %q/%q, quero old-name-shadowed-by-codeblock-param/stop-and-report", r, a)
		}
		// recusa de POLÍTICA não propõe edição: quem lê o envelope não tem o
		// que aplicar, e é isso que separa `stop-and-report` de um dry-run.
		if len(env.Edits) != 0 {
			t.Errorf("a recusa trouxe %d edição(ões)", len(env.Edits))
		}
	})
}
