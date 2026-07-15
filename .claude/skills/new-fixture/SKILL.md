---
name: new-fixture
description: Anda o esqueleto de uma fixture-PROJETO da suíte (>= 2 .prg + .hbp, .ch opcional), compila cada módulo sob o contrato do case 0 (-w3 -es2), e imprime o fio exato do runner (fresh<nome>/unit_N/ALL_UNITS) para costurar à mão. Use ao abrir um caso de teste novo. O scaffold cria só o que é mecânico e seguro; o fio no run.sh o Claude costura revisado.
disable-model-invocation: true
---

# new-fixture — abrir um caso de teste sem erro mecânico

Toda fixture da suíte é um **PROJETO** (≥ 2 `.prg` + `.hbp`; `.ch` opcional): a
ferramenta tem de provar que opera em nível de projeto, nunca sobre arquivo solto.
E fixture que não compila gera **diagnóstico enganoso** (CLAUDE.md §3). Este skill
tira o erro mecânico da criação e deixa você focar no que o caso PROVA.

## Passo 1 — andar o esqueleto (script)

```bash
.claude/skills/new-fixture/scaffold.sh <nome>          # 2 .prg + .hbp
.claude/skills/new-fixture/scaffold.sh <nome> --ch     # + header de DSL (#xcommand)
```

O script cria `tests/fix<nome>/`, **compila cada módulo** com `-w3 -es2 -s`
(o gate do case 0) e **recusa** se algum não compilar limpo. Depois imprime os
três trechos do fio no runner. Ele **não toca no run.sh** — isso é o passo 2.

Régua do idioma (§7), já embutida no template:
- **código NOVO nosso usa `#xcommand`/`#xtranslate`**, nunca `#command` — a
  família `x` (comparação EXATA) elimina a classe de bugs da abreviação dBase.
  **Exceção:** fixture cujo **assunto** É a abreviação dBase — aí `#command` é
  obrigatório, senão o teste passa por **vacuidade**.
- sem variável que forme keyword em uppercase (`nIL`); `MEMVAR` antes de
  `PRIVATE`; nada de dead store (`LOCAL x := 0` seguido de `x := ...` → W0032);
  comentário `//`, não `/* */`.

## Passo 2 — costurar o fio no runner (à mão, revisado)

O `tests/run.sh` tem ordem e convenções delicadas; o fio se faz à mão, com o
scaffold já tendo impresso os trechos prontos. São **três** pontos:

1. **helper `fresh<nome>()`** — junto dos outros `fresh*()` (topo do run.sh):
   copia a fixture para `tmp/<case-name>` (a suíte roda sobre a CÓPIA, nunca o
   original). Se tem `.ch`, o `cp` inclui `*.ch` (o scaffold já ajusta isso).
2. **corpo `unit_N()`** — o caso em si. Invoca `"$BIN" <verbo> fix<nome>.hbp
   arquivo:lin:col <arg>`, checa `exit`, e faz `check`/`diff`/`grep` sobre o
   fonte editado e o `out.log`. Para recusa: provar o fonte **byte a byte
   intacto** (`cmp -s`). Colunas: **COMPUTAR, nunca contar na cabeça** (§7) —
   `python3 -c "print(open('a.prg').read().splitlines()[L-1].index('nome')+1)"`
   (dump é 0-based, CLI 1-based).
3. **registrar N em `ALL_UNITS`** (fim do run.sh) — o scaffold sugere o próximo
   número livre a partir da lista atual.

## Passo 3 — verde

```bash
make test                    # a suíte inteira (paralela) tem de ficar verde
# JOBS=1 SÓ se você mexeu no RUNNER (§3), não por conteúdo de teste novo
```

Um caso NOVO da própria entrega não precisa de consulta ao Diego; **re-rotular
expectativa de teste PRÉ-EXISTENTE, sim** (§3 — o lado que cede é decisão dele).

## Limites — o que o scaffold NÃO faz

- Não inventa o **assunto** do caso: os módulos são um esqueleto genérico
  (rename entre dois módulos). O que o caso prova é você que escreve.
- Não mexe no `run.sh` — o fio é seu, revisado (evita quebrar a ordem/paralelo).
- Não cria `expected/` — se o caso compara contra fonte-alvo, crie
  `tests/fix<nome>/expected/` à mão como as fixtures existentes.
