# Revisão de generalidade — hbclass NÃO é o alvo, é UM CASO

**ORDEM DO DIEGO (2026-07-07)**: revisar os pontos onde a solução tentou
resolver "refatoração da hbclass" em vez da situação real — refatoração de
DSLs criadas com diretivas do pp, por qualquer programador, a qualquer
momento. **Aviso explícito dele, registrado**: commits já foram feitos com
essa intenção errada — existe código, especificações (incluindo o
roadmap), e testes que precisam de revisão para guiar ao objetivo correto.

Este documento é o instrumento da revisão: achados VERIFICADOS (V*, com
evidência arquivo:linha), perguntas a PROVAR (Q*, cada uma com o probe que
decide), e a régua de pronto. Nenhum item se fecha por argumento — só por
prova executável na suíte ou conserto verificado.

## Diagnóstico honesto (para calibrar a revisão, não para amenizá-la)

O que o registro mostra, dos dois lados:

- **O mecanismo de base é genérico e está provado**: as âncoras por forma
  da B4c foram MORTAS na B4d (rastro `from`); a régua do caso 64 é
  executável e segura (grep de 2026-07-07: `hbclass`/`CREATE CLASS`/
  `__cls` aparecem SÓ em comentários de `src/hbrefactor.prg`, nunca em
  código); casos 72-74 provam usages/rename-pp-marker/rename fim-a-fim em
  DSLs inventadas. O trabalho de dispatch/tipos consome semântica da
  LINGUAGEM (`classes.c` é o VM — qualquer classe obedece o flattening;
  `DECLARE`/`AS CLASS` é gramática), não convenção do hbclass.
- **PORÉM a intenção derrapou em quatro frentes reais**: (1) heurística
  hbclass na EXTENSÃO, não corrigida e cimentada no contrato da suíte;
  (2) comandos da era B4e provados SÓ em fixtures hbclass — generalidade
  suposta, não provada; (3) pelo menos uma suposição em forma-de-hbclass
  no código (pais de classe); (4) vocabulário/documentos que direcionam
  sessões futuras a pensar "classe" (o roadmap narrava 1400 linhas
  encharcadas disso — enxugado nesta data, histórico em
  [roadmap-fases-entregues.md](roadmap-fases-entregues.md)).

A cura é **prova adversarial + conserto pontual + limpeza de direção** —
não reescrita. Onde a prova passar, o item fecha com o caso na suíte;
onde falhar, o conserto é fato-based ou recusa honesta (princípio da
generalidade do CLAUDE.md).

## Achados VERIFICADOS (2026-07-07, evidência conferida — não re-sondar)

| # | Achado | Evidência |
|---|--------|-----------|
| V1 | **`methodQuery` da extensão é hbclass hard-coded**: regex de `METHOD ... CLASS`, `method\|access\|assign`, `CREATE CLASS`, `ENDCLASS`. O lifting de cursor só existe para hbclass; em DSL de usuário a consulta sai crua (o CLI valida — sem corrupção, mas o recurso não chega). O caso 71 colocou essa heurística no CONTRATO da suíte. | vscode/extension.js:134-149; tests caso 71 |
| V2 | **Cobertura da suíte enviesada**: `usages` (fixhom/fixppm/fixdsl/fixmth/fixdis/fixmv), `rename-pp-marker` (fixppm) e `rename-param` (fixsig + caso 54 em fixppm) têm prova em DSL inventada; **`rename-method` (só fixmth), `reorder-params` (só fixsig), `call-graph` (só fixsig), `extract-function` (fixext hbclass + recusa fixdsl)** não têm. *(Buraco FECHADO em 2026-07-07: casos 76-79 sobre a fixture fixofi — DSL não-espelho; ver Q1-Q3/Q7.)* | grep comando×fixture em tests/run.sh, 2026-07-07 |
| V3 | **`ClassParentsSeq` codifica leitura em forma-de-hbclass**: "outros identificadores POSICIONADOS na linha da declaração da função-classe que chegam ao stream = pais, na ordem escrita". Verdade para hbclass; uma DSL `RIG Totem USA Ferramenta` (Ferramenta = função referenciada na expansão, não pai) passa TODOS os filtros → pai falso no ClassGraph → dispatch envenenado. O fixhom não pega: rig.ch é espelho estrutural do hbclass. | src/hbrefactor.prg:2788-2828 (filtros em 2808-2822) |
| V4 | **Síntese do extract-para-método é por-DSL** (texto `METHOD <n>(...) CLASS <c>` hbclass hard-coded) — a ÚNICA exceção de biblioteca, decidida e documentada (Diego, 2026-07-06; racional: o pp não roda ao contrário). Em projeto de DSL própria a síntese erra → recompile-verify recusa (rede segura). Fica; re-visitar só se morder em uso real. | roadmap arquivado (decisão registrada); extract em hbrefactor.prg |
| V5 | **Rótulos dizem "class" para dono de qualquer DSL** (`cog declaration (class TOTEM)`) — o TIPO do membro lifta para o vocabulário da regra raiz (`SeedRootRule`), o do DONO não. | caso 72; relator do usages |
| V6 | **Nomes internos da ferramenta enquadram o modelo como classe** (`ClassGraph`, `RenameMethod`, `MethodImplOf`, `ClassParentsOf`, ...) — risco de DIREÇÃO (convida ajuste por-caso futuro), não de mecanismo (os consumos são do rastro/canal). Renomear em massa é churn sem prova — tratar via comentários-teto nos pontos-chave e por esta revisão. | inventário de funções, grep 2026-07-07 |
| V7 | **Especificações e roadmap narram em vocabulário de classe** (B4c/B4e/B4f/B4f-2 falam método/classe mesmo onde o mecanismo é genérico) — direcionam sessões futuras ao enquadramento errado. Roadmap enxugado nesta data; specs antigas ficam como registro histórico COM este aviso. | docs/spec-b4*.md; roadmap-fases-entregues.md |

