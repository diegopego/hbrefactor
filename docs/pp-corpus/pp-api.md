<!-- guarda: corpus_ppapi -->
# Família PP VIVO / API — `__pp_Init` e os contextos

> **O conhecimento mora em [`tests/ppc-ppapi/pa.prg`](../../tests/ppc-ppapi/pa.prg)** — 10
> asserts. Guarda: `corpus_ppapi`. Origem: `harbour/tests/ppapi.prg` + `src/pp/pplib.c`.
> *(Dúvida levantada pelo Diego, 2026-07-14: "podem existir diversos contextos… dá pra fazer
> init e close mais de uma vez… não sei o que acontece se aninhar, e nem se afeta o contexto
> do arquivo".)*

## A API (`pplib.c`)

```
__pp_Init( [cPath], [cStdCh], [lArchDefs] )   -> um estado NOVO e INDEPENDENTE
     cStdCh AUSENTE -> carrega as regras PADRÃO da linguagem
     cStdCh = ""    -> nenhuma regra: um pp VIRGEM (só as suas)
     cStdCh = arq   -> lê as regras daquele arquivo
__pp_AddRule( pp, "#xcommand ..." )   -> registra a regra NAQUELE estado
__pp_Process( pp, cTexto )            -> transforma o texto e o DEVOLVE (não executa)
__pp_Reset( pp )                      -> derruba as regras que VOCÊ adicionou
__pp_Path( pp, cPath )                -> caminho de include
```

## As respostas, provadas por assert

1. **Não existe "close".** O estado é um ponteiro sob **GC** (`pplib.c:104` — `hb_pp_free` no
   destrutor): morre quando a última referência some. O modelo não é *init/close*: é **quantos
   estados eu quiser, vivos ao mesmo tempo**.
2. **Aninhar é só ter dois.** Criar um estado com outro vivo não interfere em nada — eles são
   objetos independentes. A **mesma cabeça** pode ter **regras diferentes** em estados
   diferentes, e cada `__pp_Process` responde pelo seu.
3. **`__pp_Reset` derruba as SUAS regras e mantém as da linguagem**
   (`hb_pp_ruleListNonStdFree`): depois dele, a sua `XX` sumiu e o `?` continua virando `QOut`.
4. **O pp de runtime NÃO vê o pp da compilação.** Um `#xcommand` declarado no `.prg` existe em
   tempo de compilação (o código roda), mas o estado criado por `__pp_Init` **não o conhece** —
   o texto volta intacto. **São dois mundos**, e o do compilador morreu com a compilação.

## Consequência para o corpus (e é por isso que esta família existe)

**Toda fixture que usa o pp vivo para provar uma expansão TEM de registrar a regra de novo com
`__pp_AddRule`.** Sem isso ela não está testando a diretiva — está testando texto. E quando o
alvo é observar **só** as suas regras, use o estado virgem (`__pp_Init( , "" )`), sem a
linguagem no meio.
