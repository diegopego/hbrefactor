# Família DEFINE DINÂMICO (`dynval`) — o valor que depende de ONDE o código está

Índice: [README.md](README.md). Ensina: existem duas constantes cujo valor **não
está escrito em lugar nenhum** — ele é decidido pela **posição** do código.
Consequência para o refatorador: **mover código muda o programa**, e essa é a
única família em que a mudança é *correta* e ainda assim precisa ser dita.
Guarda: `corpus_dyn`; fixture `tests/ppc-dyn/`.

## As regras (BUILTIN do pp — o usuário não as escreve)

```c
// ppcore.c:7253-7254 — as ÚNICAS duas regras de mkind `dynval`
hb_pp_addDefine( pState, "__FILE__", &s_pp_dynamicResult );
hb_pp_addDefine( pState, "__LINE__", &s_pp_dynamicResult );
```

O `dynval` não é um marker que se escreve: é um tipo de token que o pp **cria por
dentro** (o resultado da regra é um ponteiro sentinela, não texto), e que ele
resolve na hora da expansão (`ppcore.c:5501`) — `__FILE__` vira o nome do arquivo
corrente, `__LINE__` vira `pFile->iCurrentLine`.

**A recusa documentada do P4/P5 SOBREVIVEU à medição** — e agora é medida, não
raciocinada: em **4.582 regras reais** do ecossistema, **zero** de mkind `dynval`;
as únicas duas que existem são estas, e vêm do próprio pp. É o **último** mkind com
recusa de pé. *(A do irmão `strdump` caiu: [strdump.md](strdump.md).)*

> **Correção de fato** (2026-07-13): o `ast-schema` listava `__DATE__` entre os
> dinâmicos. **Não é** — o `__DATE__` e companhia são `#define` de valor **fixo**,
> calculados uma vez na inicialização. Dinâmicos são **dois**, e só dois.

## O `.ppo` — o valor SEGUE a posição

```
LOCAL nQuando := __LINE__     ->   LOCAL nQuando := 13
? "log:", __LINE__            ->   QOut( "log:", 24 )
LOCAL cOnde := __FILE__       ->   LOCAL cOnde := "dyn.prg"
```

## Lente de refatoração — a família em que EDITAR CERTO muda o programa

Aqui está o achado, e ele é sutil. Rodando o `extract-function` sobre um módulo com
`__LINE__` (verificado):

```
antes:   ? "log:", __LINE__     (linha 12)   ->   QOut( "log:", 12 )
depois:  ? "log:", __LINE__     (linha 11)   ->   QOut( "log:", 11 )
```

O programa passa a registrar **outro número**. E — repare — **isto não é um bug**:
o statement de fato mudou de linha, e o `__LINE__` está fazendo exatamente o que
promete. Um humano editando o arquivo causaria o mesmo. A ferramenta também foi
honesta: para o `extract-function` ela **não alega** preservação de comportamento
(*"symbols preserved; run your test suite to confirm behaviour"*) — o verbo cria uma
função nova, então identidade de pcode nunca esteve na mesa.

O que a família estabelece como **fato duro**:

- **Um módulo que usa `__LINE__` é SENSÍVEL A POSIÇÃO.** Nenhum verbo que desloque
  linhas pode alegar identidade de pcode nele — nem em princípio. (Os verbos que
  **não** deslocam linhas, como o `rename`, seguem intactos: o número não muda.)
- **O `__FILE__` é sensível a ARQUIVO**: mover uma função de módulo muda a string.
- E o fato existe para avisar: `ppApplications` traz **cada expansão com a sua
  linha** — dá para saber, antes de editar, que o módulo tem esse acoplamento.

## Lacunas (o que os oráculos NÃO mostram)

> Classificação por FATO (VERIFICADO rodando). Regra em [README.md](README.md).

- **[Consumo futuro — VERIFICADO] A ferramenta não AVISA que o módulo é sensível a
  posição.** O fato está no dump (as aplicações de `__LINE__`, com linha —
  verificado na fixture: duas aplicações, linhas registradas), e nenhum verbo o usa.
  Um verbo que desloca linhas deveria dizer *"este módulo expande `__LINE__` em N
  sítios; o valor deles muda com esta edição"* — o mesmo dever de **relato** da
  família [text-stream.md](text-stream.md), pela mesma razão do §1 do CLAUDE.md.
  Entra na fase **P16** (o relato do não-verificável), que já existia: é o mesmo
  verbo, com uma segunda fonte de aviso. **Não implementado** (spec antes de código).
- **[Não-lacuna, dito por honestidade] O valor novo é o CERTO.** Não há nada a
  consertar na expansão, e seria erro "congelar" o `__LINE__` para preservar pcode —
  isso mentiria sobre onde o código está. O produto aqui é o **aviso**, não a
  correção.
