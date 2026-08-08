package suite

import (
	"strings"
	"testing"
)

// A FUNCTION name in a directive's result, with module-scoped homonyms: three
// modules define `STATIC FUNCTION Remessa`, two include the header whose
// command calls it, one does not. Each application binds to ITS module's
// static - the same result text, different functions.
//
// Renaming f2's static drags the shared header, and the header drags f3 -
// whose own static would then be orphaned. Refusing and rolling back is
// CORRECT: no edit set confined to f2 can keep the project compiling.
//
// What this case pins beyond the refusal is a DEFECT, deliberately, the way
// the work-area-field case once was: the message blames f1 - the module that
// never includes the header, whose static is a legitimate stranger - and
// never mentions f3, the module that would actually break. Whoever fixes the
// verification to name the right module (P31 item 3) turns this red, and
// updating the pinned detail is then a conscious act, not drift.
func init() {
	registra("refuse-rename-static-function-cited-by-directive", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "p.hbp", "f2.prg:9:17", "RemessaB")

		reason, _ := env.Recusa()
		if reason != "verification-failed-rolled-back" {
			t.Errorf("reason = %q, want verification-failed-rolled-back", reason)
		}
		// the rule site arrives as data, so the reader knows a directive is involved
		var aviso *Diagnostico
		for i := range env.Diagnostics {
			if env.Diagnostics[i].Code == "name-also-written-by-directive" {
				aviso = &env.Diagnostics[i]
			}
		}
		if aviso == nil {
			t.Fatal("no diagnostic naming the rule site: without it the reader cannot " +
				"tell this rollback from an unrelated one")
		}
		if !strings.Contains(aviso.Detail, "fn.ch") {
			t.Errorf("the diagnostic does not name the header: %q", aviso.Detail)
		}
		// `expected/` == `source/`: the rollback left all three modules and the
		// header byte for byte intact - that half is behaviour to KEEP.
	})
}
