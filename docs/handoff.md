# Handoff — onde o trabalho parou, e como retomar

Companheiro do [prompt-revisao-anti-heuristica.md](prompt-revisao-anti-heuristica.md)
(que cobre a **P-AUDIT**, e só ela). Este cobre **o resto**.

> **Este documento é um INSTRUMENTO, não um relatório de estado.** O estado vive no
> `docs/roadmap.md` e no `docs/pp-corpus/ROADMAP.md` — e é lá que se lê, sempre. Se
> algo aqui contradisser o roadmap, **o roadmap ganha**: um segundo lugar guardando os
> mesmos fatos envelhece e vira fonte de verdade concorrente. Aqui só entra o que o
> roadmap NÃO diz: qual é a próxima sessão, o que ela precisa saber que não está
> escrito em lugar nenhum, e onde ela vai tropeçar.

---

## 1. O que acabou de ficar pronto (e por que isso muda o próximo passo)

**A P-AUDIT foi EXECUTADA** (sessão dedicada). Três achados provados por fixture e
consertados — o pior deles: o `rename` media a fronteira do projeto pelo **CWD do
processo**, então editava um `.ch` de OUTRO projeto (no limite, o `hbclass.ch` da
instalação) e imprimia `verified`. Detalhe no roadmap § P. **Ela deixou o resíduo A4**,
que é a próxima sessão.

**A página parou de mentir, e virou portão.** Havia transcript INVENTADO nela (projetos
que não existem). Agora existe `tests/site/` + `make site-examples`: todo exemplo da
landing page é **gerado por execução real** — o fonte antes compila, o comando roda, o
fonte depois compila, e recusa/relatório não podem tocar num byte. `make site-check`
**falha** se a página divergir. Contrato em [`tests/site/README.md`](../tests/site/README.md).

**O produto é INGLÊS** (regra do Diego, 2026-07-13; está no CLAUDE.md). Mensagens da
CLI, manual, página, CHANGELOG e toda string da extensão VSCode. Português fica para a
**conversa**: roadmap, specs, CLAUDE.md, comentário de fonte, mensagem de commit.

> **Consequência que vai te morder:** a suíte **grepa as mensagens da ferramenta** (é o
> contrato). Mexeu numa string de saída → asserção quebra, e está CERTA em quebrar. E a
> extensão casa a mensagem do CLI em `extension.js` (`/no compile-time identifier/`), com
> o harness (`vscode/test-resolveat.js`) assertando essa string **no fonte dela**. Três
> lugares, sempre juntos.

---

## 2. A próxima sessão: **A4** (o resíduo da P-AUDIT)

É a de melhor relação valor/custo que existe agora — **a peça já está pronta e não é
consultada**. Duas pernas, mesma família:

**(a) `rename-dsl` trata regra MORTA como viva nas colisões DELE PRÓPRIO.** O A2
construiu o `RuleDeadInModule` (lê o tempo de vida da diretiva: só libera quando a
remoção mora no arquivo do módulo E nenhum token de fonte a precede). Cinco verbos o
consultam. As colisões do próprio `rename-dsl` — `"'X' is already a rule head"` e as de
abreviação (~5988-6003 no `src/hbrefactor.prg`) — **não**. Resultado: recusa falsa
remanescente, da mesma classe do caso 115. Não é fato faltando; é fato não lido.

**(b) O `#un…` ÓRFÃO (`undoes: null`) segue SEM CONSUMIDOR.** Uma diretiva que desliga
uma regra que não existe é **código morto silencioso** — o Harbour aceita calado. O dump
já traz o fato. O lugar natural de mostrá-lo é o `usages` da palavra. *(Cuidado: o
critério do `adr-003` diz "fato sem consumidor = fato local, não arquitetura" — aqui o
consumidor é um RELATO, não um verbo novo. Verbo novo é portão do Diego.)*

**Método:** fixture primeiro, sempre — provar a recusa falsa ANTES de consertar (foi
assim que A1/A2/A3 foram feitos, e é o que separa conserto de palpite). O CHANGELOG e o
manual já **declaram os dois limites como abertos**; quando fecharem, os dois artefatos
precisam ser corrigidos (a skill `/update-manual` cobre).

---

## 3. Depois do A4, nesta ordem

**3.1 — Migrar os quatro transcripts colados à mão da página para `tests/site/`.**
As seções profundas (rename de `DATA`, genealogia de regra, tempo de vida de diretiva,
sequestro por abreviação) ainda têm saída **digitada**. Foram conferidas contra fixtures
reais em 2026-07-13 e estão corretas — **mas estão FORA do portão**, e é exatamente assim
que as anteriores apodreceram (uma delas chegou a exibir uma mensagem em português depois
que a CLI virou inglês, e nenhum teste acusou). Enquanto elas existirem, a regra vale só
para a parte da página que já doeu.

**3.2 — P12 + P13 (exploração; eles se destravam mutuamente — rode JUNTOS).**
O `ast-16` entregou o **tempo de vida da diretiva** (o dump diz que uma regra foi
removida, e **qual**). Isso destravou o P12, e quase ninguém percebe por quê: o P12 (o pp
como *engenho de busca*) precisava injetar uma regra de **consulta**, deixá-la casar e
**tirá-la da mesa** antes que contaminasse o build. Era o mecanismo que faltava.

**Ela é exploratória — não é uma entrega.** A saída legítima inclui *"não dá, e eis a
varredura que prova"*. O CLAUDE.md exige que toda recusa sobre o core venha com varredura
REGISTRADA (`--help` inteiro, API pública, `tests/` do core, ChangeLog) — porque *"não
achei" quase sempre é "não procurei"*, e isso já custou um veredito errado publicado.

