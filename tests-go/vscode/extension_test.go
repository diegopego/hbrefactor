// A extensão VSCode decide fluxo pelo CAMPO do envelope, nunca casando a prosa.
//
// Por que isto é um portão: a fase W.2 criou uma recusa cuja ação é REPETIR
// (`retry-later`) — outro processo está refatorando o mesmo projeto, o pedido
// continua válido. Se a extensão a tratar como as demais, ela manda o usuário
// chamar um humano por algo que bastava refazer, e NINGUÉM reprova: o CLI segue
// certo, e só o consumidor de uso diário fica mal informado. O §5 do CLAUDE.md
// diz que expor a capacidade na extensão é escopo da fase que a entrega — este
// teste é o que faz esse "escopo" ter dente.
//
// Por que ele delega a um harness JS em vez de reimplementar em Go: o harness
// EXTRAI as funções reais do extension.js e as EXECUTA (técnica do caso 71).
// Um teste que lesse o arquivo e casasse texto provaria que a fonte "parece
// certa"; executar `envelopeOf` com um envelope de verdade prova que ela É.
// Go aqui orquestra e reporta — a execução do JS é do node.
package vscode

import (
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestExtensaoLeOEnvelopePorCampo(t *testing.T) {
	harness := filepath.Join("..", "..", "vscode", "test-envelope.js")

	if _, err := exec.LookPath("node"); err != nil {
		// nem passar calado nem falhar confuso: o §1.3e é sobre isto - guarda
		// que emudece passa verde sem verificar nada, e ambiente incompleto
		// tem de se NOMEAR em vez de parecer defeito da ferramenta
		t.Fatalf("node ausente nesta máquina (rode `make deps`): o harness da "+
			"extensão é JS, e sem ele este portão não verifica nada — %v", err)
	}

	saida, err := exec.Command("node", harness).CombinedOutput()
	if err != nil {
		t.Errorf("o harness da extensão reprovou:\n%s", saida)
		return
	}
	// o harness imprime "N pass, M fail" no fim; zero check é tão ruim quanto
	// check falhando - seria um portão que roda e não cobra nada
	txt := string(saida)
	if !strings.Contains(txt, " pass,") || strings.Contains(txt, "FAIL") {
		t.Errorf("saída inesperada do harness:\n%s", txt)
	}
	if strings.Contains(txt, "0 pass,") {
		t.Errorf("o harness não executou check nenhum:\n%s", txt)
	}
}
