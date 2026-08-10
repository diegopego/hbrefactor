package suite

import (
	"strings"
	"testing"
)

// Naming a project function after a Harbour runtime function shadows the native
// one — a real consequence, and the tool knows it: `harbour.hbx` says which
// names the runtime owns.
//
// Until P36c that fact was a GATE: the rename stopped and asked for `--force`.
// Measured before removing it: the dangerous case — the project actually CALLS
// the function being shadowed — has its own hard refusal ("the rename would
// hijack those calls"), with no flag and no way around it. So the gate only
// ever stopped the harmless case, and the flag only ever taught people to type
// the flag. It is now what it always was: a note.
//
// The third name carries the load, and that is why it is here: `hb_MilliSeconds`
// is NOT linked into the tool's own binary. Recognising it proves the fact comes
// from the PROJECT's `harbour.hbx` — from the toolchain the user builds with —
// and not from whatever the hbrefactor process happens to carry inside itself.
//
// `--dry-run` on all three so the three commands see the same project, and
// `expected/` (identical to `source/`) proves nothing was written.
func init() {
	registra("new-function-name-shadowing-runtime-is-a-note", func(t *testing.T, p *Projeto) {
		for _, novo := range []string{"Len", "hb_ntos", "hb_MilliSeconds"} {
			env := p.Roda("rename", "fix01.hbp", "b.prg:19:10", novo, "--dry-run")

			if env.Status != "ok" {
				t.Errorf("%s: status = %q (%s), want ok - shadowing is a note", novo, env.Status, env.Detail)
			}
			if len(env.Diagnostics) != 1 || !strings.Contains(env.Diagnostics[0].Detail, novo) {
				t.Errorf("%s: the note does not name the function asked for: %+v", novo, env.Diagnostics)
				continue
			}
			if env.Diagnostics[0].Code != "shadows-runtime-function" {
				t.Errorf("%s: diagnostic code = %q", novo, env.Diagnostics[0].Code)
			}
		}
	})
}
