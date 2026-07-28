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

		var achou bool
		for _, l := range env.Result.Locations {
			if l.Text != "cMsg + ;" {
				continue
			}
			achou = true
			// 0-based: linha 6 do arquivo, coluna 11
			if l.Range.Start.Line != 5 || l.Range.Start.Character != 11 {
				t.Errorf("o sítio continuado está em %d:%d, quero 5:11 (0-based) — "+
					"a linha do statement é a 7, mas o sítio é escrito na 6",
					l.Range.Start.Line, l.Range.Start.Character)
			}
		}
		if !achou {
			t.Error("nenhum sítio com o texto da linha continuada — o relato aponta outra linha")
		}
	})
}
