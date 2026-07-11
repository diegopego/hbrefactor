# Spec P-DOC — corpus exploratório/explicativo do PP (fase P)

Portão aberto pelo Diego (2026-07-11): a fase P ganha um deliverable de
CONHECIMENTO — uma bateria de estudos que casa **diretivas REAIS do Harbour**
(as `.ch` do core e de contribs) com seus artefatos de preprocessamento
(`.ppo` = saída expandida, `.ppt` = traço passo a passo) e explica, em formato
bilíngue (texto técnico + explicação para o programador Harbour), o que o pp faz
e o que a ferramenta consegue (ou não) refatorar. Escolhido como fatia ideal por
FUNDAR o resto da fase (P3-P8 dependem de saber quais fatos do pp têm consumidor
REAL — só o corpus real responde). Molde de investigação: o método-oráculo do
[adr-004](adr-004-grafo-transformacao-pp.md) #5, o MESMO que a fase P2 usou para
explicar o achado ao Diego.

## Por que (a tese — o "achado feliz" do Diego, 2026-07-11)

**Grande parte do que parece ser "a linguagem Harbour" é, na verdade, COMANDOS
criados por DIRETIVAS de preprocessador.** O conjunto xBase/Clipper que todo
programador escreve — `SET EXACT ON`, `@ 1,1 SAY x GET y`, `REPLACE`, `DEFAULT
… TO`, o dialeto OO inteiro (`CLASS`/`METHOD`/`VAR`/`ACCESS`) — não é gramática
do compilador: é implementado como regras `#command`/`#xcommand`/`#translate`
nas `.ch` (std.ch, hbclass.ch, contribs). Logo **entender o pp = entender o que a
maior parte do código Harbour REALMENTE é**, e é a mesma razão de o hbrefactor
agir na camada universal do FATO de derivação (refatora QUALQUER construto criado
por diretiva, sem ajuste por-caso — O NORTE).

### Terminologia (conferida no fonte do core — `doc/pp_prg.txt`, `src/pp/ppcore.c`)

O que o Diego vem chamando de "DSL" o ecossistema Harbour nomeia assim:
- **diretiva de preprocessador** = a LINHA de definição (`#command`/`#xcommand`/
  `#translate`/`#xtranslate`/`#define`); o core chama de *rule* internamente
  (`__pp_AddRule` = "Preprocess and execute new preprocessor directive").
- **comando** = a sintaxe que o programador ESCREVE e que a diretiva cria
  (`SET EXACT ON`); vem de `#command`.
- **marker** = os `<x>` do padrão; **match** = o lado esquerdo (o que casa);
  **result** = o lado direito (o que emite).
"DSL" continua válido em sentido amplo (o command-set É uma DSL implementada em
pp) e é o termo interno das specs; nos textos para o programador Harbour usar
**comando / diretiva de pp** (o vocabulário dele).

## Formato de cada família (o molde executável)

Cada família de diretiva vira uma ENTRADA no corpus ([pp-corpus/README.md](pp-corpus/README.md))
com, nesta ordem:
1. **A diretiva** (colada do `.ch` real, com arquivo:linha de origem).
2. **A fixture `.prg`** que a exercita (compila LIMPO sob `-w3 -es2` — régua do
   caso 0/64; `.ch` do core é AUTO-incluída, não incluir explícito).
3. **O `.ppo`** (saída expandida) e **o `.ppt`** (traço passo a passo) REAIS,
   colados como FATO.
4. **Os mkinds do dump ast-5** (`match[].mkind`/`result[].mkind`) que a diretiva
   usa — a ponte com P4/P5.
5. **Explicação bilíngue:** o que o pp faz, passo a passo (técnico) + o que isso
   significa para quem escreve o comando (programador Harbour).
6. **Lente de refatoração:** o que o hbrefactor consegue fazer nessa diretiva
   (rename de qual posição? usages? limite honesto?), ligando ao FATO do dump.
7. **Lacunas** (SER CRÍTICO): o que os oráculos NÃO mostram, cada item
   classificado por FATO em **[Consumo futuro]** (o dado É derivável, só falta a
   ferramenta consumi-lo → P3-P8, sem core) ou **[LACUNA real]** (o dado NÃO está
   nos oráculos → PAUSA a exploração + experimento estendendo o core). Regra e
   distinção detalhadas no [pp-corpus/README.md](pp-corpus/README.md).

### Os QUATRO oráculos (o método, decisão do Diego 2026-07-11)

Cada família casa a diretiva com os quatro instrumentos, que juntos são o retrato
completo (cada um mostra uma face):
1. **`.ppo`** (saída expandida, `harbour -p`) — o que o compilador REALMENTE compila.
2. **`.ppt`** (traço passo a passo, `harbour -p+`) — a transformação passo a passo,
   multi-passe visível, anotada por linha-fonte.
