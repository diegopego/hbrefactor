package suite

import (
	"strings"
	"testing"
)

// A file-wide STATIC lives in the module's pseudo function, and usages used
// to skip that pseudo function whole - so the one site that CREATES the
// variable (its declaration, plus the initializer's own write) was the one
// site never listed, while every use in real functions appeared. The gap was
// measured in the P31 probes and is item 4 of that phase: the reader saw the
// variable's whole life except its birth.
//
// The pseudo function is still NOT a function: it takes no definition match,
// no --func match, and no owner name - the sites say "file-wide" instead.
func init() {
	registra("usages-filewide-static-declaration", func(t *testing.T, p *Projeto) {
		env := p.Roda("usages", "p.hbp", "nTot")

		if env.Exit != 0 {
			t.Fatalf("exit = %d (detail: %s)", env.Exit, env.Detail)
		}
		if env.Result.Total != 4 {
			t.Errorf("total = %d, want 4 (declaration + initializer write + write + read)",
				env.Result.Total)
		}
		var decl bool
		for _, l := range env.Result.Locations {
			if strings.Contains(l.Kind, "declaration") && strings.Contains(l.Kind, "file-wide") {
				decl = true
			}
		}
		if !decl {
			t.Error("the file-wide declaration is still missing from the locations")
		}
	})
}
