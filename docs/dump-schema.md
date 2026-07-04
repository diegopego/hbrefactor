# Schema do dump de ocorrências (contrato harbour-core ↔ hbrefactor)

Interface entre o patch do compilador (gravador de ocorrências, branch do harbour-core) e o hbrefactor. **Este arquivo é o contrato**: mudanças aqui exigem bump de `schema` e são sempre **aditivas** (consumidor ignora campos desconhecidos) — mudar o patch upstream é caro, mudar o hbrefactor é barato ([roadmap.md](roadmap.md), concessão ao "pensar grande").

## Flag implementado

**`-x[<arquivo>]`** — espelha o precedente do `-j[<file>]` (i18n/compi18n): acumula durante o parse, despeja no fim da geração de código do módulo. Sem `<arquivo>`: `<fonte>.occ.json`. (O plano original propunha `-y`, mas `case 'Y'` já existe no cmdcheck.c sob `#ifdef YYDEBUG`; `x` estava genuinamente livre.) Zero efeito sem o flag — verificado: `.hrb` gerado com o compilador patcheado sem `-x` é byte-idêntico ao do compilador original.

**Implementação (patch v1, branch `feature/refactoring-mechanism`)**: novo `src/compiler/compoccur.c` + hooks mínimos. Ponto de gravação: **dentro de `hb_compVariableFind()`** — grava só quando o chamador passa `piPos != NULL` (referência real gerando código); consultas de escopo passam `NULL` e são ignoradas. Isso cobre também os caminhos otimizados de `include/hbexprb.c` (`nVar++`, `nVar += n` → `HB_P_LOCALINCPUSH`/`LOCALADDINT`) que **não** passam pelos geradores comuns — lacuna encontrada em teste real e fechada com essa estratégia. Os geradores `hb_compGenPushVar/PopVar/PushVarRef` refinam o acesso do último registro via `hb_compOccurTag()`.

## Fontes dos dados (verificado no fonte, ver inventário)

| Dado | Origem no compilador |
|---|---|
| Ocorrência de variável + escopo resolvido | `hb_compVariableFind()` (`hbmain.c:685`) via `hb_compGenPushVar/PopVar/PushVarRef` (`hbmain.c:2730-2868`) |
| Acesso read/write/ref | qual gerador chamou (Push=read, Pop=write, PushRef=ref) |
| Linha | `HB_COMP_PARAM->currLine` |
| Declarações + linha da declaração + nº de usos | listas `pLocals/pStatics/...` (`HB_HVAR.iDeclLine`, `iUsed`) no fim de cada função |
| Chamadas de função (schema v1: campo reservado; preenchido no patch v2/Fase 1) | `hb_compGenPushFunCall/PushFunSym` (`hbmain.c:3049,3065`) |
| Função usa macro `&` | emissão de qualquer `HB_P_MACRO*` no corpo |
| Módulo contém BEGINDUMP | callback `pDumpFunc` do pp |

**Coluna: ausente por design.** O compilador conhece linha, não coluna (inventário §1.4); a coluna é resolvida pelo hbrefactor re-tokenizando a linha original com o lexer do pp. Ocorrências múltiplas do mesmo símbolo na mesma linha ficam na **ordem do parse** — o consumidor casa por ordem com os tokens homônimos da linha.

## Formato (schema 1)

```json
{
  "schema": 1,
  "generator": "harbour 3.2.0dev",
  "module": "caminho/como/compilado/arquivo.prg",
  "hasCDump": false,
  "functions": [
    {
      "name": "MAIN",
      "kind": "function",
      "static": false,
      "line": 7,
      "usesMacro": true,
      "declarations": [
        { "sym": "nCount", "scope": "local", "declLine": 9, "used": 2, "param": false }
      ],
      "occurrences": [
        { "sym": "nCount", "scope": "local", "line": 9,  "access": "write" },
        { "sym": "nCount", "scope": "detached", "line": 10, "access": "read", "block": true }
      ],
      "calls": []
    }
  ]
}
```

### Campos

- **`scope`** — mapeamento de `HB_VS_*` (`include/hbcomp.h:87-98`):
  `local` (LOCAL/parâmetro) · `detached` (local capturada por codeblock, `HB_VS_CBLOCAL_VAR`) · `static` · `field` · `memvar` (declarada MEMVAR/PRIVATE/PUBLIC) · `memvar_implicit` (`HB_VS_UNDECLARED` — não declarada) — os bits `HB_VS_FILEWIDE` viram `"filewide": true`.
