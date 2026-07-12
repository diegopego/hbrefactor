# Spec — rename de DATA/VAR member de classe (lacuna achada pelo P-DOC)

Origem: a família **hbclass** do corpus P-DOC ([pp-corpus/class.md](pp-corpus/class.md)
§ Lacunas) surfou que o `rename` sobre `::nSaldo` recusa honesto — não há como
renomear um DATA/VAR member. Regra do Diego (2026-07-11): lacuna PAUSA a
exploração + experimento imediato. Experimento (investigação por FATO) FEITO;
este spec é o desenho + o **portão a submeter ao Diego ANTES de implementar**.

## Achado da investigação — a INFO basta, a recusa é limite v1 deliberado

Provado por FATO (fixtures no scratchpad, DSL real hbclass + homônimo entre
classes):

1. **A recusa é um freio v1 EXPLÍCITO**, não falta de fato
   ([hbrefactor.prg:10762-10771](../src/hbrefactor.prg#L10762)): `RenameMethod`
   acha o send `_NSALDO` (o setter) e recusa com "é VAR/DATA, não método; fora do
   escopo v1". O comentário no código já diz "fora do escopo v1".
2. **`resolve-at` no `VAR nSaldo`** → `Conta:nSaldo` (dona única). A declaração é
   localizável e escopada.
3. **`usages Conta:nSaldo`** acha TODOS os sítios, cada um com seu veredito de 3
   camadas: `VAR nSaldo` (declaração, class CONTA); `::nSaldo` dentro de método
   `confirmed` (via `Self AS CLASS Conta`); `VAR nSaldo` de OUTRA classe
   `excluded` (homônimo Poupanca separado corretamente); `oC:nSaldo` de receptor
   não-tipado `possible`.
4. **O setter é o MESMO token textual.** `::nSaldo` (ler) e `::nSaldo := x`
   (escrever) são o mesmo `:nSaldo` no fonte; o compilador é que gera o send
   `_NSALDO` para a escrita. Editar o texto `:nSaldo → :nTotal` cobre leitura E
   escrita de uma vez.
5. **A string de registro re-deriva.** O `{"nSaldo"}` do `oClass:AddMultiData` é
   stringify do marker VAR — renomear `VAR nSaldo → nTotal` faz o pp regenerar
   `{"nTotal"}`, exatamente como a `"Deposita"` de um método. Nada a editar à mão.

**Conclusão: NÃO é experimento de core** (nada a estender — a info toda existe no
dump/usages). É a **completude natural do `rename-method` para o caso DATA**.

## Desenho proposto (a submeter ao portão)

Não é comando novo: o `rename` unificado (fase U) já despacha `VAR nSaldo` /
`::nSaldo` para o motor de método (resolve `Conta:nSaldo`). Falta o motor TRATAR o
caso DATA em vez de recusar:

- **Reconhecer DATA vs método por FATO.** Hoje o send `_NSALDO` dispara a recusa;
  vira o SINAL de "é DATA member" (getter `nSaldo` + setter `_nSaldo`). O dump já
  distingue (a var declaration vs a method definition aparecem diferentes no
  usages).
- **Editar a declaração `VAR <nome>`** (a âncora de escrita já é fato do dump —
  posição byte-exata do token do nome), em vez da declaração/impl de método.
- **Renomear a mensagem** nos sítios textuais `:<nome>` (cobre getter e setter de
  uma vez, achado 4), com o MESMO contrato de 3 camadas do rename-method:
  confirmed edita, excluded fica, possible segue a política vigente de send.
- **Unicidade (a salvaguarda, herdada do método).** Só renomeia quando `<nome>`
  pertence a UMA classe do projeto; homônimo entre classes → recusa nomeada (já é
  o comportamento — provado com Conta/Poupanca).
- **Verificação de símbolos:** o mapa esperado ganha DUAS entradas —
  `NSALDO → NOVO` (getter) **e** `_NSALDO → _NOVO` (setter); o resto do rito
  (recompila + `HrbSymbolsRenamed` + rollback) fica igual. A string de registro
  re-deriva e a contagem fecha.
- **Pré-requisito de consumo:** o `resolve-at` de `::nSaldo` hoje devolve `nSaldo`
  cru (não escopa à classe), embora o `usages` saiba. Para o `rename` no site de
  USO (`::nSaldo`) despachar certo, o `resolve-at` precisa consumir o
  `Self AS CLASS` (fato já no dump). Editar `VAR nSaldo` já funciona sem isso.

## Riscos / perguntas honestas (para o portão)

- **`possible` sends (receptor não-tipado, `oC:nSaldo`).** Como no rename-method:
  a unicidade garante que `:nSaldo` só responde a Conta, então o rename textual da
  mensagem é seguro mesmo com receptor não-tipado. Mas vale confirmar a POLÍTICA:
  editar os possible (mensagem é global) ou deixá-los e avisar? Decisão de
  contrato — proponho espelhar exatamente o rename-method (sem inventar diferença).
- **DATA herdada / `ACCESS`/`ASSIGN`.** Esta fatia mira `VAR`/`DATA` simples. VAR
  com `ACCESS`/`ASSIGN` (métodos getter/setter explícitos) e DATA herdada de
  superclasse são casos a delimitar (provável fatia 2 ou recusa honesta).
- **Genérico > específico.** É completude do rename-method (mesmo motor), não um
  `rename-data` dedicado — fica fiel à regra. Confirmar que o desenho não vira um
  comando à parte.

## Portão a submeter ao Diego

1. Implementar a completude rename-DATA no motor do rename-method (sem comando
   novo), fatia 1 = `VAR`/`DATA` simples, unicidade + 3 camadas herdadas,
   getter+setter no mapa de símbolos?
2. Política dos `possible`: espelhar o rename-method (recomendado) ou tratar
   diferente?
3. Escopo da fatia 1: só `VAR`/`DATA` simples agora, `ACCESS`/`ASSIGN`/herança
   como fatia 2/recusa?

Prova de pronto (se o portão abrir): caso na suíte com classe única (rename do
`VAR` + leituras + escritas + a string de registro, byte-exato e rollback) +
homônimo entre classes (recusa nomeada) + DSL não-espelho com DATA member; zero
regressão; família hbclass do corpus atualizada com a lente "agora renomeável".

## § Executado (2026-07-11, portão aberto pelo Diego: "implementa a fatia 1")

Fatia 1 ENTREGUE, **zero mudança no core** (é consumo de fato já existente). No
motor do `RenameMethod` ([hbrefactor.prg:10617](../src/hbrefactor.prg#L10617)):
- **Detecção por FATO** (`lData`): a presença do send `_NOME` (o setter) — que
  antes DISPARAVA a recusa v1 — agora SINALIZA "é DATA member". Sem keyword.
- **Getter+setter num só edit**: o loop de sends casa `NOME` (getter) E, para
  DATA, `_NOME` (setter); `SendLineHits` acha a grafia crua `:NOME` na linha (a
  mesma para ler e escrever) — editá-la cobre os dois.
- **Mapa de símbolos**: `hMap` ganha `NOME→novo` E `_NOME→_novo` (os dois viram
  símbolo no `.hrb`); a string de registro re-deriva (stringify do marker VAR) e
  a verificação `HrbSymbolsRenamed` + recompilação + rollback fecham igual ao
  método. A declaração `VAR` é editada pelas sementes (já eram fato).
- **Segurança herdada**: unicidade (homônimo entre classes recusa nomeando a
  outra), colisão de nome novo (getter E setter), 3 camadas. Rótulo honesto
  `rename-data:`.
- **Provas**: caso 48 re-baselinado (o que era recusa v1 virou sucesso —
  getter+setter+INLINE+round-trip byte-exato) + **caso 110** novo (fixture
  `fixdata`: homônimo `nSaldo` recusa, `nLimite` único sucede inclusive nos usos
  externos por local não-tipado — mensagem global guardada pela unicidade). Suíte
  **825/0** paralelo × `JOBS=1`; `make ppcorpus` 16/16; sem lexdiff (core intacto).
- **Generalidade**: o motor NÃO menciona `VAR`/`DATA`/hbclass — opera sobre o send
  `_NOME` e a mensagem, fatos de compilação; vale para QUALQUER DSL que gere DATA
  member pelo canal `_HB_MEMBER`.

Fatia 2 (backlog): `ACCESS`/`ASSIGN` (getter/setter explícitos), DATA herdada de
superclasse, e o resolve-at de `::membro` escopando a classe (para o rename a
partir do site de USO, não só da declaração).
