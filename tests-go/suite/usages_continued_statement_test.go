package suite

import "testing"

// STATEMENT CONTINUADO com `;` — o terceiro achado da varredura, e de natureza
// diferente dos dois primeiros: aqui não era a coluna que faltava, era a LINHA
// que estava errada.
//
// O `line` de um sítio é a linha em que o COMPILADOR estava, e num statement
// continuado isso é a ÚLTIMA linha física dele. O uso de `cMsg` está escrito na
// linha 6; o registro dizia 7. O `usages` relatava o sítio na linha 7, coluna 0,
// com o texto de outra linha (`"y" )`) — e nenhum teste via isso.
//
// O `ast-20` resolve sem mexer no significado de `line`: o core captura a
// posição do token no momento em que REGISTRA o sítio, e emite `tokLine` só
// quando ela difere. Quem correlaciona sítios com outros canais pelo `line`
// continua funcionando; quem quer o lugar do sítio lê o par (`tokLine`, `col`).
func init() {
	registra("usages-continued-statement", func(t *testing.T, p *Projeto) {
		env := p.Roda("usages", "c.hbp", "cMsg", "--func", "Main")

		// The statement spans lines 6..8 of the file; `cMsg` is written on the
		// MIDDLE one. The compiler records the site on the line it was standing
		// on - the last physical one - so the report has to correct for that,
		// which is what `tokLine` is for.
		const escrita = 5 // 0-based, the `cMsg + ;` line
		linha := p.Linha("c.prg", escrita)

		var achou bool
		for i := range env.Result.Locations {
			l := &env.Result.Locations[i]
			if l.Range.Start.Line != escrita {
				continue
			}
			achou = true
			if l.Text != linha {
				t.Errorf("the site's preview is %q, want the file's own line %q", l.Text, linha)
			}
			l.Aponta(t, linha, "cMsg")
		}
		if !achou {
			t.Errorf("no site on the line the name is written on (%q) - "+
				"the report points somewhere else", linha)
		}
	})
}