- **`access`** — `read` | `write` | `ref` | `use` (`use` = referência registrada num caminho otimizado de codegen — incremento/atribuição composta — onde o modo exato não é refinado; para rename é indiferente).
- **`block: true`** — ocorrência dentro de codeblock (contexto: a linha pertence ao bloco, não ao corpo direto).
- **`param: true`** — declaração é parâmetro (posição ≤ contagem de parâmetros da função).
- **`usesMacro`** — gatilho da política H da [tabela S/H/X](armadilhas-shx.md) §1: rename de memvar/field/função nesta função exige confirmação. (Rename de `local`/`static`/`detached` segue S mesmo com macro — testado.)
- **`hasCDump`** — módulo com `BEGINDUMP`: verificação exige build completo, não só `-gh -l` (S/H/X §5).
- **`calls`** — **preenchido desde o patch v2**: `{ "sym", "line", "block" }` para cada referência a símbolo de função (chamada, `DO`, referência `@F()`), gravada em `hb_compGenPushFunCall`/`hb_compGenPushSymbol(bFunction)` (`hbmain.c`). Limitações v2: `Eval()` e sends de método são otimizados como mensagem (não geram símbolo de função — campo `"sends"` planejado para v3); contagem de argumentos (`"args"`) ainda não gravada (necessária na Fase 2/reorder-params).

### Regras de emissão

1. JSON gerado com `fprintf` simples no C do patch (sem dependência de lib JSON no compilador); nomes de símbolo são identificadores Harbour (sem escape necessário); caminhos de arquivo escapados (`\\`, `"`).
2. Um dump por módulo compilado; em compilação multi-arquivo, um `.occ.json` por fonte.
3. A gravação ocorre **durante o parse** (antes de `hbdead.c`): ocorrências em código morto **aparecem** — é o que garante soundness sobre o fallback `-gh -b` (arquitetura, Decisão 1a).
4. Erro de compilação ⇒ dump não é gravado (parcial nunca é emitido).

## Limitações conhecidas do patch v1 (verificadas em teste)

1. **`PRIVATE`/`PUBLIC` com inicialização** (`PRIVATE x := 5`): nem a declaração nem a escrita inicial aparecem (codegen via RTVAR, caminho não instrumentado). A *leitura* posterior aparece (como `memvar`/`memvar_implicit`). Memvars são território H de qualquer forma; corrigir no patch v2.
2. **Variáveis com alias** (`FIELD->x`, `M->x`, `alias->x`): caminho `GenPushAliasedVar` não instrumentado no v1.
3. **Duplicatas possíveis**: em alguns fallbacks de pré/pós-decremento o compilador resolve a variável duas vezes → dois registros para um token. O consumidor deve tratar a lista de ocorrências por linha como *conjunto* (a verdade posicional vem do lexer sobre a linha original), e recusar quando a mesma linha tiver o mesmo símbolo com **escopos distintos** (sombreamento por parâmetro de codeblock homônimo).
4. **Função pseudo `fileDecl: true`**: cada módulo traz uma entrada com o nome do módulo e `fileDecl: true` (declarações file-wide); consumidores filtram.
5. **`usesMacro`** é computado por varredura do pcode final: macro dentro de código morto eliminado não marca a flag (caso raro; conservadorismo adicional pode vir do consumidor via lexer).

## Evidência de funcionamento (2026-07-04, projeto de 2 arquivos)

Mini-projeto `main.prg` + `util.prg` + `util.ch`: dump validado por parser JSON; captura confirmada de: captura *detached* em codeblock (`nTotal` → `scope: "detached", block: true, access: "ref"`), parâmetro de bloco atribuído à função dona, `param: true`, `static: true`, `usesMacro: true` na função com `&`, memvar implícito, `@var` → `ref`, e `nRef++` → `use` (após o fix do ponto único). Regressão: `.hrb` sem `-x` byte-idêntico ao compilador pré-patch; projeto compila e executa com resultado correto.

## Contrato de consumo (hbrefactor)

Pipeline da Fase 0: `harbour -y` → ler JSON → filtrar `{função, sym, scope ∈ {local, detached}}` → para cada `line`, re-tokenizar a linha original (lexer do pp) e casar tokens homônimos por ordem → gerar WorkspaceEdit → aplicar → verificar `harbour -gh -l` byte-idêntico.

Recusas na Fase 0 (antes de editar): linha marcada como transformada pelo pp (diff `.prg`×`.ppo`); novo nome colide com declaração existente na função, com `#define` ativo ou com palavra reservada.
