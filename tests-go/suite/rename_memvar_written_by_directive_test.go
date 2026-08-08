package suite

import (
	"strings"
	"testing"
)

// A PRIVATE a directive writes renames too - and it does NOT go through the
// engine the LOCAL and the STATIC use.
//
// The difference is the proof, and it is not a detail. A memvar's name exists
// in the compiled program's symbol table, so "the pcode came out byte for byte
// identical" is not available and never will be: the bytes MUST change. The
// memvar verb has its own proof - the symbol table may differ in exactly one
// name, the old one becoming the new one, with every function's pcode and the
// symbol count and order untouched.
//
// That proof lives with the analysis that earns it: which function created the
// variable, which functions run while it is alive, whether the scope has holes,
// whether a macro creates it. Lifting the directive edits into the P27 engine
// would have meant lifting all of that, or inventing a proof neither verb has.
// So the directive's sites join THIS verb's edit set instead, through the same
// collector the engine uses - one answer to "which tokens of the `.ch` are this
// name", two proofs, because there are genuinely two.
//
// This case asserted a refusal until the slice landed. The verdict flipping is
// the slice; what it cost was the reporting layer built one slice earlier,
// which had nothing left to report once the tool could act instead.
func init() {
	registra("rename-memvar-written-by-directive", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "app.hbp", "app.prg:7:12", "nTotal")

		if env.Exit != 0 {
			t.Fatalf("exit = %d, want 0 (detail: %s)", env.Exit, env.Detail)
		}
		if env.Result.Kind != "memvar" {
			t.Errorf("kind = %q, want memvar - a PRIVATE keeps its own verb, and its "+
				"own proof; routing it through the LOCAL engine would claim a "+
				"byte-identity that cannot exist here", env.Result.Kind)
		}
		// the proof phrase is the memvar one, not the byte-identity one
		if !strings.Contains(env.Detail, "symbol renamed") {
			t.Errorf("detail = %q, want the memvar proof (symbol renamed): a memvar's "+
				"name IS in the pcode, so the bytes must change", env.Detail)
		}

		var tocouCh bool
		for _, loc := range env.Result.Locations {
			if strings.HasSuffix(loc.URI, "cmdlog.ch") {
				tocouCh = true
			}
		}
		if !tocouCh {
			t.Error("the header was not edited: the directive writes this name, and " +
				"leaving it behind is what made this case a refusal before")
		}
		// MEMVAR declaration, PRIVATE creation, the use, and the header
		if env.Result.EditCount != 4 {
			t.Errorf("editCount = %d, want 4 (MEMVAR + PRIVATE + use + header)",
				env.Result.EditCount)
		}
	})
}
