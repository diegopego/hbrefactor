# Família hbclass — `CLASS`/`VAR`/`METHOD` (hbclass.ch)

Índice: [README.md](README.md). Ensina: o dialeto OO INTEIRO é diretiva de pp —
num só lugar aparecem o paste do nome da função gerada, a diretiva que GERA outra
diretiva (genealogia ast-13), o registro via `oClass:AddMethod`/`AddMultiData` e o
`Self AS CLASS <classe> := QSelf()`. Guarda: `corpus_class`; fixture
`tests/ppc-class/clsx.prg`. **hbclass.ch NÃO é auto-incluída** (precisa
`#include "hbclass.ch"` + `-I <core>/include`).

Diretivas reais ([include/hbclass.ch:235+](../../../harbour-core/harbour/include/hbclass.ch)):
`CLASS <!Name!>`, `VAR <!Data!> [INIT <v>]`, `METHOD <Name> …`, `ENDCLASS`, e a
implementação `METHOD <Name> CLASS <Class>`.

## A fixture (`tests/ppc-class/clsx.prg`) — compila limpo sob `-w3 -es2`

```harbour
#include "hbclass.ch"

CREATE CLASS Conta
   VAR nSaldo INIT 0
   METHOD Deposita( nValor )
ENDCLASS

METHOD Deposita( nValor ) CLASS Conta
   ::nSaldo += nValor
   RETURN Self
```

## `.ppt` — o traço (curado; o completo tem ~40 passes) revela QUATRO fatos

**(1) `VAR` registra o dado** (canal `_HB_MEMBER`, B4f):
```
clsx.prg(4) >VAR nSaldo INIT 0<
#xcommand >_HB_MEMBER { nSaldo } ; oClass:AddMultiData(, 0, ... {"nSaldo"}, ... )<
```

**(2) `METHOD` (declaração) registra o método E COLA o nome da função gerada:**
```
clsx.prg(5) >METHOD Deposita( nValor ) ...<
#xcommand >... oClass:AddMethod( __HB_CLS_ASSTRING(...), @__HB_CLS_ASID( __HB_CLS_MTHNAME _CLASS_NAME_ Deposita... )(), ... )<
clsx.prg(5) >Conta _<
(concatenate) >Conta_<
clsx.prg(5) >Conta_ Deposita<
(concatenate) >Conta_Deposita<          <- o PASTE do nome (P1/P2)
```

**(3) `METHOD` (declaração) GERA uma diretiva nova** — genealogia ast-13:
```
clsx.prg(5) >__HB_CLS_DECLARE_METHOD Deposita Conta<
#xcommand >#xcommand METHOD <type: FUNCTION, PROCEDURE> Deposita CLASS Conta ... => DECLARED METHOD <type> Deposita CLASS Conta ; ...<
```

**(4) `METHOD … CLASS Conta` (impl) casa a regra gerada e nasce com `Self` tipado:**
```
clsx.prg(8) >METHOD Deposita( nValor ) CLASS Conta<
...
#xcommand >static FUNCTION Conta_Deposita( nValor ) ; local Self AS CLASS Conta := QSelf() AS CLASS Conta<
```

## O que o dump (ast/usages) confirma por FATO

- **Genealogia ast-13 dispara no hbclass real:** as regras `METHOD Deposita CLASS
  Conta` geradas carregam `from` apontando a app da declaração (verificado: 2
  regras geradas, `from` presente).
- **`resolve-at`** na declaração e na impl → `Conta:Deposita` (dona única).
- **`usages Conta:Deposita`** → declaração (linha 5) + definição (linha 8).
- **`usages Conta:nSaldo`** → `VAR nSaldo` (declaração, class CONTA) + os dois
  `::nSaldo` como `confirmed send (receiver declared AS CLASS CONTA)` — o
  `Self AS CLASS Conta` (RD/M-B) escopa o DATA member à classe certa.

## Explicação

**Para o programador Harbour.** Aquela classe que você escreve com `CLASS`/`VAR`/
`METHOD` **não tem uma linha de gramática no compilador** — é tudo `#xcommand` em
hbclass.ch. `CREATE CLASS Conta` abre uma função-fábrica; cada `VAR` vira
`oClass:AddMultiData(...)`; cada `METHOD` vira `oClass:AddMethod("Deposita",
@Conta_Deposita(), ...)` E cria, em tempo de pp, uma regra que reconhece a sua
implementação `METHOD Deposita CLASS Conta` e a transforma na função real
`Conta_Deposita()`, com `Self` já declarado do tipo da classe. É a diretiva mais
sofisticada do Harbour — e o hbrefactor a lê pelos mesmos fatos que lê a sua DSL.

## Lente de refatoração

Esta família é a prova de que TUDO que a ferramenta construiu se amarra num
construto real: o paste do nome (B4d/P1), a genealogia de regra gerada (ast-13),
o canal `_HB_MEMBER`/`_HB_CLASS` (B4f), o `Self AS CLASS` (RD/M-B). Renomear o
MÉTODO funciona (dona única → `Conta:Deposita`, edita declaração + impl + a string
de registro por derivação).

## Lacunas (o que os oráculos NÃO mostram)

- **[LACUNA de CAPACIDADE — decisão de produto do Diego] Renomear um DATA/VAR
  member de classe.** A informação está TODA presente (o `usages Conta:nSaldo`
  resolve a declaração `VAR nSaldo` + os `::nSaldo` como confirmed sends, escopo
  Conta), mas o `rename` sobre `::nSaldo` **recusa honesto**: *"é VAR/DATA, não
  método; fora do escopo do rename-method"*. Não há verbo para DATA member. Como
  a INFO não falta (nada a estender no core), NÃO é experimento de core: é uma
  **capacidade nova** (um "rename de DATA member") que precisa do portão do Diego
  (regra "genérico > específico: comando dedicado só com razão forte"). Registrado
  no [roadmap](../roadmap.md) como candidato; a exploração do corpus PAUSA aqui
  até a direção do Diego (regra: lacuna pausa a exploração).
- **[Consumo futuro] O `resolve-at` de `::nSaldo` devolve `nSaldo` cru** (send
  dinâmico), sem escopar a Conta, embora o `usages Conta:nSaldo` saiba escopar. É
  o mesmo fato (Self AS CLASS Conta) já no dump — falta o resolve-at consumi-lo.
  Não é lacuna de core; alimentaria o rename-DATA acima quando/se existir.
- **[Fora de escopo] Nome de CLASSE** (`Conta`) não é renomeável (limite conhecido
  do roadmap, não deste corpus).
