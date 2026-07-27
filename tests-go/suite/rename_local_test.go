package suite

import "testing"

// rename de LOCAL: a declaração, o uso no codeblock e o uso no código — e o
// homônimo do COMENTÁRIO fica.
func init() {
	registra("rename-local", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "fix01.hbp", "a.prg:5:10", "nSoma")

		if env.Result.EditCount != 3 { // decl + codeblock + corpo; o comentário não
			t.Errorf("editCount = %d, quero 3", env.Result.EditCount)
		}
	})
}
