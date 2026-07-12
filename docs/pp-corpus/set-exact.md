# Família SET — `SET EXACT` (std.ch)

Índice: [README.md](README.md). Ensina: marker **restrict** no match + result
**strsmart** (smart-quote); multi-passe com `#define`. Guarda: `corpus_set` em
`tests/ppcorpus.sh`; fixture `tests/ppc-set/setx.prg`.

Diretiva real ([include/std.ch:121](../../../harbour-core/harbour/include/std.ch)):

```harbour
#command SET EXACT <x:ON,OFF,&> => Set( _SET_EXACT, <(x)> )
```

Uma linha, e dois mecanismos avançados do pp de uma vez.

## A fixture (`tests/ppc-set/setx.prg`) — compila limpo sob `-w3 -es2`

```harbour
PROCEDURE Main()
   LOCAL lFlag := .T.
   SET EXACT ON
   SET EXACT OFF
   SET EXACT (lFlag)
   RETURN
```

*(std.ch é AUTO-incluída pelo compilador — incluí-la explícito duplicaria os
`#define` e cairia em `W0002`/`-es2`.)*

## `.ppo` (o que o compilador REALMENTE compila)

```
   Set( 1, "ON" )
   Set( 1, "OFF" )
   Set( 1, lFlag )
```

## `.ppt` (o traço — DOIS passes por linha)

```
setx.prg(7) >SET EXACT ON<
#command >Set( _SET_EXACT, "ON" )<
setx.prg(7) >_SET_EXACT<
#define >1<
...
setx.prg(9) >SET EXACT (lFlag)<
#command >Set( _SET_EXACT, lFlag )<
setx.prg(9) >_SET_EXACT<
#define >1<
```

## Os mkinds do dump (ast-5) — a ponte com P4/P5

```
match:   SET(literal)  EXACT(literal)  x(marker, mkind=restrict)  + alt. ON|OFF|&
result:  Set ( _SET_EXACT ,  x(marker, mkind=strsmart)  )
```

## Explicação

**Técnica.** A regra casa `SET EXACT` seguido de UM marker restrito
(`<x:ON,OFF,&>`, mkind `restrict`): só `ON`, `OFF` ou macro `&` são aceitos. No
result, `<(x)>` é o SMART-STRINGIFY (mkind `strsmart`): palavra "nua" vira STRING
(`ON` → `"ON"`); entre parênteses/expressão, passa CRU (`(lFlag)` → `lFlag`). Num
SEGUNDO passe, `_SET_EXACT` é um `#define` que vira `1` — daí `Set( 1, "ON" )`.

**Para o programador Harbour.** Você escreve `SET EXACT ON` como se `ON` fosse
palavra-chave; o pp a captura como valor restrito (só ON/OFF/& — `SET EXACT
TALVEZ` não casa) e a converte em `"ON"`. Para passar variável, o idioma é o
parêntese: `SET EXACT (lFlag)` — aí NÃO vira string. O `_SET_EXACT` vira `1`
porque é um `#define` interno.

## Lente de refatoração (por FATO)

`resolve-at` em `SET EXACT ON`: `SET`/`EXACT` → *palavra de regra de pp (builtin)*;
`ON` → *nome de marker*. A ferramenta lê o papel de cada posição mesmo num comando
builtin do std.ch e não inventa ação (é do core, não do seu código). O valor não
é renomear std.ch — é **provar que o FATO do dump descreve fielmente até as
diretivas mais universais**: o mesmo maquinário que refatora a SUA DSL lê o
command-set do Clipper sem ajuste.

## Lacunas (o que os oráculos NÃO mostram)

> Classificação por FATO (não por raciocínio). Regra em [README.md](README.md).

- **[Consumo futuro — VERIFICADO] Restrição não-validada no consumo.** O dump JÁ
  traz as alternativas do restrict — vistas no dump desta própria fixture (seção
  "mkinds" acima: `role=restrict` com `ON`, `OFF`, `&`). Só falta a ferramenta
  VALIDAR um recheio contra elas. Fato presente → é o **P5** (ppcore.c:877-878),
  **não** mudança de core.
- **[Consumo futuro — parcialmente verificado] `strsmart` vs `strdump`/`strstd`.**
  O `strsmart` está PROVADO no dump desta fixture. Os irmãos (`strdump`, `strstd`)
  são do mesmo vocabulário de result-mkind do ast-5 mas o corpus **ainda não os
  viu rodando** — provar cada um numa fixture é justamente o **P4**. Até lá, o
  honesto é: `strsmart` confirmado, os outros pendentes de prova (não de core).
