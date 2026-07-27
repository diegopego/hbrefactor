package suite

import "testing"

// MULTI-COMANDO com transformação: dois renames em sequência, sobre o MESMO
// projeto — o segundo encontra o arquivo já editado pelo primeiro, e o
// `expected/` afirma o estado depois dos dois.
//
// O que os nomes provam: `while` e `Loop` PARECEM reservados, e quem decide não
// é uma lista escrita por nós — é o projeto compilando. Os dois entram, e o
// pcode fica idêntico. (Foi a morte do `NameAccepted`: ele recusava `while`,
// que o projeto real aceita.)
func init() {
	registra("rename-local-to-keyword-like-name", func(t *testing.T, p *Projeto) {
		primeiro := p.Roda("rename", "fix01.hbp", "a.prg:5:10", "while")
		segundo := p.Roda("rename", "fix01.hbp", "a.prg:20:10", "Loop")

		for _, c := range []struct {
			nome string
			env  Envelope
			n    int
		}{
			{"while", primeiro, 3}, // decl + codeblock + corpo
			{"Loop", segundo, 2},   // decl + RETURN
		} {
			if c.env.Result.EditCount != c.n {
				t.Errorf("%s: editCount = %d, quero %d", c.nome, c.env.Result.EditCount, c.n)
			}
			if c.env.Result.Proof != "pcode-identical" {
				t.Errorf("%s: proof = %q, quero pcode-identical", c.nome, c.env.Result.Proof)
			}
		}
	})
}
