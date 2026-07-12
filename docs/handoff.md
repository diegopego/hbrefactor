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

O `ast-16` entregou o **tempo de vida da diretiva**: o dump passou a dizer que uma
regra foi **removida** (`#undef` / `#un[x|y]command` / `#un[x|y]translate`), e **qual**
regra a remoção matou (`undoes`). Detalhe em [ast-schema.md](ast-schema.md) e
[pp-corpus/directive-scope.md](pp-corpus/directive-scope.md).

**Isso desbloqueou o P12, e quase ninguém percebe por quê.** O P12 (o pp como *engenho
de busca*) precisava injetar uma regra de **consulta**, deixá-la casar, e **tirá-la da
mesa** antes que ela contaminasse o build. Era o mecanismo que faltava — e ele agora
existe, é oficial, e o dump o enxerga. **P12 e P13 se destravam mutuamente: rode-os
JUNTOS, na mesma sessão.**

---

## 2. A próxima sessão: EXPLORAÇÃO (P12 + P13)

**Ela é exploratória — não é uma entrega.** A saída legítima inclui *"não dá, e eis a
varredura que prova"*. O CLAUDE.md exige que toda recusa sobre o core venha com
varredura REGISTRADA (`--help` inteiro, API pública, `tests/` do core, ChangeLog) —
porque *"não achei" quase sempre é "não procurei"*, e isso já custou um veredito errado
publicado.

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

---

## 3. O que é DECISÃO DO DIEGO, e não deve ser "resolvido" por iniciativa

- **Portão D-P5 — migração de DSL como verbo novo.** O desenho está pronto e escrito
  (`roadmap.md`, Eixo B). Está barrado por **duas regras do projeto**, não por
  dificuldade técnica: (a) verbo novo exige portão dele; (b) o critério do `adr-003`
  (*"fato sem consumidor = fato local, não arquitetura"*). Ele espera desde 2026-07-12.
- **B6 — limpeza do diff do PR.** Executar **só** quando ele for abrir o PR (ordem
  dele). O que sai do branch é pequeno e está listado no `roadmap.md` § B6 — que carrega
  também a **retratação** de um achado meu que era falso; leia-a antes de tocar no
  assunto.
- **Commit no core e push:** autorização **por-commit**, sempre. Não encadear.

---

## 4. Onde você vai tropeçar (custou caro, não está óbvio no código)

- **`git checkout -- <arquivo>` destrói trabalho não-commitado, e é irreversível.** Eu
  o usei para limpar um teste e apaguei edições de uma hora antes. Teste em **cópia no
  scratchpad**, nunca no fonte real.
- **O shell é `zsh`**: `for x in $VAR` **não** faz word-splitting como no bash. Uma
  régua de verificação minha "passou" por vacuidade por causa disso.
- **`bin/` é lixo de build (ignorado); `tools/` é o que se versiona.** Escrevi dois
  scripts em `bin/`, "commitei", e o `.gitignore` os engoliu — as mensagens de commit
  afirmavam o que não existia.
- **Número em página só se for MEDIDO** (`make site-check` falha se defasar). E
  **verifique a BASE antes de concluir dela**: um `master` local sete commits atrasado
  me fez acusar o upstream do Harbour de poluir o próprio branch. Achado falso,
  publicado. Ambas as regras estão no CLAUDE.md, com as cicatrizes.
- **O hook `.claude/hooks/anti-heuristica.sh` barra `git commit`** quando o diff de
  `src/hbrefactor.prg` cheira a heurística. Ele é PreToolUse e é lido no **início da
  sessão**. Se ele te barrar, ele provavelmente está certo — leia a mensagem antes de
  contorná-lo.
