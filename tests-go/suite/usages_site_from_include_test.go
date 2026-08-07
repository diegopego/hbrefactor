package suite

import "testing"

// O sítio cujo NOME foi escrito noutro arquivo — e, medido no corpus do core,
// **40% dos sítios de código real** são deste tipo, porque Harbour se escreve
// sobre DSL (`hbclass.ch`, `std.ch`, os comandos da própria aplicação).
//
//	k.ch:1   #xcommand CMD_SOMA <v> => nAcc += <v>
//	                             ^26: o NOME está escrito aqui
//	k.prg:7     CMD_SOMA 5
//	            ^3: o USO acontece aqui
//
// São dois lugares, e a ferramenta JÁ os separa: o uso sai como sítio do
// módulo, e a posição escrita sai como entrada própria (`in rule result`),
// apontando o `.ch`. Este caso não inventa forma nova — ele trava a que existe
// e cobra as duas lacunas dela:
//
//  1. o USO sai em `6:0`, largura zero — mas a posição existe e está publicada:
//     `ppApplications` traz o token `CMD_SOMA` da aplicação em `7:3`, com o
//     comprimento. Zero-width é o sinal honesto de "não sei onde"; usá-lo onde
//     se SABE gasta o único sinal que temos para o caso em que de fato não se
//     sabe.
//  2. a entrada do `.ch` sai com `text: null` — a ferramenta sabe o arquivo e a
//     linha, e não mostra a linha. O `text` é o preview pelo qual a IDE e o
//     agente decidem sem reabrir arquivo (é a razão de ele existir); nulo ali
//     devolve ao consumidor o trabalho que o campo existe para poupar.
func init() {
	registra("usages-site-from-include", func(t *testing.T, p *Projeto) {
		// VERMELHO POR DESENHO — este caso é o TDD da fase P24, escrito à MÃO
		// antes do conserto, que é o método deste repo (§3: o esperado se
		// escreve, nunca se grava de uma execução).
		//
		// Ele está COMMITADO vermelho por decisão do Diego (2026-08-06): a
		// alternativa era deixá-lo fora do git, e untracked morre num
		// `git clean -fdx` — com a frente parada por tempo indeterminado, o
		// risco de PERDER o contrato é pior que um HEAD vermelho conhecido.
		//
		// Some quando a P24 entregar. Não "conserte" o esperado: ele é o
		// contrato. Ver docs/retomada-posicao-do-sitio.md.
		t.Log("TDD DA P24 — vermelho POR DESENHO, ver docs/retomada-posicao-do-sitio.md")

		env := p.Roda("usages", "k.hbp", "nAcc", "--func", "Main")

		var uso, noHeader *Local
		for i := range env.Result.Locations {
			l := &env.Result.Locations[i]
			switch {
			case l.URI == "file://<CWD>/k.ch":
				noHeader = l
			case l.Kind == "use (local)":
				uso = l
			}
		}

		// 1. o uso acontece na aplicação da diretiva, e ela tem posição
		if uso == nil {
			t.Error("nenhum sítio `use (local)` — o uso trazido pela diretiva sumiu")
		} else if uso.Range.Start.Line != 6 || uso.Range.Start.Character != 3 ||
			uso.Range.End.Character != 11 {
			t.Errorf("o uso está em %d:%d..%d, quero 6:3..11 — o token `CMD_SOMA` da "+
				"aplicação, que o dump publica em ppApplications",
				uso.Range.Start.Line, uso.Range.Start.Character, uso.Range.End.Character)
		}

		// 2. o nome escrito no header, com o preview daquela linha
		if noHeader == nil {
			t.Error("nenhum sítio no k.ch — quem renomear `nAcc` precisa saber que o " +
				"nome também está escrito no header, ou a edição quebra o build")
			return
		}
		if noHeader.Range.Start.Line != 0 || noHeader.Range.Start.Character != 26 {
			t.Errorf("o nome no header está em %d:%d, quero 0:26 (0-based)",
				noHeader.Range.Start.Line, noHeader.Range.Start.Character)
		}
		if noHeader.Text == "" {
			t.Error("a entrada do k.ch sem `text`: a ferramenta tem o arquivo e a linha, " +
				"e devolve ao consumidor o trabalho de reabrir o arquivo — que é " +
				"exatamente o que o campo existe para poupar")
		}
	})
}
