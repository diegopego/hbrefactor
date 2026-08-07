package suite

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"testing"
)

// W.2 — o lock de projeto serializa refatorações concorrentes.
//
// POR QUE ESTE NÃO É UM CASO DE `TestCasos`, e o motivo é medido: o cenário que
// prova o lock são dois renames no MESMO arquivo, e ali as `locations` são
// legitimamente não-determinísticas — o terceiro sítio de `nAcc` sai em `8:14`
// ou `8:11` conforme o outro rename já ter alongado aquela linha ou não. As duas
// respostas estão CERTAS: cada comando relata o arquivo que ele leu. Congelar uma
// delas num `outputs.json` seria fixar o resultado de uma corrida, e o caso
// passaria a oscilar por timing — a única coisa que um teste não pode fazer.
//
// O que É determinístico é o que interessa, e é o que este arquivo afirma: as
// duas edições sobrevivem, ninguém recusa, e quem não consegue a vez recebe uma
// recusa que diz REPETIR.

// projetoLock monta, num diretório temporário, um projeto de dois módulos com
// dois locais no mesmo arquivo — o menor que reproduz a corrida. Fica aqui, e
// não em testdata/, porque `TestCasos` cobra caso registrado para cada pasta de
// lá (e com razão: pasta sem caso é fixture que ninguém exercita).
func projetoLock(t *testing.T) (dir string, fonte string) {
	t.Helper()
	dir = t.TempDir()
	arquivos := map[string]string{
		"m.prg": "" +
			"FUNCTION Soma( nV )\n" +
			"\n" +
			"   LOCAL nAcc := 0\n" +
			"   LOCAL nOut := 0\n" +
			"\n" +
			"   nAcc += nV\n" +
			"   nOut += nAcc\n" +
			"\n" +
			"   RETURN nOut\n",
		"main.prg": "" +
			"PROCEDURE Main()\n" +
			"\n" +
			"   ? Soma( 1 )\n" +
			"\n" +
			"   RETURN\n",
		"p.hbp": "-w3\n-es2\nmain.prg\nm.prg\n",
	}
	for nome, texto := range arquivos {
		if err := os.WriteFile(filepath.Join(dir, nome), []byte(texto), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	return dir, arquivos["m.prg"]
}

func rodaEm(t *testing.T, dir string, extraEnv []string, argv ...string) (Envelope, string) {
	t.Helper()
	cmd := exec.Command(binario(t), append(argv, "--json")...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(), extraEnv...)
	var saida, erro strings.Builder
	cmd.Stdout, cmd.Stderr = &saida, &erro
	_ = cmd.Run()
	if s := erro.String(); strings.TrimSpace(s) != "" {
		t.Fatalf("stderr não está vazio:\n%s", s)
	}
	var env Envelope
	if err := json.Unmarshal([]byte(saida.String()), &env); err != nil {
		t.Fatalf("envelope ilegível: %v\n%.400s", err, saida.String())
	}
	return env, saida.String()
}

// Sem o lock isto perdia uma das duas refatorações em 5 de 12 rodadas (medido
// 2026-08-06, antes da W.2): um comando lê o arquivo, o outro o reescreve, e o
// primeiro descobre que o texto do sítio não confere mais — recusa e devolve o
// fonte byte a byte. Nada corrompe; o que se perde é TRABALHO, calado.
//
// PARES é o que torna este teste um portão e não um sorteio: com 5/12 de chance
// por rodada, a probabilidade de oito pares passarem sem lock é ~0,7%.
func TestLockSerializaRenamesConcorrentes(t *testing.T) {
	const pares = 8
	dir, fonte := projetoLock(t)
	alvo := filepath.Join(dir, "m.prg")

	for i := 0; i < pares; i++ {
		if err := os.WriteFile(alvo, []byte(fonte), 0o644); err != nil {
			t.Fatal(err)
		}
		var wg sync.WaitGroup
		envs := make([]Envelope, 2)
		for k, argv := range [][]string{
			{"rename", "p.hbp", "m.prg:3:10", "nSomaA"},
			{"rename", "p.hbp", "m.prg:4:10", "nSaidaB"},
		} {
			wg.Add(1)
			go func(k int, argv []string) {
				defer wg.Done()
				envs[k], _ = rodaEm(t, dir, nil, argv...)
			}(k, argv)
		}
		wg.Wait()

		for k, env := range envs {
			if env.Status != "ok" {
				reason, _ := env.Recusa()
				t.Fatalf("par %d, comando %d: status %q (reason %q) — sem serialização "+
					"uma das refatorações se perde", i, k, env.Status, reason)
			}
		}
		b, err := os.ReadFile(alvo)
		if err != nil {
			t.Fatal(err)
		}
		for _, nome := range []string{"nSomaA", "nSaidaB"} {
			if !strings.Contains(string(b), nome) {
				t.Fatalf("par %d: %q não está no arquivo — a edição foi perdida", i, nome)
			}
		}
	}
}

// Quem não consegue a vez tem de receber uma recusa que diz REPETIR — e não
// `stop-and-report`, que era o que a corrida produzia antes desta fatia
// (`unclassified` + "text on line N does not match"). O agente lia "pare e conte
// ao humano" sobre algo que bastava refazer.
//
// O lock é tomado aqui com fcntl(F_SETLK) porque é o que o Harbour usa
// (`src/rtl/filesys.c`) — no Linux, `flock()` e `fcntl()` são independentes, e um
// lock de flock não seria visto pela ferramenta: o teste passaria sem testar.
func TestLockRecusaComCodigoQuandoOutroProcessoSegura(t *testing.T) {
	dir, fonte := projetoLock(t)
	alvo := filepath.Join(dir, "m.prg")

	// descobre QUAL arquivo de lock é o deste projeto perguntando à própria
	// ferramenta: um comando de escrita cria o arquivo. Derivar a chave aqui
	// (MD5 de cwd+spec) seria replicar decisão dela — se ela mudar, o teste
	// segue verde travando o arquivo errado.
	if env, _ := rodaEm(t, dir, nil, "rename", "p.hbp", "m.prg:3:10", "nPrimeiro"); env.Status != "ok" {
		t.Fatalf("preparação falhou: %s", env.Status)
	}
	if err := os.WriteFile(alvo, []byte(fonte), 0o644); err != nil {
		t.Fatal(err)
	}
	locks, err := filepath.Glob(filepath.Join(os.TempDir(), "hbrefactor", "lock", "*.lock"))
	if err != nil || len(locks) == 0 {
		t.Fatalf("a ferramenta não criou arquivo de lock nenhum (%v)", err)
	}
	var alvoLock string
	for _, l := range locks { // o mais recente é o deste projeto
		if alvoLock == "" {
			alvoLock = l
			continue
		}
		a, _ := os.Stat(l)
		b, _ := os.Stat(alvoLock)
		if a != nil && b != nil && a.ModTime().After(b.ModTime()) {
			alvoLock = l
		}
	}

	f, err := os.OpenFile(alvoLock, os.O_RDWR, 0o644)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	trava := &syscall.Flock_t{Type: syscall.F_WRLCK, Whence: 0, Start: 0, Len: 1}
	if err := syscall.FcntlFlock(f.Fd(), syscall.F_SETLK, trava); err != nil {
		t.Fatalf("não consegui segurar o lock por fora: %v", err)
	}
	defer func() {
		solta := &syscall.Flock_t{Type: syscall.F_UNLCK, Whence: 0, Start: 0, Len: 1}
		_ = syscall.FcntlFlock(f.Fd(), syscall.F_SETLK, solta)
	}()

	// teto curto: sem o override, este único assert custaria os 30 s do default,
	// e portão caro é portão que alguém desliga
	env, _ := rodaEm(t, dir, []string{"HBREFACTOR_LOCK_WAIT_MS=300"},
		"rename", "p.hbp", "m.prg:3:10", "nNaoDeveEntrar")

	reason, action := env.Recusa()
	if reason != "project-busy-another-process" {
		t.Errorf("reason = %q, quero \"project-busy-another-process\" (status %q)",
			reason, env.Status)
	}
	if action != "retry-later" {
		t.Errorf("action = %q, quero \"retry-later\" — o agente precisa saber que "+
			"basta repetir, e não que deve parar e chamar um humano", action)
	}
	b, err := os.ReadFile(alvo)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(b), "nNaoDeveEntrar") {
		t.Error("a recusa editou o fonte — o rollback não é opcional")
	}
}
