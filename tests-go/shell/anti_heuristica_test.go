// O portão anti-heurística barra o commit de `src/hbrefactor.prg` cujo diff
// staged cheire aos gatilhos do CLAUDE.md § 1.2. Ele é o mecanismo que a §1.6
// exige — "regra nova sem portão novo é regra que eu vou violar de novo" — e
// até 2026-08-08 ele mesmo não tinha teste nenhum.
//
// Isso importa porque um portão silencioso falha na direção PERIGOSA: se o
// regex parar de casar, ele passa VERDE e ninguém percebe. É o mesmo defeito da
// primeira versão do portão dos docs, e a razão de este arquivo existir.
//
// A dívida virou urgente quando a P27 EDITOU o portão (apagou a regra 2, que
// acusava 54 linhas do fonte e nenhuma heurística). Mexer num portão sem teste
// é a única coisa pior que não ter o portão.
//
// O que se prova aqui são as duas direções, e a segunda é a que dói: barrar o
// que deve barrar, e DEIXAR PASSAR o que é legítimo. Um portão que barra tudo
// é abandonado em uma semana, e leva os outros junto.
package shell

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

const baseFonte = "// fonte de mentira, só para o diff ter um arquivo\nSTATIC FUNCTION X()\n   RETURN NIL\n"

// monta um repositório git de mentira com src/hbrefactor.prg commitado, aplica
// `linha` como adição staged, e devolve (saída do hook, saiu-não-zero).
func rodaHook(t *testing.T, linha string) (string, bool) {
	t.Helper()

	hook, err := filepath.Abs(filepath.Join("..", "..", ".claude", "hooks", "anti-heuristica.sh"))
	if err != nil || !existe(hook) {
		t.Fatalf("hook não encontrado em %s", hook)
	}
	dir := t.TempDir()
	alvo := filepath.Join(dir, "src", "hbrefactor.prg")
	if err := os.MkdirAll(filepath.Dir(alvo), 0o755); err != nil {
		t.Fatal(err)
	}
	escreve(t, alvo, baseFonte)

	git := func(arg ...string) {
		t.Helper()
		c := exec.Command("git", arg...)
		c.Dir = dir
		c.Env = append(os.Environ(),
			"GIT_AUTHOR_NAME=t", "GIT_AUTHOR_EMAIL=t@t",
			"GIT_COMMITTER_NAME=t", "GIT_COMMITTER_EMAIL=t@t")
		if out, err := c.CombinedOutput(); err != nil {
			t.Fatalf("git %v: %v\n%s", arg, err, out)
		}
	}
	git("init", "-q")
	git("add", "-A")
	git("commit", "-qm", "base")

	escreve(t, alvo, baseFonte+linha+"\n")
	git("add", "src/hbrefactor.prg")

	// executado DIRETO, honrando o shebang, como o settings.json faz. Invocar
	// com `sh` fazia o dash morrer em `set -o pipefail`, e o teste acusava o
	// portão de um defeito que era do instrumento (CLAUDE.md §1.7.7)
	c := exec.Command(hook)
	c.Dir = dir
	c.Stdin = strings.NewReader(`{"tool_name":"Bash","tool_input":{"command":"git commit -m x"}}`)
	saida, err := c.CombinedOutput()
	return string(saida), err != nil
}

func existe(p string) bool { _, err := os.Stat(p); return err == nil }

func escreve(t *testing.T, p, s string) {
	t.Helper()
	if err := os.WriteFile(p, []byte(s), 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestPortaoAntiHeuristica(t *testing.T) {
	casos := []struct {
		nome   string
		linha  string
		barra  bool
		porque string
	}{
		{
			nome:   "comparação de texto para decidir identidade",
			linha:  `   IF Upper( cAlgum ) == Upper( cOutro )`,
			barra:  true,
			porque: "gatilho 1: o dump tem id/número, e comparar TEXTO para decidir papel é a heurística que a ferramenta existe para matar",
		},
		{
			nome:   "aridade da linha de comando NÃO é gramática",
			linha:  `   IF Len( aArgs ) < 6`,
			barra:  false,
			porque: "a regra que acusava isto foi apagada em 2026-08-07: media 54 linhas do fonte e nenhuma era heurística - todas contam argumentos da CLI ou itens de lista",
		},
		{
			nome:   "o selo FATO-OK deixa passar o que o Diego autorizou",
			linha:  `   IF Upper( cAlgum ) == Upper( cOutro )   // FATO-OK(diego,2026-01-01): o core não dá este fato`,
			barra:  false,
			porque: "autorização POR-CASO é o escape previsto no CLAUDE.md §1.1; sem ele o portão não teria saída legítima",
		},
		{
			nome:   "arquivo por basename como CHAVE",
			linha:  `   hMapa[ hb_FNameNameExt( cPath ) ] := hAst`,
			barra:  true,
			porque: "gatilho 5: dois .ch homônimos de diretórios distintos colidem quando o basename decide identidade",
		},
	}

	for _, c := range casos {
		t.Run(c.nome, func(t *testing.T) {
			saida, barrou := rodaHook(t, c.linha)
			if barrou != c.barra {
				verbo := map[bool]string{true: "BARRAR", false: "DEIXAR PASSAR"}
				t.Errorf("o portão devia %s e não %s\nlinha:   %s\nporquê:  %s\nsaída:\n%s",
					verbo[c.barra], verbo[barrou], c.linha, c.porque, saida)
			}
			if c.barra && !strings.Contains(saida, "BARRADO") {
				t.Errorf("barrou sem dizer que barrou - a saída é o que o autor lê:\n%s", saida)
			}
		})
	}
}

// e o portão só olha `git commit`: qualquer outro comando passa direto, senão
// ele viraria um imposto sobre todo uso do shell.
func TestPortaoIgnoraOutrosComandos(t *testing.T) {
	hook, _ := filepath.Abs(filepath.Join("..", "..", ".claude", "hooks", "anti-heuristica.sh"))
	c := exec.Command(hook)
	c.Dir = t.TempDir()
	c.Stdin = strings.NewReader(`{"tool_name":"Bash","tool_input":{"command":"ls -la"}}`)
	if out, err := c.CombinedOutput(); err != nil {
		t.Errorf("o portão barrou um comando que não é commit: %v\n%s", err, out)
	}
}
