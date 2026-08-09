package suite

import (
	"strings"
	"testing"
)

// The three shapes where a memvar's binding GENUINELY depends on the
// execution path. Each is one way for the same USE site to bind to different
// variables on different runs, which no compile-time fact can decide:
//
//	conditional: the second PRIVATE may or may not have executed when the
//	             use runs - the answer is in a runtime value;
//	two callers: the shared use binds to whichever caller's PRIVATE is
//	             alive - one site, two variables, chosen by the call;
//	recursion:   the use "before" the creation sees the caller's variable
//	             on the first activation and the PREVIOUS ACTIVATION'S on
//	             the next - "what is alive at entry" has no single answer.
//
// These pins are the executable half of P33's spec: if a future change makes
// any of them stop refusing, that is not progress - it is the tool claiming
// a fact that does not exist.
func init() {
	registra("refuse-rename-private-conditionally-created", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "p.hbp", "a.prg:5:12", "xNovo")
		reason, _ := env.Recusa()
		if reason != "memvar-has-more-than-one-creator" {
			t.Errorf("reason = %q, want memvar-has-more-than-one-creator", reason)
		}
	})

	registra("refuse-rename-private-shared-use-two-callers", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "p.hbp", "a.prg:5:12", "xNovo")
		reason, _ := env.Recusa()
		if reason != "memvar-has-more-than-one-creator" {
			t.Errorf("reason = %q, want memvar-has-more-than-one-creator", reason)
		}
		if !strings.Contains(env.Detail, "PROCA") || !strings.Contains(env.Detail, "PROCB") {
			t.Errorf("the refusal does not name both creators: %q", env.Detail)
		}
	})

	registra("refuse-rename-private-recursive-creator", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "p.hbp", "a.prg:5:12", "xNovo")
		reason, _ := env.Recusa()
		if reason != "memvar-has-more-than-one-creator" {
			t.Errorf("reason = %q, want memvar-has-more-than-one-creator", reason)
		}
	})
}
