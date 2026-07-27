package suite

import "testing"

// ROLLBACK pela VERIFICAÇÃO, e é a prova central da ferramenta funcionando —
// não um erro dela. Uma diretiva do header stringify o nome numa string
// literal (`<"v">`), então renomear o LOCAL muda o pcode: o projeto continua
// compilando, e mesmo assim o programa passaria a IMPRIMIR outra coisa.
//
// Nenhuma leitura do fonte pega isso; só a recompilação com comparação do
// `.hrb` pega. O fonte volta byte a byte — o `expected/` igual ao `source/` é
// que prova a volta —, e o agente relata "tentei, não era neutro, desfiz".
func init() {
	registra("rollback-stringify-changes-pcode", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "fix01.hbp", "a.prg:33:10", "nOutro")

		if r, a := env.Recusa(); r != "verification-failed-rolled-back" || a != "stop-and-report" {
			t.Errorf("recusa = %q/%q, quero verification-failed-rolled-back/stop-and-report", r, a)
		}
		// desfeito quer dizer desfeito: nada sobra para o consumidor aplicar.
		if len(env.Edits) != 0 {
			t.Errorf("a recusa trouxe %d edição(ões)", len(env.Edits))
		}
	})
}
