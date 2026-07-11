# ADR 002 — `rename` unificado e a descontinuação dos oito `rename-*`

Data: 2026-07-11. Status: **APROVADA pelo Diego** (portão § U aberto na
mesma sessão; duas escolhas: (D-U1) **descontinuar + remover** os oito
`rename-*` — não manter como aliases; (D-U2) cobrir **todos os oito alvos**
na fatia 1). Contexto executável:
[spec-u-verbos-unificados.md](spec-u-verbos-unificados.md),
[roadmap.md](roadmap.md) § U.

## O problema

A CLI expunha oito comandos de rename, um por ESPÉCIE de alvo
(`rename-local`, `rename-param`, `rename-static`, `rename-memvar`,
`rename-function`, `rename-method`, `rename-dsl`, `rename-pp-marker`).
Renomear exigia que o usuário **classificasse o alvo de antemão** no sufixo
do comando — a mesma taxonomia que o compilador já resolve e que a
ferramenta já consome por POSIÇÃO em `resolve-at`/`usages --at` (Q5).
Repetir a taxonomia no sufixo é uma **réplica sintática na superfície da
CLI**, o anti-padrão que O NORTE proíbe no motor: a fonte da verdade é o
compilador, não uma tabela de tipos remontada à mão — aqui, na UX.

## A decisão

1. **Um verbo, `rename <projeto> <arq:linha:col> <novo>`.** O KIND vem do
   FATO sob o cursor; o dispatcher delega ao `rename-*` específico por
   dentro, com saída **byte-idêntica por construção** (reuso, não
   reimplementação). Ponto ambíguo/sem fato = recusa nomeando a exceção,
   nunca palpite.

2. **Os oito `rename-*` são DESCONTINUADOS e serão REMOVIDOS** (não viram
   aliases retrocompatíveis permanentes). Escolha do Diego sobre a
   alternativa "manter 100% funcionais + ADR". Racional: a superfície menor
   é o estado final fiel a O NORTE; aliases perenes preservariam a réplica
   que a fase existe para matar.

3. **Remoção em DOIS passos** (implícito na forma "descontinuar + remover
   num passo seguinte"):
   - **Fatia 1 (esta):** entrega o `rename`; marca os oito como
     descontinuados no `--help`; mantém-nos **funcionais** — eles são o
     MOTOR da delegação E o ORÁCULO do teste byte-idêntico (o `diff` compara
     `rename <pos>` contra o `rename-*` vivo). A extensão ganha o comando
     unificado "Rename Symbol" (0.12.0) e marca os comandos por-kind como
     descontinuados.
   - **Fatia 2 (seguinte):** remove a superfície pública dos oito do
     `Main`/`Usage` (as funções `Rename*` sobrevivem como delegados
     internos); migra o harness (as invocações `rename-*` viram `rename
     <pos>` ou golden congelado — sem o par vivo, o byte-idêntico vira
     asserção contra saída esperada gravada); CHANGELOG do corte.

## Por que não manter aliases

- A régua de valor da fase é a superfície ENXUTA; um alias perene é a
  réplica sobrevivendo com outro nome.
- O motor não é perdido: as funções `RenameLocal`/`RenameStatic`/… ficam
  como delegados internos do `rename`. "Remover o comando" ≠ "remover a
  capacidade".
- Custo assumido: migração do harness (~40 invocações) e da extensão, e a
  perda do oráculo-vivo para o teste (compensada por golden congelado). O
  Diego aceitou o custo em troca do estado final limpo.

## O que NÃO muda

`extract`/`reorder`/`inline-local` seguem com seus argumentos próprios — uma
posição não especifica um range de extração nem uma permutação de
parâmetros (o fato não os cobre com só o ponto). Renomear CLASSE fica fora
(nenhum dos oito verbos cobre; seria fase própria). O contrato de verificação
por recompilação + rollback é intacto: o `rename` delega às mesmas funções
que já o carregam.
