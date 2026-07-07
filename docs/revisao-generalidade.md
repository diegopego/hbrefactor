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
| V2 | **Cobertura da suíte enviesada**: `usages` (fixhom/fixppm/fixdsl/fixmth/fixdis/fixmv), `rename-pp-marker` (fixppm) e `rename-param` (fixsig + caso 54 em fixppm) têm prova em DSL inventada; **`rename-method` (só fixmth), `reorder-params` (só fixsig), `call-graph` (só fixsig), `extract-function` (fixext hbclass + recusa fixdsl)** não têm. | grep comando×fixture em tests/run.sh, 2026-07-07 |
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
| Q1 | `reorder-params` funciona para "método" de DSL própria? (assinatura via `SigParamHits`/`GenNameParts` + reordenação de sends com unicidade) | fixture rig.ch: reorder de um COG de 2+ params; round-trip + execução idêntica | consertar o consumo (os fatos existem: markers posicionados + rastro) ou recusa nomeando o fato faltante |
| Q2 | `rename-method Totem:Brilho` (o açúcar) resolve dono de DSL própria — ou só o `rename-pp-marker` cru? | fixhom: rename via forma `Dono:Membro` numa DSL não-espelho | se o açúcar for hbclass-shaped, generalizá-lo (é para ser SÓ política de unicidade sobre o motor genérico) |
| Q3 | `call-graph` resolve membro de DSL própria (definição + arestas dinâmicas `~>`)? | fixture: `call-graph <membro-de-DSL>` | idem Q1 — índice de mensagens vem de `GenNameParts`, deve valer para qualquer colagem |
| Q4 | ✅ **FECHADA (2026-07-07, caso 75)** — o veneno era REAL: probe fixq4 (`... TEMPERA <forjador>`, forjador por `@ref` — a MESMA forma do pai do hbclass) fazia `t:Pintar()` sair `confirmed ... dispatches to LOUSA:PINTAR` quando em runtime seria ERRO. E o probe matou o conserto-candidato: `@Pai()` na árvore de registro NÃO distingue (o forjador viaja igual). Não há fato — a linguagem não tem canal de herança (fato 4). | Conserto entregue: vínculo escrito nunca confirma/exclui (`DispatchVia` gateia SendVerdict, DispatchHijackers e os dois passes de declaração); acerto PRÓPRIO segue decidindo (regra do VM). Rótulo novo nomeia o candidato: `possible ... may dispatch to C:M through written parents, unproven`. **MUDANÇA DE CONTRATO da suíte (portão do Diego)**: 7 asserts de alcance POR HERANÇA flipam para o possible nomeado (casos 67: 3, 68: 2, 69: 1, 70: 1); caso 66 (cenário original), 72-74 e o descendente-nomeado INTACTOS. Suíte 474/0 com o caso 75 (fixture fixq4 + régua do caso 64). Caminho honesto para recuperar decidibilidade de herança: canal de linguagem (ex.: `DECLARE CLASS ... FROM`, candidato B6+) ou evidência de runtime — nunca forma. | — |
| Q5 | **Matar o `methodQuery` da extensão** (V1): "o que está sob o cursor" vira pergunta de FATO ao CLI — `resolve-at <arq> <linha> <col>` respondida por `ppApplications` (tokens consumidos têm posição) + rastro; a extensão passa posição, nunca regex. A B4g (`match[]`/`result[]`) completa a cobertura para sites dentro de diretiva. | novo comando CLI + harness node do caso 71 re-apontado (mudança de contrato: pedir autorização do Diego, como no 71) | — (o fato existe por construção; é consumo) |
| Q6 | Rótulo do DONO no vocabulário da regra raiz (V5): `cog declaration (rig TOTEM)` em vez de `(class TOTEM)` | estender o lifting existente (`SeedRootRule` já dá a palavra) aos rótulos de dono; casos 72-74 atualizados | — |
| Q7 | `extract-function` em corpo de "método" de DSL própria recusa LIMPO (nunca sintetiza hbclass em projeto alheio)? (V4) | fixture: range com Self-análogo em DSL própria | garantir recusa nomeando a exceção de síntese; documentar no ast-schema |
| Q8 | **Auditar os commits do CORE** (`feature/compiler-ast-dump`) atrás de tratamento específico de classes — suspeita do Diego (2026-07-07): "acho que isso foi errado e vai contra nossas diretivas atuais". Revisão commit a commit: `2cca58e4b8` (ast-1), `6dd32b1a24` (ast-2), `9f9c116495` (ast-3), `86a915f9ca` (ast-4, o candidato — "transport the language type channel"). Pergunta-guia: alguma LÓGICA keyed a nome/forma de biblioteca, ou só transporte 1:1 de canal da linguagem? | **Evidência preliminar já colhida (2026-07-07)**: (a) `HB_HCLASS`/`HB_HDECLARED` são estruturas PRÉ-EXISTENTES do compilador no master (hbcompdf.h, hbmain.c — o subsistema DECLARE é da LINGUAGEM, décadas antes do branch); (b) o diff INTEIRO do branch menciona "hbclass" UMA vez, em COMENTÁRIO (explica que o otimizador poda o Self — exemplo motivador, não lógica); (c) a mensagem do ast-4 registra a intenção "with no library convention anywhere"; (d) o desenho class-specific (`rcls` no SEND, convenção `F():New()`) foi REJEITADO no portão v3 da B4f. A auditoria confirma ou refuta: gates `iWarnings<3` abertos sob `fAst` mudam algo além do transporte? campos do schema (`declared`, `class`) deriváveis só para classes ou espelham a gramática? comentário do Self reformulável (cosmético). Achado real → conserto com a prova zero-impacto padrão (-w0 E -w3 + relink duplo). | — |

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
