package suite

import "testing"

// RECUSA: o projeto já CHAMA o nome novo, e as chamadas passariam a cair na
// função renomeada. A chamada sequestrada compila perfeitamente — é por isso
// que ninguém a veria, e é por isso que a recusa é de política.
//
// O nome escolhido não está escrito em lugar nenhum do fonte: quem o põe lá é
// uma diretiva do `std.ch`, ao expandir o `?` do a.prg. A recusa nasce do que a
// COMPILAÇÃO viu, não do texto do arquivo.
func init() {
	registra("refuse-new-function-name-hijacks-calls", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "fix01.hbp", "b.prg:19:10", "QOut")

		if r, a := env.Recusa(); r != "new-name-already-called" || a != "stop-and-report" {
			t.Errorf("recusa = %q/%q, quero new-name-already-called/stop-and-report", r, a)
		}
		if len(env.Edits) != 0 {
			t.Errorf("a recusa trouxe %d edição(ões)", len(env.Edits))
		}
	})
}
