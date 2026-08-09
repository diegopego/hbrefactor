package suite

import (
	"strings"
	"testing"
)

// Disjoint reaches, but one MODULE hosts sites of both chains: both.prg has
// UsaUm (reached by ProcA's private) and ProcB (the other creator). Its
// file-wide MEMVAR declaration serves the two chains at once, so renaming
// chain A would need the new name ADDED to that list while the old one stays
// - one symbol more, which renumbers the module's symbol table and leaves the
// edited functions without the one-symbol-substitution proof this verb gives.
// Editing without proof is what this tool does not do: the refusal names the
// shared module, and the sources stay byte-for-byte intact (expected/ ==
// source/). Lifting this needs a proof that survives renumbering per edited
// function - the honest boundary of P29's slice.
func init() {
	registra("refuse-rename-private-disjoint-creators-sharing-a-module", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "p.hbp", "a.prg:5:12", "xNovo")

		reason, action := env.Recusa()
		if reason != "memvar-has-more-than-one-creator" {
			t.Errorf("reason = %q, want memvar-has-more-than-one-creator", reason)
		}
		if action != "stop-and-report" {
			t.Errorf("action = %q, want stop-and-report", action)
		}
		if !strings.Contains(env.Detail, "both.prg") {
			t.Errorf("the refusal does not name the shared module: %q", env.Detail)
		}
	})
}
