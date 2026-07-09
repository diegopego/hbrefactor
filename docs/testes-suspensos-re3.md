# Testes suspensos no RE.3 — alvos de reconquista por FATO

**O que é isto (decisão do Diego, 2026-07-09, mesma sessão do portão
do RE.3)**: o RE.3 tirou a inferência do veredito do `usages` e os
casos 39/61/63/66-69/72/75/84/85/86 foram re-baselinados para o
contrato só-fato. As EXPECTATIVAS antigas não morreram — cada uma é o
registro de um *site que deveria voltar a ser decidível*. Este
catálogo as suspende COM NOME E RÓTULO VERBATIM e aponta, para cada
uma, a rota de FATO que a reconquista. Regras do catálogo:

1. **Nenhum assert volta verbatim.** Os rótulos `via construction
   chain / class graph as written / dispatches to` eram a assinatura
   da inferência — mortos pela REGRA DO FATO. O que volta é a DECISÃO
   no site, por fato, com rótulo novo (`guaranteed`, `confirmed ...
   declared`).
2. **Só rotas de fato** (decisão do Diego): materializador + `-kt`
   (fatia 2 da B9), RE.5 (cobertura completa do `-kt`), RE.6
   (contratos genéricos de diretiva), novos canais no core. Re-ligar a
   inferência ao veredito NÃO é rota.
3. **Este catálogo é semente do critério de aceite da fatia 2**
   (decisão do Diego): os itens marcados `[FATIA-2]` só saem daqui
   quando o ciclo materializa → impõe → o site decide `guaranteed`
   (ou `confirmed declared`) num caso de suíte NOVO. Itens `[RE.5]`,
   `[RE.6]` e `[SEM-ROTA]` esperam os respectivos portões.

Verbatim de referência: os asserts antigos completos vivem em
`git show 1aa95a8:tests/run.sh` (estado pré-RE.3); abaixo vai o rótulo
essencial de cada um.

## Rota A — anotação materializável em LOCAL/parâmetro `[FATIA-2]`

A sugeridora (B7 dormente) prova a classe; o materializador escreve o
`AS CLASS`; `-kt` impõe (site coberto — RE.2); o send sai `guaranteed`.

| Caso | Site | Assert antigo (essencial) |
|---|---|---|
| 39/61 | fixcls w2.prg:7 `oMenu:Paint()` | `confirmed send (receiver class UWMENU via construction chain, class graph as written) in MAIN` |
| 61 | fixmth c2.prg:28 `oC:Soma( 5 )` | `confirmed send (receiver class CAIXA via construction chain, ...) in MAIN` |
| 63 | fixrcv r2.prg:28 `s:Zap()` | `confirmed send (receiver class SEMCTOR via construction chain, ...) in USA` |
| 66 | fixdis d1.prg:87/88 `oNm:`/`oNs:Paint()` | `excluded send within the written class graph (receiver class NCMAIN/NCSECONDARY via construction chain, dispatches to ...)` — a PARTE de tipagem volta por esta rota; a EXCLUSÃO é Rota C |
| 84 | fixext e1.prg:71/73/74 `oC:`/`oV:Deposita` | `confirmed send (receiver class CONTA/CONTAVIP via construction chain, ...) in MAIN` (consulta da própria classe) |
| 85 | fixb7 b1.prg:53 `p:Gira()` | `confirmed send (receiver class PECA via construction chain, ...) in MAIN` (fábrica — ver também Rota B) |

## Rota B — retorno por `DECLARE ... AS CLASS` materializado `[FATIA-2]`

O canal de retorno JÁ existe na linguagem (`DECLARE F() AS CLASS X`) e
o `-kt` JÁ o impõe (embrulho `__HB_CHKTYPE` no RETURN — spec-b9). A
sugeridora prova o retorno (pushes `ret`, identidade `QSelf()`); o
materializador escreve o DECLARE; o send encadeado decide por fato.

| Caso | Site | Assert antigo (essencial) |
|---|---|---|
| 85 | fixb7 b1.prg:53 (fábrica `Cria()` sem DECLARE) | `confirmed ... via construction chain` — DECLARE materializado dá o mesmo site por fato |
| 86 | fixb7b q1.prg:73 `oC:Pega():Soma( 5 )` | `confirmed send (receiver class MOEDA via construction chain, ...) in MAIN` (retorno não-Self pelos pushes ret) |
| 86 | fixb7b q1.prg:75 `oM:Soma( 1 ):Soma( 2 )` (2 sends) | `confirmed ...` ×2 (identidade RETURN Self em cadeia) |

## Rota C — exclusão de homônimo em SEND `[SEM-ROTA hoje; candidata: RE.6/canal novo]`

