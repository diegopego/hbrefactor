package suite

import (
	"strings"
	"testing"
)

// The severe half of P36, pinned. `__mvGet( "xC" + "fg" )` reads the PRIVATE
// by a name that only exists at RUN TIME - and before this phase the tool
// renamed it anyway, shipping `verified: 2 edit(s); symbol renamed, pcode
// byte-identical` over a program that then dies with
// `Error BASE/1003 Variable does not exist: xCfg`. The pcode WAS identical;
// the break lives in a string, which pcode identity cannot see by
// construction. What lied was the word verified reaching the user.
//
// The protection that existed was a string rule ("a literal equal to the
// memvar's name"), and one concatenation walked around it. What refuses now is
// a compiler fact: the core declares which of ITS functions resolve a symbol
// from a value computed at run time (ast-25), so the refusal holds however the
// name was written - assembled, read from a file, or never a literal at all.
//
// The name inside the string is never read here, and must never be: whether
// the string spells the memvar is exactly the question this phase refuses to
// ask. The call alone is the fact.
func init() {
	registra("refuse-rename-memvar-read-by-name-at-runtime", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "app.hbp", "app.prg:5:12", "xConf")

		reason, action := env.Recusa()
		if reason != "memvar-scope-not-closed" {
			t.Errorf("reason = %q, want memvar-scope-not-closed", reason)
		}
		if action != "stop-and-report" {
			t.Errorf("action = %q, want stop-and-report", action)
		}
		// the refusal has to NAME the call, or the agent cannot report it - and
		// an agent that cannot report goes back to editing the text by hand
		if len(env.Diagnostics) != 1 || !strings.Contains(env.Diagnostics[0].Detail, "__MVGET") {
			t.Errorf("the refusal does not name the call that resolves the name: %+v", env.Diagnostics)
		}
	})
}
