package suite

import "testing"

// The OTHER direction, and the negative half that keeps it honest.
//
// The cursor is on `nLinhas` inside the header - in the RESULT of the
// `#xcommand`, not in its match. Pointing there used to get "'nLinhas' is not a
// match word of any project pp rule": true, and useless. It is not a word of the
// DSL (nobody writes it at a call site); it is a SYMBOL the rule writes into
// generated code, and the side of the rule is what separates the two - a fact of
// the position, not a choice.
//
// Both directions produce the SAME edit set, which is why they are one command:
// this case and `rename-local-written-by-directive` differ only in where the
// cursor was.
//
// The negative half is the point of the fixture. `Outra()` declares its own
// `LOCAL nLinhas` and never uses the command. A tool renaming by NAME would
// rewrite it and the reader would never know - it compiles either way, since
// renaming a local consistently is invisible in pcode. It is left alone because
// the tool renames what the directive BINDS: the site carries the index of the
// application that wrote it (`occurrences[].app`, delivered by the P24), and
// `Outra()` has no such site. `expected/` states this - lines 16 and 18 keep the
// old name on purpose, and the harness compares byte for byte.
func init() {
	registra("rename-directive-result-from-the-header", func(t *testing.T, p *Projeto) {
		// read BEFORE the run: the rename edits this very line, and the
		// assertion is about the word the site covered in the ORIGINAL text
		linha := p.Linha("cmdlog.ch", 0)
		env := p.Roda("rename", "app.hbp", "cmdlog.ch:1:29", "nTotal")

		if env.Exit != 0 {
			t.Fatalf("exit = %d, want 0 (detail: %s)", env.Exit, env.Detail)
		}
		if env.Result.Kind != "rule-written" {
			t.Errorf("kind = %q, want rule-written", env.Result.Kind)
		}
		if env.Result.Proof != "pcode-identical" {
			t.Errorf("proof = %q, want pcode-identical", env.Result.Proof)
		}

		// the site in the header points at the WORD, not at some column - if the
		// position drifted, this says which text it actually covered
		var noCh *Local
		for i := range env.Result.Locations {
			if l := &env.Result.Locations[i]; l.URI[len(l.URI)-len("cmdlog.ch"):] == "cmdlog.ch" {
				noCh = l
			}
		}
		if noCh == nil {
			t.Fatal("no edit in cmdlog.ch: the header is the side this direction starts from")
		}
		noCh.Aponta(t, linha, "nLinhas")

		// two binding sites (Main's local) and one directive occurrence. The
		// homonym in Outra() is NOT among them - `expected/` proves the file,
		// this proves the tool knew it, rather than editing and getting lucky.
		if env.Result.ApplicationSites != 2 || env.Result.DirectiveOccurrences != 1 {
			t.Errorf("sites = %d binding + %d directive, want 2 + 1: the local of Outra() "+
				"is a different variable and must not be in the set",
				env.Result.ApplicationSites, env.Result.DirectiveOccurrences)
		}
	})
}
