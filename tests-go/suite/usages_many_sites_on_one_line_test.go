package suite

import "testing"

// TRÊS ocorrências do mesmo nome numa ÚNICA linha — `nTotal := nTotal + nTotal`,
// nas colunas 3, 13 e 22 —, e o que este caso trava é que **todas as três são
// alcançáveis**, cada uma no seu token.
//
// Duas coisas separadas tiveram de ser verdade para isso:
//
//  1. a posição de um sítio vem do NÓ que o parser construiu, não de contar
//     "o K-ésimo registro deste nome nesta linha". A ordem em que o compilador
//     registra é a de REDUÇÃO; a dos tokens é a de ESCRITA. O `ast-20` casava
//     as duas e por isso ACERTAVA aqui por acaso e errava noutros lugares (ver
//     `usages-write-and-capture-on-one-line`);
//  2. o token do MEIO só existe no relato porque o core passou a registrá-lo.
//     O compilador reescreve `var := var <op> exp` para `var <op>= exp` e
//     **libera o nó do operando** no reduce, então a geração de código nunca o
//     vê. O pcode fica certo e o registro do FONTE ficava faltando um nome que
//     o programador escreveu — um find-all-references que não o lista está
//     errado para quem vai renomear.
//
// O alvo aparece em DOIS registros no MESMO token (`use` e `ref`, coluna 3):
// ele é lido e escrito no lugar, e essa é a mesma forma da captura por
// codeblock — dois sítios, um token só.
func init() {
	registra("usages-many-sites-on-one-line", func(t *testing.T, p *Projeto) {
		env := p.Roda("usages", "p.hbp", "nTotal", "--func", "Main")

		// a linha 6 (0-based 5), na ordem em que o dump registra
		type sitio struct {
			kind string
			col  int
		}
		quero := []sitio{
			{"read (local)", 13}, // o operando que o otimizador dobra no alvo
			{"use (local)", 3},   // o alvo, lido-e-escrito no lugar
			{"ref (local)", 3},   // o MESMO token, segundo registro
			{"read (local)", 22}, // a ponta direita
		}
		var tenho []sitio
		for _, l := range env.Result.Locations {
			if l.Range.Start.Line == 5 {
				tenho = append(tenho, sitio{l.Kind, l.Range.Start.Character})
			}
		}
		if len(tenho) != len(quero) {
			t.Fatalf("a linha 6 trouxe %d sítios, quero %d — %v", len(tenho), len(quero), tenho)
		}
		for i := range quero {
			if tenho[i] != quero[i] {
				t.Errorf("sítio %d da linha 6 é %v, quero %v", i+1, tenho[i], quero[i])
			}
		}

		// os TRÊS tokens escritos ficam cobertos: quem renomear precisa dos três
		cobertas := map[int]bool{}
		for _, s := range tenho {
			cobertas[s.col] = true
		}
		for _, col := range []int{3, 13, 22} {
			if !cobertas[col] {
				t.Errorf("nenhum sítio no token da coluna %d — o nome está escrito lá", col)
			}
		}

		// e o fim de cada sítio fecha o NOME, não um pedaço dele
		for _, l := range env.Result.Locations {
			if n := l.Range.End.Character - l.Range.Start.Character; n != len("nTotal") {
				t.Errorf("o sítio da linha %d cobre %d caracteres, quero %d",
					l.Range.Start.Line+1, n, len("nTotal"))
			}
		}
	})
}
