# Arquitetura — hbrefactor sobre AST do compilador (2026-07-05)

Decisão registrada após o debate técnico de 2026-07-04/05 (histórico da era
anterior em [smoketest/](smoketest/README.md)). Princípio central, por ordem
do Diego: **todo conhecimento sintático e semântico vem de ganchos no
compilador oficial; a ferramenta não replica nada que o compilador saiba.**

## Divisão de trabalho

```
harbour (branch feature/compiler-ast-dump, a partir do master)
│  ganchos de 1 linha, gated por fAst (-x) — zero impacto sem o switch
│  toda a lógica em src/compiler/compast.c (novo)
│  posição de token: tabela lateral no pp (ppcore.c) + propagação em
│  hb_pp_tokenClone → coluna sobrevive a linhas reescritas por #command
▼
.ast.json por módulo (schema ast-1)
│  tokens (linha, coluna|null, tipo, proveniência s/i/n)
│  declarações c/ escopo resolvido + occurrences r/w/x + calls + sends
│  blocks (eventos abre/fecha/meio de IF/WHILE/FOR/CASE/SWITCH/SEQUENCE)
│  statements (árvore de expressão pré-reduce de cada statement/push)
▼
hbmk2  ──  resolvedor E gerador: hbrefactor roda
│          `hbmk2 <alvos> -prgflag=-x<dir>/ -s` — funciona com qualquer
│          projeto que o hbmk2 aceite (.hbp, .hbc c/ sources=, listas)
▼
hbrefactor (.prg) — decide e edita TEXTO; nunca adivinha sintaxe
│  comandos: renames, reorder, extract, usages, relatórios
▼
verificação independente — recompila antes/depois, compara byte a byte
   (.hrb -gh -l) ou estruturalmente (comparadores de HRB), rollback
   automático. Editor ≠ verificador é a prova de correção.
```

## Por que o motor fica FORA do compilador (provado, não opinião)

1. O parser vê o mundo pós-pp; refatoração edita o texto pré-pp — dentro ou
   fora, os fatos necessários são os mesmos (e os ganchos os exportam).
2. Não há AST retida no compilador (one-pass): as árvores de expressão são
   transientes — o gancho as serializa no funil (`hb_compExprGenStatement`/
   `GenPush`) antes do free.
3. Refatoração é operação de PROJETO — altitude do hbmk2, não do compilador.
4. Editor ≠ verificador só existe com o motor fora.

## Pontos de gancho (mapa)

| Fato | Gancho | Onde |
|---|---|---|
| token consumido + posição | `hb_compAstToken` | complex.c `hb_comp_yylex` |
| posição/proveniência | tabela lateral + `hb_pp_tokenClone` | ppcore.c |
| nascimento de nó (linha, tok) | `hb_compAstNodeBorn` | hbcomp.c `hb_compExprNew` |
| árvore do statement | `hb_compAstStatement` | hbexpra.c `GenStatement`/`GenPush` |
| função/procedure | `hb_compAstFuncBegin` | hbmain.c `hb_compFunctionAdd` |
| uso c/ escopo resolvido | `hb_compAstUse` + `hb_compAstTag` r/w/x | hbmain.c `hb_compVariableFind` + geradores |
| aliased (M->, alias->) | `hb_compAstUse` | hbmain.c GenPush/PopAliasedVar |
| calls / sends | `hb_compAstCallAdd/SendAdd` | hbmain.c PushFunCall/PushSymbol/GenMessage |
| PRIVATE/PUBLIC c/ init | `hb_compAstUse` | harbour.y `hb_compRTVariableGen` |
| blocos de controle | `hb_compAstBlock` | harbour.y ações dos contadores |
| dump/cleanup | `hb_compAstSave/Free` | hbmain.c |

## Regras que permanecem da era anterior (provadas)

- Fixtures = contrato de comportamento (mini-projetos ≥2 .prg + .ch + .hbp;
  recusas explícitas; ida-e-volta byte-exata; rollback).
- Fluxos definidos no Makefile; hbmk2 direto é experimentação.
- Strings/dados: detecção e relato (`--force` para prosseguir sem tocar),
  jamais edição automática.
- Corpus de validação: fixtures + `work/hbhttpd`. Projetos grandes só quando
  o Diego liberar.