## O que PROVAR ou CONSERTAR (checklist executável — a revisão é isto)

Régua comum: cada Q fecha com caso na suíte usando DSL INVENTADA que NÃO
espelha o hbclass (a lição do V3: espelho estrutural não é adversarial), e
com a régua do caso 64 (nenhuma palavra da DSL na ferramenta/core).
Resultado possível de cada Q: **prova** (funciona genérico), **conserto
fato-based**, ou **recusa/relato honesto documentado no ast-schema** —
nunca ajuste por-caso.

| # | Pergunta | Probe que decide | Se falhar |
|---|----------|------------------|-----------|
| Q1 | ✅ **FECHADA (2026-07-07, caso 76)** — prova + conserto. Fixture NOVA fixofi (a lição do V3 aplicada: NÃO-espelho — colagem MENSAGEM-primeiro `Talha_na_Banca` com separador multi-byte, assinatura numa ÚNICA linha sem par protótipo/impl, dispatch REAL de runtime `__clsNew`/`__clsAddMsg`, sem canal declared). A forma `Dona:Membro` JÁ funcionava (SigParamHits/SendSitesArgs/PpMarkerOwners são do rastro, ordem-independentes): assinatura movida 1×, corpo intacto, param homônimo de outro ofício intacto (escopo por identidade), sends reordenados, execução idêntica, round-trip. A forma CRUA derrapava: `cUpMsg := ATail(aIdent)` era forma-de-hbclass e elegia a DONA como mensagem — no fixofi recusava com diagnóstico-mentira ("a mensagem é membro de BANCA, TALHA, VERNIZ, LUSTRO"); numa DSL de 1 mensagem editaria assinatura SEM os sends (quebra silenciosa). | Conserto `GenMsgPart`: a MENSAGEM do composto é a parte que NÃO nomeia função-de-classe do projeto (fato da co-derivação, posição nenhuma); indecidível → recusa pedindo a forma `Classe:Metodo`. |
| Q2 | ✅ **FECHADA (2026-07-07, caso 77)** — PROVA pura, nenhum conserto: o açúcar `Dona:Membro` é só política de unicidade sobre o motor genérico (nenhum `ATail`/forma no caminho). No fixofi: dona resolvida por co-derivação (paste E string-containment convergem), artefato da colagem INVERTIDA previsto por faixas (`predicted: TALHA_NA_BANCA -> CINZELA_NA_BANCA`, sem separador assumido), string de registro prevista/conferida no dump pós-edição, homônimo (`Banca:Lustro`) recusa nomeando a outra dona (TEAR), forma crua resolve dona única, execução idêntica + round-trip. | — |
| Q3 | ✅ **FECHADA (2026-07-07, caso 78)** — o buraco era REAL: o índice de mensagens elegia a última parte da colagem (`cMsg := ATail(aParts)` — forma-de-hbclass); em DSL mensagem-primeiro a DONA virava chave e `call-graph Banca:Talha`/`Talha` respondia **VAZIO em silêncio** (nem definição nem arestas). | Conserto: mensagem/dona pelo fato da co-derivação (`GenMsgPart` + dona = a parte que nomeia função-de-classe); composto sem dona identificável fica FORA do índice de mensagens (honesto — antes ganhava "dona" fantasma por posição). Caso 78: definição → símbolo invertido, aresta `~>` (nunca estática), homônimo com alvo ambíguo visível; hbclass intacto (casos 20/57). |
| Q4 | ✅ **FECHADA (2026-07-07, caso 75)** — o veneno era REAL: probe fixq4 (`... TEMPERA <forjador>`, forjador por `@ref` — a MESMA forma do pai do hbclass) fazia `t:Pintar()` sair `confirmed ... dispatches to LOUSA:PINTAR` quando em runtime seria ERRO. E o probe matou o conserto-candidato: `@Pai()` na árvore de registro NÃO distingue (o forjador viaja igual). Não há fato — a linguagem não tem canal de herança (fato 4). | Conserto entregue: vínculo escrito nunca confirma/exclui (`DispatchVia` gateia SendVerdict, DispatchHijackers e os dois passes de declaração); acerto PRÓPRIO segue decidindo (regra do VM). Rótulo novo nomeia o candidato: `possible ... may dispatch to C:M through written parents, unproven`. **MUDANÇA DE CONTRATO da suíte (portão do Diego)**: 7 asserts de alcance POR HERANÇA flipam para o possible nomeado (casos 67: 3, 68: 2, 69: 1, 70: 1); caso 66 (cenário original), 72-74 e o descendente-nomeado INTACTOS. Suíte 474/0 com o caso 75 (fixture fixq4 + régua do caso 64). Caminho honesto para recuperar decidibilidade de herança: canal de linguagem (ex.: `DECLARE CLASS ... FROM`, candidato B6+) ou evidência de runtime — nunca forma. | — |
| Q5 | **Matar o `methodQuery` da extensão** (V1): "o que está sob o cursor" vira pergunta de FATO ao CLI — `resolve-at <arq> <linha> <col>` respondida por `ppApplications` (tokens consumidos têm posição) + rastro; a extensão passa posição, nunca regex. A B4g (`match[]`/`result[]`) completa a cobertura para sites dentro de diretiva. | novo comando CLI + harness node do caso 71 re-apontado (mudança de contrato: pedir autorização do Diego, como no 71) | — (o fato existe por construção; é consumo) |
| Q6 | ✅ **FECHADA (2026-07-07, caso 72 atualizado + caso 80 novo)** — rótulo do DONO no vocabulário da DSL que o declarou: `cog declaration (rig TOTEM)`, `dote declaration (amuleto SOL)`, `oficio definition Talha (tenda Banca)` (prova na DSL NÃO-espelho, registro runtime puro). **Decisão de semântica (probe registrado)**: NÃO é a regra raiz do site do dono — no hbclass `CREATE CLASS X` tem raiz `CREATE` (`#xcommand CREATE CLASS <n> => CLASS ...`, açúcar sobre açúcar) e o rótulo sairia `(create X)` truncado, mudando 13 asserts de ~8 casos. O vocábulo é a cabeça da regra cuja expansão LIGOU o nome ao canal de classe — o `from` do próprio nome (fato do ast-3), colhido no `_HB_CLASS` do stream (dona declarativa pura) e no nome da função-dona gerada (registro runtime puro). O rótulo diz o que o dono É ("cog declaration" = o que a linha é; "rig TOTEM" = o que TOTEM é); hbclass segue `(class ...)` porque a regra `CLASS` é quem declara. Dona sem derivação cai para "class" (o nome do canal da linguagem), nunca palpite. Rótulos EPISTÊMICOS de send ("receiver class X via declared types") ficam: ali "class" é conceito da linguagem (`AS CLASS`/`_HB_CLASS`), não vocabulário do hbclass. Suíte 520/0. | `OwnerVocabMap`/`OwnerWord` no usages; casos 72 (3 asserts) e 80 | — |
| Q7 | ✅ **FECHADA (2026-07-07, caso 79)** — dois consertos, ambos fato-based. **(a) O portão da síntese** (V4): contêiner-método agora é detectado pelo fato (parte-dona = função-de-classe, qualquer posição na colagem) e a síntese `METHOD ... CLASS`+protótipo só acontece quando o VOCÁBULO da regra raiz do site escrito (`PpMarkerLift`) é a forma que a ferramenta sabe emitir (`method`, hbclass — a exceção documentada); contêiner de DSL própria DEGRADA para FUNÇÃO verificada com o fato relatado ("contêiner de DSL própria (regra 'oficio'): a síntese de método é a exceção do hbclass") — nunca síntese em projeto alheio, execução idêntica provada. **(b) Veneno NOVO achado pelo probe**: range com `QSelf()` extraído para função quebrava EM SILÊNCIO — QSelf não gera occurrence (o cheque de Self não via) e numa chamada comum o receptor não viaja; provado: `Banca/10` → `/10` com a verificação de símbolos PASSANDO. Conserto: `QSelf()` vira nó `SELF` na árvore (fato do dump) — nó SELF no range com alvo FUNÇÃO = **recusa limpa nomeando o fato e a exceção de síntese**. Documentado no ast-schema. | — |
| Q8 | ✅ **FECHADA (2026-07-07, auditoria commit a commit) — suspeita REFUTADA**: nenhuma lógica keyed a nome/forma de biblioteca em `2cca58e4b8`/`6dd32b1a24`/`9f9c116495`/`86a915f9ca`; tudo transporte 1:1 de canal da LINGUAGEM. Os três itens substantivos, verificados no fonte: **(a) os 5 gates** `iWarnings < 3 && ! fAst` (hbmain.c: `hb_compClassFind`/`ClassAdd`/`MethodAdd`/`DeclaredAdd`/`DeclaredParameterAdd`) só mantêm as tabelas do subsistema DECLARE populadas — todo diagnóstico recém-alcançável é warning NÍVEL 3 gated na EMISSÃO (hbgenerr.c:191 compara o dígito da tabela com `iWarnings`; `CLASS_NOT_FOUND` e `DUP_DECLARATION` são `"3..."`), o erro do `DECLARE_MEMBER` órfão foi explicitamente mantido só a -w3, e duplicata devolve o método EXISTENTE (sem deref NULL na ação `DecData`, harbour.y:1317). O único delta de estado abaixo de -w3 (`pVar->cType` fica `'S'`+`pClass` em vez do fallback `'O'`) não tem NENHUM leitor: os warnings de tipo (`ASSIGN_TYPE`, `MESSAGE_NOT_FOUND`...) existem só como constantes em hberrors.h — nenhum site os emite; genc/hbopt/hbdead não leem `cType`/`pClass`. O canal de tipos é write-only no core; o dump é o primeiro leitor. **(b) Campos do schema espelham a gramática**: `declarations[]` copia o ESCRITO (`hb_compAstDecl` = nome/escopo/char de tipo/nome AS CLASS direto do `HB_VARTYPE` da gramática); a seção `declared` é caminhada 1:1 de `pFirstClass`/`pFirstDeclared` (`DECLARE`/`_HB_CLASS`/`_HB_MEMBER` são keywords do LEXER no master, complex.c:158-159); byref/optional decodificam os offsets pré-existentes `HB_VT_OFFSET_*` (master hbcomp.h:104-106); os guards `'S'` espelham a condição de escrita do próprio subsistema (o conserto do lixo de malloc). **(c) Comentário do Self** (compast.c:106) é COSMÉTICO: a poda do otimizador é genérica por flags de pcode (hbopt.c intocado pelo branch, último commit 2017; `OPT_LOCAL_FLAG_POPSELF` vale para QUALQUER local `:= QSelf()`) — "hbclass Self" é exemplo motivador. **(d) Varredura por keying sem a string literal**: em TODO o código adicionado do branch há UMA comparação de string — o cheque de abreviação do alias `MEMVAR` (`hb_compAstAliasScope`, ast-1), cópia verbatim do idioma pré-existente do core (master hbmain.c:2940/2992; `M->`/`MEMVAR->` é gramática); o rastreio do pp keia só nos kinds do próprio pp (`'d'`/`'t'`/`'c'`) e índices de marker. | Nenhum conserto necessário — core limpo. Pendência cosmética OPCIONAL: reformular o comentário de compast.c:106 sem citar hbclass (ex.: "locals atribuídos de QSelf() e não usados"); candidata natural à preparação da B6 (comentário em core upstream não deveria citar biblioteca). | — |