3. **ast dump** (`harbour -x`) — o FATO estruturado (os `mkind` do ast-5, o `from`),
   a ponte com o consumo da ferramenta e com P4/P5.
4. **código COMPILÁVEL** (a fixture `.prg`) — comprovado sob `-w3 -es2` (régua do
   caso 0). O corpus SEMPRE se baseia em código que compila e roda.

### Suite SEPARADA — `make ppcorpus` (não é o contrato)

O corpus é suite-like (executável, provado) mas vive SEPARADO do contrato
(`make test`) DE PROPÓSITO (decisão do Diego): (a) é exploratório e cresce livre;
(b) durante a exploração o **core será modificado** para gerar mais informação
(`.ppt`/`.ppo`/dump mais ricos — permissão do Diego, #7 do adr-004), e o contrato
tem de ficar byte-idêntico. O runner é `tests/ppcorpus.sh` (sequencial), alvo
`make ppcorpus`. Anti-drift: os `.ppo`/`.ppt`/dump colados no doc são build
artifacts — NÃO se versionam; a guarda REGENERA os quatro e **assere as
transformações-chave** que o doc afirma. Se o core mudar a expansão, `make
ppcorpus` quebra e o doc é corrigido — o conhecimento fica ancorado no FATO
corrente, nunca numa cópia congelada. (O contrato `make test` permanece 813/0
byte-idêntico, intocado por esta frente.)

### Extensão do core PERMITIDA (autorização do Diego, 2026-07-11)

Nesta fase exploratória é permitido — e desejável — **estender o fonte do
Harbour** para extrair mais informação quando o `.ppo`/`.ppt` não bastar (é o #7
do adr-004: "estender `.ppo`/`.ppt` ao máximo"). Ex.: anotar no `.ppt` qual
marker/mkind gerou cada peça de saída. Todo achado se anota NO DOCUMENTO DE
PESQUISA pertinente (este spec / o corpus), **nunca na memória privada** (ordem
do Diego). Commit no core segue sob autorização por-commit.

## Corpus planejado (ordem proposta — crescente em complexidade)

1. **`std.ch` — família SET** (o comando mais universal; restrict + smart-quote).
   *ENTREGUE como prova-de-formato* (`SET EXACT`).
2. `std.ch` — família `@ … SAY … GET … PICTURE … VALID` (multi-marker, grupos
   opcionais, o coração da UI Clipper).
3. `std.ch` — `TEXT … ENDTEXT`, `STORE … TO` (list marker, `#pragma __text`).
4. `hbclass.ch` — `CLASS`/`METHOD`/`VAR`/`DATA`/`ACCESS`/`ASSIGN` (diretiva que
   gera função + registra; multi-passe; liga ao ast-13/genealogia).
5. Um contrib não-mantido-como-régua mas rico (ex.: hbct/Clipper Tools) — medição,
   não capacidade (nuance xhb do CLAUDE.md).

Cada família adicionada só com fixture que compila + guarda executável + a
explicação bilíngue. O corpus cresce fatia a fatia; este spec lista o alcançado.

## Critério de pronto ("família entregue")

- [ ] diretiva REAL do core citada com arquivo:linha;
- [ ] fixture `.prg` compila limpo sob `-w3 -es2` (régua do caso 0);
- [ ] `.ppo` + `.ppt` REAIS colados no corpus, e os mkinds do ast-5;
- [ ] explicação bilíngue (técnico + programador Harbour);
- [ ] lente de refatoração ligada ao FATO do dump;
- [ ] guarda executável na suíte (compila + transformações-chave) verde;
- [ ] toda descoberta anotada NO CORPUS/SPEC (nunca na memória).

## Status

- **Reorganização (2026-07-11, ordem do Diego):** corpus agora é DIRETÓRIO
  `docs/pp-corpus/` — índice enxuto (README) + UM ARQUIVO POR FAMÍLIA, para o
  Claude do futuro carregar só a família que precisa (o monolito estouraria o
  contexto). Instrução permanente no README.
- **Famílias 1-4 ENTREGUES (2026-07-11):** SET EXACT (restrict+smart-quote), @…SAY
  (grupos opcionais + seleção de forma), STORE (grupo opcional que repete), hbclass
  (o dialeto OO é pp: paste + genealogia ast-13 + `Self AS CLASS`). `make ppcorpus`
  **16/16**; contrato `make test` segue **813/0** byte-idêntico.
- **LACUNA encontrada (família hbclass) → exploração PAUSADA** (regra do Diego):
  o `rename` de um **DATA/VAR member** de classe recusa honesto (não há verbo). A
  info NÃO falta (usages resolve tudo escopado à classe) → é lacuna de CAPACIDADE,
  decisão de produto do Diego, não experimento de core. Registrada em class.md e
  no roadmap; a próxima família (contrib) aguarda a direção do Diego sobre a lacuna.
