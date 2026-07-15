<!-- guarda: corpus_class -->
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

## A fixture — a prova é EXECUTÁVEL (METODO-V2)

Duas camadas, em dois arquivos. Aqui a camada A (o TEXTO via pp vivo) **não cabe**:
o dialeto são dezenas de regras entrelaçadas que só fazem sentido com a classe
inteira em contexto — o "o que VIRA" é provado pelo `.ppt`, não por `__pp_Process`
de uma diretiva isolada.

- **`tests/ppc-class/clsx.prg`** (`hbclass.ch` + `hbtest`) — camada B: o dialeto
  **compila e roda**. `Conta()` instancia; `oConta:nSaldo` nasce `0` (o `VAR … INIT
  0` rodou); `oConta:Deposita( 100 )` dispara o método gerado e o `::nSaldo +=`
  **acumula** (100, depois 150); `Deposita` devolve **Self** (`== oConta`). Cada
  valor prova que `VAR`/`METHOD`/`::send` viraram função de verdade.
- **`tests/ppc-class/clsxdump.prg`** (raw-dumpável, `-I <core>/include`) — os fatos
  do `.ppt`/dump: o **paste** do nome (`Conta` + `_` + `Deposita` → `Conta_Deposita`),
  a diretiva que **gera** a regra da impl (genealogia ast-13, `from`), e a impl
  nascendo com o **Self tipado** (`local Self AS CLASS Conta := QSelf()`).

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

> Classificação por FATO (não por raciocínio — o item de consumo futuro foi
> VERIFICADO rodando o dump; ver a evidência colada). Regra em [README.md](README.md).

- **[RESOLVIDA — capacidade rename-DATA entregue, 2026-07-11] Renomear um
  DATA/VAR member de classe.** A lacuna que o corpus achou (o `rename` sobre um
  DATA member recusava "é VAR/DATA, não método") virou EXPERIMENTO imediato (regra
  do Diego) e depois CAPACIDADE, com portão aberto. A investigação provou que a
  info bastava (o `usages Conta:nSaldo` já resolvia declaração + getter/setter
  escopados à classe; o setter `_nSaldo` é o mesmo token textual `:nSaldo`; a
  string de registro re-deriva). Foi a **completude natural do rename-method para
  DATA** — sem comando novo: hoje o `rename` sobre `VAR nSaldo`/`::nSaldo` edita a
  declaração + getter + setter, mapeia `NSALDO→novo` E `_NSALDO→_novo`, e recusa
  homônimo entre classes (unicidade). Spec: [../spec-rename-data.md](../spec-rename-data.md);
  provas: caso 48 re-baselinado + caso 110 (fixdata). Fatia 2 (`ACCESS`/`ASSIGN`,
  DATA herdada) fica no backlog.
- **[Consumo futuro — VERIFICADO] O `resolve-at` de `::nSaldo` devolve `nSaldo`
  cru** (send dinâmico), sem escopar a Conta — embora o `usages Conta:nSaldo` já
  saiba escopar. A assimetria foi PROVADA rodando os dois oráculos na fixture:
  ```
  resolve-at ::nSaldo (uso, linha 14)  -> query: nSaldo         (send; dispatch dinâmico)
  resolve-at VAR nSaldo (decl, linha 9)-> query: Conta:nSaldo   (dona única, declared)

  usages Conta:nSaldo:
     clsx.prg:14  confirmed send (receiver declared AS CLASS CONTA) in CONTA_DEPOSITA
     clsx.prg:14  confirmed send (receiver declared AS CLASS CONTA) in CONTA_DEPOSITA
     clsx.prg:9   var declaration (class CONTA)
  ```
  O `usages` casa os dois `::nSaldo` como send confirmado NA classe certa, mas o
  `resolve-at` sobre o mesmo `::nSaldo` ainda entrega `nSaldo` sem classe. A
  capacidade rename-DATA hoje opera a partir da DECLARAÇÃO `VAR nSaldo` (que
  escopa); escopar o resolve-at do site de USO (`::nSaldo`) é a melhoria seguinte
  — **o fato já está no dump** (o `usages` prova), **sem core**, só falta o
  resolve-at consumi-lo.
- **[Fora de escopo] Nome de CLASSE** (`Conta`) não é renomeável (limite conhecido
  do roadmap, não deste corpus).
