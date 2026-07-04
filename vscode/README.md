# hbrefactor — extensão VSCode

Extensão **fina**: toda a análise (oráculo do compilador `-x`), a aplicação
das edições, a verificação e o rollback vivem no CLI `hbrefactor`. A extensão
coleta argumentos, invoca o CLI e mostra os resultados (canal "hbrefactor" +
painel de referências nativo).

## Requisitos

1. `hbrefactor` compilado (`make build` na raiz deste repo → `bin/hbrefactor`).
2. Harbour com o patch `-x` (branch `feature/refactoring-mechanism` do
   harbour-core) — o diretório dos binários vai na configuração `hbrefactor.hbBin`.
3. Projeto com `.hbp` no workspace (ou `hbrefactor.project` apontando para ele).

## Instalação (desenvolvimento)

```sh
# link simbólico na pasta de extensões:
ln -s ~/devel/hbrefactor/vscode ~/.vscode/extensions/diegopego.hbrefactor-0.1.0
# ou empacotar: npx vsce package (dentro de vscode/)
```

Configuração (settings.json):

```json
{
  "hbrefactor.binPath": "~/devel/hbrefactor/bin/hbrefactor",
  "hbrefactor.hbBin": "~/devel/harbour-core/harbour/bin/linux/gcc"
}
```

## Comandos (Ctrl+Shift+P)

| Comando | O que faz |
|---|---|
| `hbrefactor: Usages` | Todas as referências do símbolo sob o cursor (variável ou função) no painel de referências + canal |
| `hbrefactor: Rename local/param under cursor` | Rename verificado de LOCAL/parâmetro (função detectada acima do cursor; o CLI valida contra o oráculo) |
| `hbrefactor: Rename function under cursor` | Rename de função no projeto inteiro; se houver referências textuais, mostra os avisos e oferece prosseguir com `--force` |
| `hbrefactor: Reorder parameters` | Nova ordem por nomes separados por vírgula |
| `hbrefactor: Extract selection to new function` | Extrai as linhas selecionadas para STATIC FUNCTION/PROCEDURE nova |

Atalhos: associe nos seus keybindings (ex.: F2 → `hbrefactor.renameLocal`,
Shift+F12 → `hbrefactor.usages`).

## Notas

- Os arquivos são modificados **no disco pelo CLI** (que verifica e faz
  rollback); a extensão salva os editores antes de invocar e o VSCode
  recarrega os arquivos alterados. O "desfazer" é o git, não o Ctrl+Z.
- A única heurística local é achar o nome da `FUNCTION/PROCEDURE` acima do
  cursor para montar a linha de comando — se errar, o CLI recusa com
  mensagem clara (nenhuma edição acontece por palpite).
