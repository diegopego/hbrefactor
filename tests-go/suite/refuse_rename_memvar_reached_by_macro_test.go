package suite

import (
	"strings"
	"testing"
)

// The half that was already STRONG, pinned so it stays strong. The name the
// macro evaluates is assembled (`"Dob" + "ro"`), so no string rule could ever
// have caught it - and none is needed: the compiler scans the pcode for macro
// opcodes, so `usesMacro` is lit however the name was written. Sixteen macro
// forms were rewritten with assembled names and sixteen stayed lit (P36).
//
// Why a memvar rename REFUSES on macro while a function rename does not: a
// PRIVATE is renamed only when its dynamic scope CLOSES, and a macro evaluation
// inside that scope is an opening the static graph cannot follow. The function
// rename has no such closure to prove, so it ships and DECLARES the reach
// instead (rename-function-declares-its-runtime-reach).
//
// What this case adds beyond the refusal: the hole reaches the agent. Before
// P36 the refusal said "scope with holes" in the envelope and printed WHICH
// hole on stderr - so whoever read stdout, which is the normal thing in a pipe,
// got the verdict without the reason. Under a machine contract that is the same
// defect as no message at all.
func init() {
	registra("refuse-rename-memvar-reached-by-macro", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "app.hbp", "app.prg:5:12", "xConf")

		reason, _ := env.Recusa()
		if reason != "memvar-scope-not-closed" {
			t.Errorf("reason = %q, want memvar-scope-not-closed", reason)
		}
		if len(env.Diagnostics) != 1 {
			t.Fatalf("want exactly the macro hole, got %+v", env.Diagnostics)
		}
		d := env.Diagnostics[0]
		if !strings.Contains(d.Detail, "SHOW") {
			t.Errorf("the hole does not name the function that opens it: %q", d.Detail)
		}
		if d.Location == nil {
			t.Fatal("the hole has no location - the agent cannot show the user where")
		}
		d.Location.Aponta(t, p.Linha("app.prg", 14), "&")
	})
}
