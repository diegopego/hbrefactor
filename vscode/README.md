# hbrefactor — extensão VSCode

Extensão **fina**: toda a análise (oráculo do compilador `-x`), a aplicação
das edições, a verificação e o rollback vivem no CLI `hbrefactor`. A extensão
coleta argumentos, invoca o CLI e mostra os resultados (canal "hbrefactor" +
painel de referências nativo).

## Requisitos

1. `hbrefactor` compilado (`make build` na raiz deste repo → `bin/hbrefactor`).
2. Harbour com o patch `-x` (branch `feature/compiler-ast-dump` do
   harbour-core) — o diretório dos binários vai na configuração
   `hbrefactor.hbBin`, cujo **default já é o layout do repo**
   (`~/devel/harbour-core/harbour/bin/linux/gcc`, o mesmo do Makefile);
   só configure se a árvore estiver em outro lugar. Sem um `hbBin`
   válido o CLI cai no hbmk2 do PATH (sem `-x`) e todo comando morre
   com "o projeto não compila" — o CLI agora nomeia essa causa no erro.
3. Projeto no workspace: `.hbp`, `.hbc` com `sources=` ou lista de `.prg`
   (qualquer alvo que o hbmk2 aceite; `hbrefactor.project` fixa a escolha).
   Com **vários** `.hbp`/`.hbc` no workspace, o picker é **ciente do
   arquivo**: a extensão pergunta ao CLI (`projects-of`, fato do hbmk2 —
   a extensão nunca parseia `.hbp`) de quais projetos o arquivo em foco é
   fonte — dono único entra direto sem pergunta; fonte compartilhada
   pergunta só entre os donos; arquivo órfão (ou pergunta falhada) cai
   para a lista completa, o comportamento antigo.

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
| `hbrefactor: Usages` | Todas as referências do símbolo sob o cursor (variável, função, método **ou palavra de diretiva de pp**) no painel de referências + canal. No canal, o relato inclui o que a expansão fabrica (`-> CAIXA_SOMA`, `-> derives ...`): a extensão passa `--show-expansion` sempre — diferente do CLI pelado, cujo default omite os nomes gerados; o painel de referências segue no vocabulário do fonte (o `--json` não muda com o flag) |
| `hbrefactor: Rename Symbol under cursor` | **Rename unificado (F2)**: você dá só a POSIÇÃO; o kind — local, parâmetro, STATIC, memvar, função, método, palavra de DSL ou marker de diretiva — vem do FATO da árvore, não de um comando por-espécie. Pede `--edit-rules`/`--force` quando o nome é citado em diretiva ou em strings, e recusa nomeando a exceção se a posição não tem símbolo de compilação. **É o único comando de rename** — os quatro por-kind foram REMOVIDOS na fase U (fatia 2). |
| `hbrefactor: Reorder parameters` | Nova ordem por nomes separados por vírgula |
| `hbrefactor: Extract selection to new function` | Extrai as linhas selecionadas para STATIC FUNCTION/PROCEDURE nova (locais exclusivas da seleção migram junto) |
| `hbrefactor: Unused locals` | Relatório de locais declaradas e não usadas / atribuídas e não lidas (W0003/W0032, projeto inteiro) |
| `hbrefactor: Call graph` | Quem chama quem — filtrado pela palavra sob o cursor, ou projeto inteiro |
| `hbrefactor: Find dynamic calls` | Auditoria dos pontos cegos: strings que nomeiam funções do projeto e funções com macro `&` |

Atalhos: associe nos seus keybindings (ex.: F2 → `hbrefactor.rename`,
Shift+F12 → `hbrefactor.usages`).

## Notas

- Os arquivos são modificados **no disco pelo CLI** (que verifica e faz
  rollback); a extensão salva os editores antes de invocar e o VSCode
  recarrega os arquivos alterados. O "desfazer" é o git, não o Ctrl+Z.
- O **Rename Symbol** não tem heurística: passa a POSIÇÃO do cursor ao CLI,
  que resolve o kind pelo FATO da árvore; se a posição não tem símbolo de
  compilação, recusa nomeando o motivo (nenhuma edição por palpite). Só o
  *Reorder parameters* ainda procura a `FUNCTION/PROCEDURE/METHOD` acima do
  cursor.
- Em projetos legados com módulos que não compilam, os relatórios rodam em
  **cobertura parcial** (avisam quais módulos ficaram de fora) e o rename de
  símbolo de módulo único funciona desde que o módulo alvo compile. Rename de
  projeto inteiro (função/método/marker) continua exigindo o projeto são.
