package suite

import "testing"

// The one place where the two sides genuinely cannot be made to agree.
//
// `? "hi"` expands through a rule the preprocessor carries COMPILED IN (std.ch
// is built into the pp), and that rule's result spells `QOut`. This project
// defines its own `FUNCTION QOut`, so the two are the same symbol - and the
// rename would have to change both. There is no file to change: the rule has no
// `file` and no line.
//
// So this refusal is not policy, it is physics, and that is why it survived the
// removal of every other gate on this path. The distinction matters to whoever
// reads the envelope: `stop-and-report` says "tell the human", and no flag,
// retry or permission changes the outcome. A code that hinted otherwise would
// send an agent looping - which is the failure mode the reason/action taxonomy
// exists to prevent.
//
// `expected/` is `source/` copied: nothing is touched, and the harness compares
// byte for byte. A refusal that edited first and rolled back would look the same
// on disk, so the case also pins WHEN it happens - before any compile cycle.
func init() {
	registra("refuse-rename-written-by-builtin-rule", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "q.hbp", "q.prg:7:10", "Emite")

		reason, action := env.Recusa()
		if reason != "name-written-by-builtin-rule" {
			t.Errorf("reason = %q, want name-written-by-builtin-rule - a bare "+
				"`unclassified` is indistinguishable from a code nobody thought about",
				reason)
		}
		if action != "stop-and-report" {
			t.Errorf("action = %q, want stop-and-report: no flag and no retry can "+
				"produce a directive file that does not exist", action)
		}
		if env.Exit != 1 {
			t.Errorf("exit = %d, want 1", env.Exit)
		}

		// the refusal NAMES the rule, so the human knows which one - and it says
		// `(builtin)` where a project rule would give file:line:col
		var achou bool
		for _, d := range env.Diagnostics {
			if d.Code == "name-also-written-by-directive" {
				achou = true
				if d.Location != nil {
					t.Errorf("the diagnostic carries a location (%v) for a rule that "+
						"has no file - inventing a position is worse than none", d.Location)
				}
			}
		}
		if !achou {
			t.Error("no diagnostic naming the rule: the refusal has to say WHICH rule " +
				"writes the name, or the reader cannot check it")
		}
	})
}
