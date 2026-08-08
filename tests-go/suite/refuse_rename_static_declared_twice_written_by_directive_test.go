package suite

import (
	"strings"
	"testing"
)

// Two function-scoped STATICs of the same name, in two functions, both using
// the command. Harbour allows it and they are DIFFERENT variables - and the
// same directive writes into both.
//
// This is the case that told me the slice was not finished. The refusal was
// already safe (nothing edited), but it said "use --func", and the unified
// `rename` has no such flag: it was telling the reader to do something that
// cannot be done. A refusal that names an impossible next step is worse than a
// blunt one, because an agent will try it, fail, and fall back to editing text
// by hand - the failure mode this tool exists to remove.
//
// What the refusal owes here is the shape of the problem: the rule ties two
// distinct variables together, so renaming one of them is not a smaller version
// of the job - it is a wrong job. Fixing it means renaming both plus the header,
// which is a slice of its own; until then this says so, with a code of its own.
//
// The warning that names the header stays, because here it IS the cause.
func init() {
	registra("refuse-rename-static-declared-twice-written-by-directive", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "app.hbp", "app.prg:5:11", "nTotal")

		reason, action := env.Recusa()
		if reason != "static-declared-more-than-once" {
			t.Errorf("reason = %q, want static-declared-more-than-once", reason)
		}
		if action != "stop-and-report" {
			t.Errorf("action = %q, want stop-and-report", action)
		}
		// the point of the case: no flag is suggested, because none would work
		if strings.Contains(env.Detail, "--") {
			t.Errorf("the refusal offers a flag: %q - the unified rename takes no "+
				"--func, and pointing at a flag that does not exist sends the reader "+
				"(or an agent) down a path that cannot succeed", env.Detail)
		}
		if !strings.Contains(env.Detail, "more than one place") {
			t.Errorf("the refusal does not say WHAT is wrong: %q", env.Detail)
		}
	})
}
