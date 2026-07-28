package suite

import "testing"

// O exemplo do Diego, 2026-07-27:
//
//	LOCAL a, b
//	a := "b"      // isto é uma string comum
//
// A ferramenta relatava `possible reference in string` aqui — casando o TEXTO
// do literal contra o nome procurado (`Upper( hItem["text"] ) == cUpMeth`), que
// é o §1.2 gatilho 1 em estado puro, e sem um único selo `FATO-OK` no fonte:
// a detecção é anterior ao portão do §1.1.
//
// **A régua que a mata** *(Diego)*: *"heurística é code smell e deve ser retirada
// mesmo. se houver forma de resolver através de alterações no core, aí sim,
// senão, o hbrefactor simplesmente não vai suportar. me recuso a ter heurística
// nele."* — e mais: *"está fora do escopo do hbrefactor lidar com fatos frágeis
// e de responsabilidade do desenvolvedor, como simplesmente colocar o nome de
// uma variável dentro de uma string."*
//
// Este caso é o piso: aqui não há nada a relatar, e a saída vazia é a resposta
// CERTA — não um limiar bem calibrado. `b` é um LOCAL, e macro provadamente não
// alcança local (medido: `&cN` nomeando um LOCAL morre em runtime com "Variable
// does not exist"), então nem o caminho legítimo da P22 tem o que dizer aqui.
func init() {
	registra("usages-plain-string-is-not-a-reference", func(t *testing.T, p *Projeto) {
		env := p.Roda("usages", "s.hbp", "b", "--func", "Main")

		if env.Result.Total != 3 {
			t.Errorf("total = %d, quero 3 (declaração, escrita, leitura) — a string "+
				"`\"b\"` da linha 5 não é sítio nenhum", env.Result.Total)
		}
		for _, l := range env.Result.Locations {
			// a linha 5 (0-based 4) é a da string: nenhum sítio pode nascer dela
			if l.Range.Start.Line == 4 {
				t.Errorf("sítio na linha 5 (%q): a ferramenta voltou a casar texto "+
					"de string contra o nome", l.Text)
			}
			// e nada aqui é incerto: os três vêm da compilação
			if l.Certainty != "confirmed" {
				t.Errorf("certainty = %q em %d:%d, quero confirmed — sem a heurística "+
					"não sobra nenhum `possible` neste caso",
					l.Certainty, l.Range.Start.Line, l.Range.Start.Character)
			}
		}
	})
}
