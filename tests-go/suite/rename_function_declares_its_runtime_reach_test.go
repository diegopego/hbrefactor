package suite

import "testing"

// The seal stops being mute about the border it does not cover.
//
// This rename is CORRECT for everything the compiler can see, and the proof is
// real: two edits, pcode byte-identical. It is also incomplete for something no
// compilation can see - line 6 assembles a name at run time and calls it, and
// after the rename that call finds nothing. Both statements are true at once,
// and before P36 the envelope carried only the first: `verified`, plus a
// `scope` saying `complete: true` about conditional compilation, which a reader
// naturally takes for "nothing was left out".
//
// The answer is NOT a refusal (Diego, 2026-07-27: macros are run time, the tool
// does not control them, and pretending otherwise is worse than saying so) -
// it is `reach`, a POSITIVE field, in the pattern P17 set for uncertainty:
// stated, never implied by absence. `complete: false` with the site named is
// the tool telling the user which line to go read.
//
// The fact under it is the compiler's, not a reading of the source: `usesMacro`
// comes from the pcode, so the assembled `"Dob" + "ro"` changes nothing about
// whether it is lit.
func init() {
	registra("rename-function-declares-its-runtime-reach", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "app.hbp", "app.prg:10:10", "Duplica")

		if env.Status != "ok" {
			t.Fatalf("status = %q (%s), want ok - macro reach declares, never refuses", env.Status, env.Detail)
		}
		if env.Result.Proof != "pcode-identical" {
			t.Errorf("proof = %q, want pcode-identical", env.Result.Proof)
		}
		if env.Result.Reach == nil {
			t.Fatal("no reach field - the seal would be mute about the run-time border")
		}
		if env.Result.Reach.Complete {
			t.Error("reach.complete = true, and line 6 evaluates a macro")
		}
		if len(env.Result.Reach.Runtime) != 1 || env.Result.Reach.Runtime[0].Line != 6 {
			t.Errorf("reach.runtime does not point at the macro line: %+v", env.Result.Reach.Runtime)
		}
	})
}
