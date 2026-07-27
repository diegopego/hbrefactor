package suite

import "testing"

// A declaração do LOCAL alvo carrega, na mesma linha, uma constante de um
// header ALHEIO (`LOCAL nMax := K_LIMITE`). O LOCAL muda; a constante fica
// escrita como está — ela não é do módulo, e o `#define` que a produz mora no
// `.ch` compartilhado.
func init() {
	registra("rename-local-beside-define", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "fix01.hbp", "a.prg:20:10", "nTeto")

		if env.Result.EditCount != 2 { // a declaração e o RETURN; a constante não
			t.Errorf("editCount = %d, quero 2", env.Result.EditCount)
		}
		// o veredito só é `applied` depois da recompilação: o `proof` é o que
		// separa esta ferramenta de uma substituição de texto bem-sucedida.
		if env.Result.Verdict != "applied" || env.Result.Proof != "pcode-identical" {
			t.Errorf("verdict/proof = %q/%q, quero applied/pcode-identical",
				env.Result.Verdict, env.Result.Proof)
		}
	})
}
