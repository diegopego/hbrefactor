package suite

import (
	"strings"
	"testing"
)

// A refusal has to TELL the cause, not just the effect.
//
// A `#xcommand` (CMD_LOG) writes `nLinhas` in the header; the programmer sees
// `LOCAL nLinhas` in their own `.prg` and renames it - the most natural
// refactoring there is, and nothing in their file warns about the header. The
// tool edits, recompiles, the pcode changes, and it rolls back. Right. But
// saying only "the pcode changed" leaves the programmer without the next step,
// and pushes an agent back to text substitution - the very failure mode this
// tool exists to eliminate (CLAUDE.md §1.6).
func init() {
	registra("refuse-rename-name-also-written-by-directive", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "app.hbp", "app.prg:5:10", "nTotalLinhas")

		// the VERDICT does not change: same refusal, same reason
		reason, action := env.Recusa()
		if reason != "verification-failed-rolled-back" || action != "stop-and-report" {
			t.Errorf("refusal = %q/%q, want verification-failed-rolled-back/stop-and-report",
				reason, action)
		}
		if env.Exit != 1 {
			t.Errorf("exit = %d, want 1", env.Exit)
		}

		// what CHANGES: the cause comes named, with where to look
		var achou *Diagnostico
		for i := range env.Diagnostics {
			if env.Diagnostics[i].Code == "name-also-written-by-directive" {
				achou = &env.Diagnostics[i]
			}
		}
		if achou == nil {
			t.Fatal("no `name-also-written-by-directive` diagnostic: the tool KNOWS " +
				"the header writes the name (usages says so) and does not tell it in the refusal")
		}
		if !strings.Contains(achou.Detail, "cmdlog.ch") {
			t.Errorf("the diagnostic does not name the file: %q", achou.Detail)
		}

		// and the rollback is real: `expected/` is `source/` copied, and the
		// harness compares the two byte for byte
	})
}
