package suite

import (
	"strings"
	"testing"
)

// A failing rename names its OWN cause, and drags in nothing that merely
// resembles one.
//
// `b.prg` includes the header but never uses `CMD_LOG`, so its `LOCAL nLinhas`
// is a different variable from the one the directive binds in `a.prg`. The
// rename then fails for a reason of its own: `nIL` reads as the reserved `NIL`
// in a case-insensitive language, and the compiler says so.
//
// This case is the residue of a helper that was REMOVED, and the removal is
// what it states. `DiagRuleWrites` (P25) attached "a directive also names this
// symbol" to the VERB `rename-local`, so that every failure on that path
// reported every rule mentioning the name. Its causal scenario - the header
// keeps the old name, so the pcode changes - was taken over by the P27, which
// renames both sides instead of refusing. What was left reaching it was this
// case, where the header is a coincidence: the tool blamed a `.ch` that had
// nothing to do with an E0030.
//
// The rule that came out of the five-whys is that the diagnostic belonged to
// the FACT, not to the verb - which is why it fired where it was a coincidence
// and stayed silent where it is the cause (a STATIC or a memvar written by a
// directive gets NO diagnostic at all today; see the P28 spec). So it is gone
// from here, and comes back where it is causal, with its own case.
//
// What this pins is the boundary, and it is meant to be uncomfortable to
// remove: a refusal may report everything it can prove, and may not promote a
// coincidence to a cause. An agent reading `diagnostics[]` decides what to tell
// a human from exactly this.
func init() {
	registra("refuse-rename-invalid-name-does-not-blame-the-directive", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "p.hbp", "b.prg:5:10", "nIL")

		reason, _ := env.Recusa()
		if reason != "compile-failed-rolled-back" {
			t.Errorf("reason = %q, want compile-failed-rolled-back - the name is "+
				"invalid; the header has nothing to do with it", reason)
		}

		var erro, aviso *Diagnostico
		for i := range env.Diagnostics {
			switch env.Diagnostics[i].Code {
			case "compiler-error":
				erro = &env.Diagnostics[i]
			case "name-also-written-by-directive":
				aviso = &env.Diagnostics[i]
			}
		}
		if erro == nil || !strings.Contains(erro.Detail, "E0030") {
			t.Fatalf("the real cause is missing from diagnostics[]: %+v", env.Diagnostics)
		}
		if erro.Severity != "error" {
			t.Errorf("severity of the cause = %q, want error - it is the severity that "+
				"lets a consumer rank diagnostics without parsing prose", erro.Severity)
		}

		// the boundary. cmdlog.ch DOES name `nLinhas`, and b.prg DOES include it,
		// so a tool matching by name has every excuse to mention it here. It must
		// not: b.prg never applies the command, and the failure is the reserved
		// word. Reporting the header alongside the real error is how a reader -
		// or an agent - ends up fixing the wrong file.
		if aviso != nil {
			t.Errorf("the refusal drags in a rule site that did not cause it: %q\n"+
				"the header names the symbol, but b.prg never applies the command - "+
				"the failure is E0030. A coincidence reported next to a cause reads "+
				"as a second cause.", aviso.Detail)
		}
	})
}
