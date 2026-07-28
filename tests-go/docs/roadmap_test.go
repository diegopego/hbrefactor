// Uma fase marcada ✅ ENTREGUE não pode ter sonda PENDENTE (⬜).
//
// Por que este portão existe (CLAUDE.md §1.7, cicatrizes §1.3e): a P20 foi
// marcada entregue com classes de caso que ninguém tinha sondado, e foi
// exatamente por ali que quatro defeitos passaram — o `col` de um send-escrita,
// a captura por codeblock, o incremento implícito do `FOR`, a leitura de
// variável de macro. A tabela de sondas é o `expected/` de uma extensão de
// core: cada classe de caso, o que o core responde HOJE, e o comando que
// produziu a resposta. Marcar ENTREGUE com linha em branco é dizer "provado"
// sobre o que não se perguntou.
//
// O que ele NÃO faz: julgar se a sonda foi boa, nem exigir tabela de quem não
// tem. Só cobra a coerência entre o selo e as marcas — a parte decidível.
package docs

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"

	"github.com/google/go-cmp/cmp"
)

type Fase struct {
	ID        string // "P20"
	Entregue  bool   // o cabeçalho traz o selo ✅ ENTREGUE
	Pendentes int    // quantos ⬜ o corpo da fase carrega
}

var (
	reFase = regexp.MustCompile(`(?m)^### (P\d+)\b(.*)$`)
	// o corpo de uma fase termina no PRÓXIMO TÍTULO, qualquer que seja o nível
	// — não no próximo `### P`. A diferença não é detalhe: parar só em fase
	// faria o corpo engolir as seções entre uma fase e a seguinte, e contar as
	// marcas delas como se fossem dela. (Achado pelo TestFases, e é por isso
	// que ele existe.)
	reTitulo = regexp.MustCompile(`(?m)^#{1,6} `)
)

// Fases devolve, na ordem do documento, o selo e as sondas pendentes de cada
// fase.
func Fases(texto string) []Fase {
	cabecas := reFase.FindAllStringSubmatchIndex(texto, -1)
	fora := make([]Fase, 0, len(cabecas))
	for _, c := range cabecas {
		fim := len(texto)
		if p := reTitulo.FindStringIndex(texto[c[1]:]); p != nil {
			fim = c[1] + p[0]
		}
		// o selo mora no cabeçalho; as marcas, no corpo depois dele
		cabeca := texto[c[0]:c[1]]
		corpo := texto[c[1]:fim]
		fora = append(fora, Fase{
			ID:        texto[c[2]:c[3]],
			Entregue:  strings.Contains(cabeca, "✅") && strings.Contains(cabeca, "ENTREGUE"),
			Pendentes: strings.Count(corpo, "⬜"),
		})
	}
	return fora
}

// O CONTROLE NEGATIVO do extrator (o padrão do TestExtrai): se o regex parar de
// casar, é ESTE teste que falha — e não a guarda que emudece, passando verde
// sobre um documento que ela deixou de ler. Ele não depende do roadmap real,
// que muda a cada sessão.
func TestFases(t *testing.T) {
	const amostra = "### P9 — título qualquer *(aberto 2026-01-01; **A RESOLVER**)*\n" +
		"corpo com uma sonda pendente ⬜ e outra ⬜\n" +
		"### P10 — outro *(aberto 2026-01-02; **✅ ENTREGUE 2026-01-03**)*\n" +
		"tudo verificado ✅ aqui\n" +
		"### P11 — terceiro *(**⚠ ENTREGUE, mas ver P12**)*\n" +
		"uma pendente ⬜\n" +
		"## Seção que não é fase\n" +
		"⬜ solto aqui fora não pertence a fase nenhuma\n"

	quero := []Fase{
		{ID: "P9", Entregue: false, Pendentes: 2},
		{ID: "P10", Entregue: true, Pendentes: 0},
		// ⚠ não é ✅: uma entrega retratada não é uma entrega selada
		{ID: "P11", Entregue: false, Pendentes: 1},
	}
	if d := cmp.Diff(quero, Fases(amostra)); d != "" {
		t.Errorf("o extrator mudou de comportamento (-quero +tenho):\n%s", d)
	}
}

func TestFaseEntregueNaoTemSondaPendente(t *testing.T) {
	caminho := filepath.Join(raiz(t), "docs", "roadmap.md")
	b, err := os.ReadFile(caminho)
	if err != nil {
		t.Fatalf("roadmap ilegível: %v", err)
	}
	fases := Fases(string(b))
	if len(fases) == 0 {
		t.Fatal("nenhuma fase lida do roadmap — o regex quebrou")
	}
	for _, f := range fases {
		if f.Entregue && f.Pendentes > 0 {
			t.Errorf("%s está marcada ✅ ENTREGUE com %d sonda(s) ⬜ pendente(s): "+
				"ou a sonda se roda e a linha vira ✅, ou o selo cai. "+
				"Marcar entregue sobre o que não se perguntou foi como a P20 "+
				"passou quatro defeitos (CLAUDE.md §1.7)", f.ID, f.Pendentes)
		}
	}
}