A exclusão ("este send NUNCA é da classe consultada") exigia mundo
fechado sobre parents as-written — mesmo com `guaranteed` (is-a X), a
exclusão da OUTRA classe precisa de parentesco PROVADO e fechado, que
nenhum canal do core dá hoje. Candidatas honestas: RE.6 (se o core
expuser parentesco imposto/provado por classe) ou canal novo no core.
Os sites de DECLARAÇÃO homônimos seguem excluded (fato, nunca saíram).

| Caso | Site | Assert antigo (essencial) |
|---|---|---|
| 61 | fixmth c2.prg:30 `oO:Soma( 2 )` | `excluded send within the written class graph (receiver class OUTRA ..., dispatches to OUTRA:SOMA)` |
| 66 | fixdis d1.prg:69 `oS:Paint()` (consulta UWMain) | `excluded send (dispatches to UWSECONDARY:PAINT)` — **o furo dos homônimos, caso original do Diego** |
| 66 | fixdis d1.prg:78 `oP:Paint()` (declarado) | `excluded send within the project's class graph (dispatches to UWSECONDARY:PAINT)` |
| 66 | consulta espelho UWSecondary:Paint | `excluded send (dispatches to UWMAIN:PAINT)` |
| 67 | fixdis d2.prg:33 `oO:Paint()` (consulta do pai) | `excluded send (dispatches to UWOVER:PAINT)` (override — acerto próprio) |
| 72 | fixhom m1.prg:38/41 `oF:`/`oI:Brilho()` | `excluded send (dispatches to FAROL:BRILHO / IDOLO:BRILHO)` |
| 72 | fixhom `MYPAINT l` | `excluded send (dispatches to LOUSA:PINTAR)` |
| 72 | fixhom `LOUSA_NEW ::nT := n` | `excluded send within the project's class graph (dispatches to LOUSA:NT)` |
| 84 | fixext consultas cruzadas (e1.prg:64/71/73/74) | `excluded send within the written class graph (..., dispatches to CONTA:DEPOSITA / CONTAVIP:DEPOSITA)` |
| 85 | fixb7 b1.prg:53 (consulta Disco:Gira) | `excluded send within the written class graph (..., dispatches to PECA:GIRA)` |
| — | json66/json72 (pré-RE.3) | excluded fora das Location[] — volta junto com a exclusão |

## Rota D — sites de codeblock `[RE.5 + A6]`

O `-kt` fatia 1 não cobre blocos (matriz do RE.1) e a anotação
`AS CLASS` em param de bloco é inescrevível (A6 segfault; a gramática
descarta o nome). Rota: consertar A6 + estender emissão (RE.5) →
materializador anota → `guaranteed` em bloco.

| Caso | Site | Assert antigo (essencial) |
|---|---|---|
| 86 | fixb7b q1.prg:13/14 (INLINE/OPERATOR — money) | `confirmed send (receiver class MOEDA via construction chain, ..., codeblock) in MOEDA` (1º param do bloco inline é o receptor) |
| 86 | fixb7b q1.prg:82 (bloco lê detached de binding único) | `confirmed ... codeblock` |
| 86 | fixb7b q1.prg:85/90 (param de bloco pela união dos Evals) | `confirmed ... codeblock` |
| 86 | fixb7b q2.prg:9 (DSL não-espelho — tigela) | `confirmed send (receiver class FORNALHA ..., codeblock) in FORNALHA` — a generalidade tem que voltar JUNTO |

## Rota E — possible NOMEADO (contexto, não decisão) `[RE.6 ou aceitar o degrade]`

As nomeações da Q4 e os conjuntos finitos nunca decidiam — davam
contexto. Saíram por decisão do Diego (degrade pleno). Só voltam se o
contexto virar FATO (parentesco provado — RE.6); caso contrário o
degrade pleno É o estado final.

| Caso | Assert antigo (essencial) |
|---|---|
| 67/68/69/75 | `possible send (receiver class X may dispatch to Y:MET through written parents, unproven)` e variantes |
| 68 | `possible send (descendant HMBOTH of HMBETA may dispatch to ...)` |
| 85 | `possible send (receiver one of DISCO or PECA via construction chain, ...)` (união de call sites e de IIF) |

## Como usar (Claude de sessão futura)

- Abrir a fatia 2: os itens `[FATIA-2]` viram o esqueleto do critério
  de pronto — caso de suíte novo por item, assertando o rótulo de FATO
  no MESMO site do fixture (os fixtures continuam na suíte, intocados).
- Abrir RE.5: os itens `[RE.5 + A6]` entram no critério da fatia.
- Nenhum item autoriza reativar `B7Ctx` no `usages` — a máquina é
  insumo do materializador (spec-re, portão 2026-07-09).