Prompt para colar:

> Você vai **explorar** (não entregar) duas fatias da fase P, que se destravam
> mutuamente. Leia antes, nesta ordem: `CLAUDE.md` (§ REGRA DO FATO e § GATILHOS),
> `docs/pp-corpus/pp-as-search.md` (P12), `docs/pp-corpus/directive-scope.md` § 4 (P13)
> e `docs/ast-schema.md` (o contrato do dump — em especial `undoes`/`removed`, do
> `ast-16`).
>
> **P12 — o preprocessador como ENGENHO DE BUSCA.** A ideia do Diego: o pp já é um
> casador de padrões industrial, e nós o usamos só para expandir. Um `#xcommand` é uma
> *query*. A pergunta a sondar: **dá para injetar uma regra cuja única função é
> RECONHECER (não reescrever), rodá-la sobre o código, colher os sites, e removê-la** —
> sem que ela vaze para o build? O mecanismo de remoção existe desde o `ast-16`; use o
> **pp vivo** (`__pp_init` / `__pp_process`, como o P11 fez em `c391408`), nunca o
> `.ppo` destrutivo.
>
> **P13 — os USOS que o escopo de diretiva promove.** O pedido textual do Diego está
> citado no § 4 do `directive-scope.md`. A pergunta em aberto que ele mesmo levantou:
> *dá para injetar diretiva num **bloco arbitrário** e desligá-la depois?* Cuidado: o pp
> é **linha a linha**, então "escopo" aqui é **posicional**, não sintático — sondar o
> limite honesto disso é metade da fatia. As **três** famílias de remoção contam
> (`#undef` inclusive; foi a que eu esqueci na primeira volta, e o Diego pegou).
>
> **Método:** probe executável, sempre. Fixture `.prg` que compila limpo sob `-w3 -es2`
> (exportar `HB_BIN`!). Nada de conclusão por leitura de fonte. Registre o que sondou e
> **não** funcionou — silêncio de busca registrado vale para a próxima sessão.
>
> **Saída:** o que o pp PODE fazer (com o probe que prova), o que ele NÃO pode (com a
> varredura que sustenta a recusa), e o que isso habilita no hbrefactor. **Não construa
> verbo novo** — isso é portão do Diego (D-P5, abaixo).

**3.3 — P-DOC**: próxima família do corpus do pp = um contrib (por medição). Famílias
1-4 entregues. Regra dura do Diego: **lacuna real PAUSA a exploração e vira experimento
de core imediato**.

---

## 4. O que é DECISÃO DO DIEGO, e não deve ser "resolvido" por iniciativa

- **Portão D-P5 — migração de DSL como verbo novo.** O desenho está pronto e escrito
  (`roadmap.md`, Eixo B). Está barrado por **duas regras do projeto**, não por
  dificuldade técnica: (a) verbo novo exige portão dele; (b) o critério do `adr-003`
  (*"fato sem consumidor = fato local, não arquitetura"*). Ele espera desde 2026-07-12.
- **B6 — limpeza do diff do PR.** Executar **só** quando ele for abrir o PR (ordem
  dele). O que sai do branch é pequeno e está listado no `roadmap.md` § B6 — que carrega
  também a **retratação** de um achado meu que era falso; leia-a antes de tocar no
  assunto.
- **Commit no core e push:** autorização **por-commit**, sempre. Não encadear.
- **PENDENTE AGORA:** o `harbour-core/site/index.html` está **sujo** com os indicadores
  re-medidos (913→942, 112→115). É mudança legítima e já medida, mas commit no core é
  autorização dele. Não commitar por iniciativa.

---

## 5. Onde você vai tropeçar (custou caro, não está óbvio no código)

- **`git checkout -- <arquivo>` destrói trabalho não-commitado, e é irreversível.** Eu
  o usei para limpar um teste e apaguei edições de uma hora antes. Teste em **cópia no
  scratchpad**, nunca no fonte real.
- **O shell é `zsh`**: `for x in $VAR` **não** faz word-splitting como no bash. Uma
  régua de verificação minha "passou" por vacuidade por causa disso.
- **`bin/` é lixo de build (ignorado); `tools/` é o que se versiona.** Escrevi dois
  scripts em `bin/`, "commitei", e o `.gitignore` os engoliu — as mensagens de commit
  afirmavam o que não existia.
- **Número em página só se for MEDIDO, e exemplo só se for EXECUTADO** (`make
  site-check` falha nos dois). **NUNCA edite entre os marcadores `SITE-EX:*:BEGIN/END`**
  do `site/index.html` — são gerados; a próxima execução sobrescreve e o portão acusa.
  E **verifique a BASE antes de concluir dela**: um `master` local sete commits atrasado
  me fez acusar o upstream do Harbour de poluir o próprio branch. Achado falso,
  publicado.
- **Antes de escrever entrada de CHANGELOG, CONFIRA se a sessão da entrega já escreveu
  uma.** Eu dupliquei a entrada da P-AUDIT por não olhar primeiro; a regra da skill é
  *conferir e completar*, não duplicar.
- **O hook `.claude/hooks/anti-heuristica.sh` barra `git commit`** quando o diff de
  `src/hbrefactor.prg` cheira a heurística. Ele é PreToolUse e é lido no **início da
  sessão**. Se ele te barrar, ele provavelmente está certo — leia a mensagem antes de
  contorná-lo. *(Ele TEM falso positivo conhecido: acusava `hb_FNameNameExt` usado só
  para EXIBIR o nome numa mensagem. O gatilho é CASAR por basename, não exibir; o padrão
  foi apertado em 2026-07-13 e continua pegando as cinco formas de casamento real. Se
  apertar de novo, PROVE os dois lados antes.)*
