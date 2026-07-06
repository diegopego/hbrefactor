# hbrefactor — extensão VSCode

Extensão **fina**: toda a análise (oráculo do compilador `-x`), a aplicação
das edições, a verificação e o rollback vivem no CLI `hbrefactor`. A extensão
coleta argumentos, invoca o CLI e mostra os resultados (canal "hbrefactor" +
painel de referências nativo).

## Requisitos

1. `hbrefactor` compilado (`make build` na raiz deste repo → `bin/hbrefactor`).
2. Harbour com o patch `-x` (branch `feature/refactoring-mechanism` do
   harbour-core) — o diretório dos binários vai na configuração `hbrefactor.hbBin`.
3. Projeto no workspace: `.hbp`, `.hbc` com `sources=` ou lista de `.prg`
   (qualquer alvo que o hbmk2 aceite; `hbrefactor.project` fixa a escolha).

## Instalação (desenvolvimento)

```sh
# link simbólico na pasta de extensões:
ln -s ~/devel/hbrefactor/vscode ~/.vscode/extensions/diegopego.hbrefactor-0.2.0
# ou empacotar: npx vsce package (dentro de vscode/)
```

Configuração (settings.json):

```json
{
  "hbrefactor.binPath": "~/devel/hbrefactor/bin/hbrefactor",
  "hbrefactor.hbBin": "~/devel/harbour-core/harbour/bin/linux/gcc",
  "hbrefactor.includePaths": "~/devel/harbour-core/harbour/contrib/hbct:~/devel/harbour-core/harbour/contrib/xhb"
}
```

`includePaths` (opcional) vira a env `INCLUDE` do compilador — necessário
quando o projeto usa headers de contrib (`hbzebra.ch`, `xhb.ch`, ...) e o
Harbour é a árvore de fontes (não uma instalação com os headers copiados).

## Comandos (Ctrl+Shift+P)

| Comando | O que faz |
|---|---|
| `hbrefactor: Usages` | Todas as referências do símbolo sob o cursor (variável, função, método **ou palavra de diretiva de pp**) no painel de referências + canal |
| `hbrefactor: Rename local/param under cursor` | Rename verificado de LOCAL/parâmetro (funciona dentro de `METHOD ... CLASS` — a extensão passa `Classe:Método` ao CLI) |
| `hbrefactor: Rename function under cursor` | Rename de função no projeto inteiro; se houver referências textuais, mostra os avisos e oferece prosseguir com `--force` |
| `hbrefactor: Rename directive/command word (pp DSL)` | Renomeia a palavra-cabeça de uma diretiva `#command`/`#xcommand`/`#[x]translate`/`#define` na definição (o `.ch`) **e** em todos os usos; o CLI verifica `.ppo`/`.hrb` byte-idênticos e faz rollback |
| `hbrefactor: Rename STATIC variable under cursor` | Rename de STATIC (de função ou file-wide) no módulo atual |
| `hbrefactor: Reorder parameters` | Nova ordem por nomes separados por vírgula |
| `hbrefactor: Extract selection to new function` | Extrai as linhas selecionadas para STATIC FUNCTION/PROCEDURE nova (locais exclusivas da seleção migram junto) |
| `hbrefactor: Unused locals` | Relatório de locais declaradas e não usadas / atribuídas e não lidas (W0003/W0032, projeto inteiro) |
| `hbrefactor: Call graph` | Quem chama quem — filtrado pela palavra sob o cursor, ou projeto inteiro |
| `hbrefactor: Find dynamic calls` | Auditoria dos pontos cegos: strings que nomeiam funções do projeto e funções com macro `&` |

Atalhos: associe nos seus keybindings (ex.: F2 → `hbrefactor.renameLocal`,
Shift+F12 → `hbrefactor.usages`).

## Notas

- Os arquivos são modificados **no disco pelo CLI** (que verifica e faz
  rollback); a extensão salva os editores antes de invocar e o VSCode
  recarrega os arquivos alterados. O "desfazer" é o git, não o Ctrl+Z.
- A única heurística local é achar o nome da `FUNCTION/PROCEDURE/METHOD`
  acima do cursor para montar a linha de comando — se errar, o CLI recusa
  com mensagem clara (nenhuma edição acontece por palpite).
- Em projetos legados com módulos que não compilam, os relatórios rodam em
  **cobertura parcial** (avisam quais módulos ficaram de fora) e os renames
  de módulo único (local/param/static) funcionam desde que o módulo alvo
  compile. Renames de projeto inteiro continuam exigindo o projeto são.