Ordem sugerida (decisão do Diego): Q4 primeiro (é o único candidato a
resposta ERRADA hoje — pai falso envenena excluded/confirmed; os demais
degradam para recusa/possible), depois Q1-Q3/Q7 (prova ou conserto),
Q5/Q6 (direção + extensão). A B4g corre em paralelo natural: Q5 usa o que
ela exporta.

## Commits/eras a reler nesta revisão (o aviso do Diego, concretizado)

- **Era B4e (P0-P3 + P2a)** — comandos "cientes de construtos" escritos e
  testados método-primeiro; é o grosso de V2/Q1-Q3/Q7.
- **Era B4f-2/fatia de declarações + extensão v0.5.0 (caso 71)** — o
  lifting de cursor hbclass e seu contrato; V1/Q5.
- **B4f-2 `ClassParentsSeq`/`ClassGraph`** — V3/Q4.
- **B4c** — já revisada e morta na B4d (registro); nada a fazer.
- Specs correspondentes (spec-b4e, spec-b4f, spec-b4f2) permanecem como
  registro histórico com o enquadramento da época — este documento é o
  corretivo de direção; não reescrever história.

## Critério de pronto da revisão

Todas as Q fechadas (prova, conserto ou recusa honesta documentada), com
casos na suíte em DSL inventada NÃO-espelho; régua do caso 64 assertada
nos casos novos; `make test` verde; ast-schema.md atualizado onde a
resposta for "teto/relato honesto"; extensão sem regex de construto (Q5)
ou com a pendência explicitamente aceita pelo Diego.
