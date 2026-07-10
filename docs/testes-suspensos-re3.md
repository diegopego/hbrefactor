# Testes suspensos no RE.3 — alvos de reconquista por FATO

> **Status (2026-07-10, F2.5 + B9 fatia 3)**: as Rotas A e B
> (`[FATIA-2]`) estão **RECONQUISTADAS** (casos 89 e 91-96) e a
> **Rota D fechou nos itens escrevíveis** (casos 98-100, B9 fatia 3 —
> só q1:13/14 seguem suspensos: param gerado por diretiva, sem token
> escrito). Rotas C (sem rota) e E (RE.6/degrade) seguem como estavam
> — nada delas foi prometido nem entregue.

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

## Rota A — anotação materializável em LOCAL/parâmetro `[FATIA-2]` — ✅ RECONQUISTADA (2026-07-10, casos 91-96)

A sugeridora (B7 dormente) prova a classe; o materializador escreve o
`AS CLASS`; `-kt` impõe (site coberto — RE.2); o send sai `guaranteed`.

**Reconquista provada em suíte (F2.4-complemento)**: cada site abaixo
decide `confirmed send (receiver declared AS CLASS <X>)` na cópia
materializada pelo `annotate --apply` e sobe a `guaranteed ... imposed
by -kt checks` com `-prgflag=-kt` no projeto — o ciclo completo
materializa → impõe → fato. As linhas dos sites nas cópias deslocam
pelos one-liners inseridos (fixture original intocado). SÓ locais:
anotação de PARÂMETRO segue fatia futura (resíduo 2 da F2.4).

| Caso | Site | Assert antigo (essencial) | Reconquista |
|---|---|---|---|
| 39/61 | fixcls w2.prg:7 `oMenu:Paint()` | `confirmed send (receiver class UWMENU via construction chain, class graph as written) in MAIN` | ✅ caso 91 (w2:8 na cópia) |
| 61 | fixmth c2.prg:28 `oC:Soma( 5 )` | `confirmed send (receiver class CAIXA via construction chain, ...) in MAIN` | ✅ caso 92 (c2:32) |
| 63 | fixrcv r2.prg:28 `s:Zap()` | `confirmed send (receiver class SEMCTOR via construction chain, ...) in USA` | ✅ caso 93 (r2:31) |
| 66 | fixdis d1.prg:87/88 `oNm:`/`oNs:Paint()` | `excluded send within the written class graph (receiver class NCMAIN/NCSECONDARY via construction chain, dispatches to ...)` — a PARTE de tipagem volta por esta rota; a EXCLUSÃO é Rota C | ✅ caso 94 (d1:95/96) — SÓ a tipagem; o espelho segue `possible` honesto |
| 84 | fixext e1.prg:71/73/74 `oC:`/`oV:Deposita` | `confirmed send (receiver class CONTA/CONTAVIP via construction chain, ...) in MAIN` (consulta da própria classe) | ✅ caso 95 (e1:73/75/76) |
| 85 | fixb7 b1.prg:53 `p:Gira()` | `confirmed send (receiver class PECA via construction chain, ...) in MAIN` (fábrica — ver também Rota B) | ✅ caso 96 (b1:54) |

## Rota B — retorno por `DECLARE ... AS CLASS` materializado `[FATIA-2]` — ✅ RECONQUISTADA (casos 89 e 96)

O canal de retorno JÁ existe na linguagem (`DECLARE F() AS CLASS X`) e
o `-kt` JÁ o impõe (embrulho `__HB_CHKTYPE` no RETURN — spec-b9). A
sugeridora prova o retorno (pushes `ret`, identidade `QSelf()`); o
materializador escreve o DECLARE; o send encadeado decide por fato.

| Caso | Site | Assert antigo (essencial) | Reconquista |
|---|---|---|---|
| 85 | fixb7 b1.prg:53 (fábrica `Cria()` sem DECLARE) | `confirmed ... via construction chain` — DECLARE materializado dá o mesmo site por fato | ✅ caso 96 (`DECLARE NOVAPECA() AS CLASS PECA` antes da definição — imposto) |
| 86 | fixb7b q1.prg:73 `oC:Pega():Soma( 5 )` | `confirmed send (receiver class MOEDA via construction chain, ...) in MAIN` (retorno não-Self pelos pushes ret) | ✅ caso 89 (2026-07-09, F2.4-núcleo) — `confirmed ... via declared types` |
| 86 | fixb7b q1.prg:75 `oM:Soma( 1 ):Soma( 2 )` (2 sends) | `confirmed ...` ×2 (identidade RETURN Self em cadeia) | ✅ caso 89 — completadores (g) `_HB_MEMBER SOMA()/PEGA()` |

## Rota C — exclusão de homônimo em SEND `[SEM-ROTA hoje; candidata: RE.6/canal novo]`

> Honestidade agora ASSERTADA em suíte (2026-07-10): nos round-trips
> materializados, o cruzado/espelho segue `possible send (receiver
> class X, relation to Y unknown)` — casos 92 (fixmth), 94 (fixdis,
> o furo dos homônimos) e 95 (fixext). A exclusão NÃO voltou e não
> volta por esta rota.

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

## Rota D — sites de codeblock `[RE.5 + A6]` — ✅ RECONQUISTADA nos itens escrevíveis (B9 fatia 3, 2026-07-10; casos 98-100)

O `-kt` fatia 1 não cobria blocos (matriz do RE.1) e a anotação
`AS CLASS` em param de bloco era inescrevível (A6 segfault; a
gramática descartava o nome). **A primeira perna FECHOU no RE.5** (A6
morto, imposição por Eval, fato `chk`/ast-8; caso 88) e **a segunda
na B9 fatia 3**
([spec-b9-fatia3-param-bloco.md](spec-b9-fatia3-param-bloco.md)): o
materializador escreve `AS CLASS` em param de bloco na âncora do fato
ast-9 (`nameLine`/`nameCol`) e o ciclo materializa → impõe → decide
fecha em suíte. Única exceção honesta: q1:13/14 (bloco GERADO pela
diretiva INLINE — o param não tem token escrito no fonte do app; a
posição vem AUSENTE no ast-9, prov de include). Rotas futuras
registradas: anotação na REGRA da DSL do usuário; para hbclass,
extensão do hbclass.ch no core (candidato sob portão).

| Caso | Site | Assert antigo (essencial) | Reconquista |
|---|---|---|---|
| 86 | fixb7b q1.prg:13/14 (INLINE/OPERATOR — money) | `confirmed send (receiver class MOEDA via construction chain, ..., codeblock) in MOEDA` (1º param do bloco inline é o receptor) | ⏸ SUSPENSO (param gerado por diretiva — sem site escrevível; caso 99 asserta o possible honesto) |
| 86 | fixb7b q1.prg:82 (bloco lê detached de binding único) | `confirmed ... codeblock` | ✅ caso 98 (LOCAL da dona anotada; leitura detached decide por fato; `guaranteed` com -kt) |
| 86 | fixb7b q1.prg:85/90 (param de bloco pela união dos Evals) | `confirmed ... codeblock` | ✅ caso 99 (anotação no token do param — inclusive o statement CONTINUADO; `guaranteed`) |
| 86 | fixb7b q2.prg:9 (DSL não-espelho — tigela) | `confirmed send (receiver class FORNALHA ..., codeblock) in FORNALHA` — a generalidade tem que voltar JUNTO | ✅ caso 100 (registro `_HB_CLASS` + anotação; `guaranteed`; morna/oExtra possible honesto) |

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
