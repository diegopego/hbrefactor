package suite

import (
	"strings"
	"testing"
)

// The other half of the P32 drag: the same directive call binds to a module
// STATIC in f2 and DYNAMICALLY in f4 (which defines no homonym - its call
// reaches the public Remessa of f5). One edit set cannot serve both sides:
// dragging the header would re-point f4's expansion at a name that does not
// exist there, and not dragging it would strand f2. The refusal has its own
// code and names the binding PER MODULE - the reader learns the shape of the
// problem, not just that something failed. Sources stay byte-for-byte intact
// (expected/ == source/).
func init() {
	registra("refuse-rename-static-function-mixed-binding", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "p.hbp", "f2.prg:9:17", "RemessaB")

		reason, action := env.Recusa()
		if reason != "directive-binds-static-and-dynamic" {
			t.Errorf("reason = %q, want directive-binds-static-and-dynamic", reason)
		}
		if action != "stop-and-report" {
			t.Errorf("action = %q, want stop-and-report", action)
		}
		for _, mod := range []string{"f2.prg", "f4.prg"} {
			if !strings.Contains(env.Detail, mod) {
				t.Errorf("the per-module map does not name %s: %q", mod, env.Detail)
			}
		}
	})
}
