package suite

import "testing"

// `"nBase"` and `nBase` are two different things, and the tool used to treat
// them as one (Diego, 2026-08-09, looking at this exact fixture: *"'nBase' é
// diferente de hb_ntos( nBase * 2 ) - portanto não se compara com o stringify
// da diretiva de PP"*). The string is a label being printed; the variable is
// the value. Nothing but their spelling connects them, and spelling is not a
// fact.
//
// So this inline goes through, and the string is left exactly as written. The
// refusal that used to fire here claimed to guard against reaching the local
// by name at run time — which cannot happen: a macro naming a LOCAL resolves
// to a memvar, not to the local (measured in P22). It guarded nothing and
// blocked this.
//
// The other half of that rule survives, and has its own case: when a directive
// STRINGIFIES the identifier, the compiler says so (`from: [{op: "stringify"}]`)
// and inlining would leave that string naming a variable that no longer exists.
// Same verb, same shape on screen, opposite verdict — because one of them is a
// fact and the other was a guess.
func init() {
	registra("inline-local-beside-a-string-that-is-just-data", func(t *testing.T, p *Projeto) {
		env := p.Roda("inline-local", "app.hbp", "app.prg", "Main", "nBase")

		if env.Status != "ok" {
			t.Fatalf("status = %q (%s), want ok", env.Status, env.Detail)
		}
		if len(env.Diagnostics) != 0 {
			t.Errorf("a data string should raise nothing: %+v", env.Diagnostics)
		}
	})
}
