package suite

import (
	"strings"
	"testing"
)

// The directive OWNS this variable: it declares it and uses it, entirely inside
// the code it generates. The `.prg` never writes the name.
//
// This is not a corner. Measured across 40 real modules of Harbour's own RTL
// plus its class-system exercise: of the 333 variables a directive writes, ALL
// 333 are like this - `hbclass.ch` creating `oClass`, `nScope`, `s_oClass` and
// consuming them itself. Not one core directive writes into a name the user
// declared. Owning the name is the healthy pattern; reaching into someone
// else's is the fragile one.
//
// So the two must not be confused, and the refusal is where that shows. The
// tool already did the safe thing - nothing is edited, and pointing at
// `hbclass.ch` leaves the installation untouched - but it said "no editable
// site found", which is true and useless: it sounds like the tool failed to
// look. The reader cannot tell "I aimed at the wrong thing" from "the tool is
// broken", and an agent reading it has no idea whether to retry.
//
// Now it names the owner. Renaming this would be an alpha-rename inside the
// directive, which is a different job with a different proof - and saying so is
// what keeps the user from hunting for a flag that does not exist.
func init() {
	registra("refuse-rename-variable-owned-by-the-directive", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "app.hbp", "conta.ch:1:29", "nContador")

		reason, action := env.Recusa()
		if reason != "variable-belongs-to-the-directive" {
			t.Errorf("reason = %q, want variable-belongs-to-the-directive", reason)
		}
		if action != "stop-and-report" {
			t.Errorf("action = %q, want stop-and-report", action)
		}
		// the message has to say WHOSE variable it is - that is the whole point
		if !strings.Contains(env.Detail, "declared AND used entirely by the directive") {
			t.Errorf("the refusal does not say who owns the variable: %q", env.Detail)
		}
		// and it must not read like a failure to look
		if strings.Contains(env.Detail, "no editable site") {
			t.Errorf("the refusal still reads as if the tool failed to look: %q", env.Detail)
		}
	})
}
