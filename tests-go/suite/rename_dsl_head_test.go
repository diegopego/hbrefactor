package suite

import "testing"

// Renomeia a CABEÇA de uma diretiva: a declaração no `.ch` e os sítios que a
// aplicam nos dois módulos. É o caso que a régua do vocabulário existe para
// guardar — a ferramenta atravessa uma DSL sem conhecer nenhuma palavra dela.
//
// A prova não é a mesma de um rename de LOCAL: aqui o pp reescreve texto ANTES
// do compilador, então o que se compara é a EXPANSÃO (`.ppo` e `.hrb` idênticos).
func init() {
	registra("rename-dsl-head", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "fixdsl.hbp", "a.prg:11:4", "MENU_ITEM")

		if env.Result.Kind != "dsl" || env.Result.Proof != "expansion-identical" {
			t.Errorf("kind/proof = %q/%q, quero dsl/expansion-identical",
				env.Result.Kind, env.Result.Proof)
		}
		// 3 aplicações + 1 declaração: os dois números são separados de propósito,
		// porque são fatos de naturezas diferentes (uso × definição).
		if env.Result.ApplicationSites != 3 || env.Result.DirectiveOccurrences != 1 {
			t.Errorf("sítios = %d aplicação(ões) + %d diretiva(s), quero 3 + 1",
				env.Result.ApplicationSites, env.Result.DirectiveOccurrences)
		}
		if env.Result.EditCount != 4 { // e os quatro somam os dois acima
			t.Errorf("editCount = %d, quero 4", env.Result.EditCount)
		}
		// o escopo COMPLETO é o que autoriza o veredito a valer para o projeto:
		// nenhum sítio ficou num ramo que a compilação não viu.
		if env.Result.Scope == nil || !env.Result.Scope.Complete || len(env.Result.Scope.Unseen) != 0 {
			t.Errorf("escopo = %+v, quero completo e sem `unseen`", env.Result.Scope)
		}
	})
}
