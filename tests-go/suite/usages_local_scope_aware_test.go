package suite

import (
	"fmt"
	"testing"
)

// `usages` de um LOCAL, e o que ele tem de saber para responder: ESCOPO. O
// mesmo nome noutra função seria outra variável, e o `--func` diz de qual se
// pergunta. O `nTotal` que aparece num COMENTÁRIO da fixture não é sítio nenhum
// — ele não chega à compilação, então a ferramenta não o vê nem o relata.
//
// CINCO sítios em TRÊS posições, e isso é fato do CORE, não soma da ferramenta.
// O dump do compilador registra, para o mesmo `nTotal` em Main:
//
//	declarations: linha 5
//	occurrences:  linha 5 write | linha 6 use | linha 6 ref | linha 13 read
//
// A declaração com inicializador é declaração E escrita; a captura pelo
// codeblock chega em DOIS registros (`use` e `ref`). A ferramenta projeta um
// sítio por registro — quem quiser posições, deduplica por `range`.
//
// (O teste legado — `unit_9` — afirmava só que TRÊS deles existiam, com uma
// asserção do tipo "ache isto na lista". Ela não podia provar o que a
// ferramenta TAMBÉM dizia, e por isso os outros dois nunca apareceram em teste
// nenhum. Foi a comparação do envelope INTEIRO que os trouxe à luz.)
func init() {
	registra("usages-local-scope-aware", func(t *testing.T, p *Projeto) {
		env := p.Roda("usages", "fix01.hbp", "nTotal", "--func", "Main")

		if env.Result.Total != 5 || env.Result.Returned != 5 || env.Result.Truncated {
			t.Errorf("total/returned/truncated = %d/%d/%v, quero 5/5/false",
				env.Result.Total, env.Result.Returned, env.Result.Truncated)
		}

		posicoes := map[string]int{}
		for _, l := range env.Result.Locations {
			if l.Owner != "MAIN" {
				t.Errorf("owner = %q, quero MAIN — o `--func` recorta o escopo", l.Owner)
			}
			// cada sítio veio da compilação; outra certeza aqui seria a
			// ferramenta relatando o que não provou.
			if l.Certainty != "confirmed" {
				t.Errorf("certainty = %q, quero confirmed", l.Certainty)
			}
			posicoes[fmt.Sprintf("%d:%d", l.Range.Start.Line, l.Range.Start.Character)]++
		}
		if len(posicoes) != 3 {
			t.Errorf("os 5 sítios caem em %d posições, quero 3", len(posicoes))
		}
		// a linha 13 (0-based 12) tem DOIS `nTotal`: o do código na coluna 15 e o
		// do comentário na 27. Só o primeiro pode ser sítio.
		if posicoes["12:15"] != 1 || posicoes["12:27"] != 0 {
			t.Errorf("o sítio da linha 13 não é o do código: %v", posicoes)
		}
	})
}
