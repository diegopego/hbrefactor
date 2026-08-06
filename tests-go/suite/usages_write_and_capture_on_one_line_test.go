package suite

import "testing"

// O CONTRAEXEMPLO do `ast-20`: quando a ordem dos REGISTROS não é a ordem dos
// TOKENS, casar o K-ésimo com o K-ésimo aponta o lugar errado.
//
//	nTotal := 0 + Eval( {| x | nTotal += x }, 1 ) + nTotal
//	   ^3                      ^30                  ^51
//
// Três tokens, QUATRO sítios: a captura pelo codeblock chega em dois registros
// (`use` e `ref`), os dois no token da coluna 30. A ordem em que o compilador
// os registra é a de REDUÇÃO — o alvo da atribuição é o ÚLTIMO —, e a ordem dos
// tokens é a de ESCRITA. Elas não têm por que coincidir, e aqui não coincidem.
//
// Medido no dump antes do conserto: `use` na 3 (é 30), `ref` na 30 (certo por
// acaso), `read` na 51 (certo), `write` na 51 (é 3). Dois de quatro errados, e
// os quatro saindo `confirmed` — a ferramenta afirmando com a mesma confiança
// o que provou e o que contou.
//
// O fato existe no compilador e não é contagem: todo nó de expressão nasce com
// o índice do token que o gerou (`nBirthTok`, hb_compAstNodeBorn). O sítio nasce
// de um nó; a posição é a do token daquele nó.
func init() {
	registra("usages-write-and-capture-on-one-line", func(t *testing.T, p *Projeto) {
		env := p.Roda("usages", "w.hbp", "nTotal", "--func", "Main")

		// o que este caso prova: na linha do statement (0-based 4), cada sítio
		// no SEU token — e nenhum sítio numa coluna onde não há token.
		porKind := map[string]int{}
		for _, l := range env.Result.Locations {
			if l.Range.Start.Line == 4 {
				porKind[l.Kind] = l.Range.Start.Character
			}
		}
		quero := map[string]int{
			"write (local)":             3,  // o alvo da atribuição
			"use (detached, codeblock)": 30, // a captura, dentro do bloco
			"ref (detached, codeblock)": 30, // o mesmo token, segundo registro
			"read (local)":              51, // a leitura da ponta direita
		}
		for kind, col := range quero {
			if tenho, ok := porKind[kind]; !ok {
				t.Errorf("nenhum sítio %q na linha 5", kind)
			} else if tenho != col {
				t.Errorf("%s na coluna %d, quero %d", kind, tenho, col)
			}
		}
		// e o `write` NUNCA pode cair na coluna de outro sítio: era assim que o
		// defeito se escondia — duas locations idênticas parecem plausíveis.
		if porKind["write (local)"] == porKind["read (local)"] {
			t.Errorf("o alvo da atribuição e a leitura saíram na MESMA coluna (%d)",
				porKind["write (local)"])
		}
	})
}
