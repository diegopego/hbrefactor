---
name: build-core
description: Rebuilda o harbour-core (branch feature/compiler-ast-dump) sem cair nas 3 armadilhas do CLAUDE.md §2 — relink de harbour E hbmk2, binários apagados à força, e sincronização do parser (.y → .yyc/.yyh commitados). Use depois de editar o compilador/pp do core, ou a gramática. Não commita nada (commit é autorização por-commit do Diego).
disable-model-invocation: true
---

# build-core — rebuild do core sem os footguns do §2

Editar o compilador/pp do harbour-core e reconstruir tem **três armadilhas
catalogadas** (CLAUDE.md §2, cicatriz §5.1). Este skill encapsula a sequência
correta num script — portão executável, não checklist que se esquece.

## Quando usar

- Depois de editar qualquer coisa em `~/devel/harbour-core/harbour/src/`
  (compilador, pp, RTL) e você precisa dos binários novos em `HB_BIN`.
- **`--grammar`** quando a mudança tocou a GRAMÁTICA (`src/compiler/harbour.y`):
  aí o parser precisa ser regenerado **e** os `.yyc/.yyh` commitados sincronizados.

## As 3 armadilhas que o script resolve

| # | armadilha | o que o script faz |
|---|-----------|--------------------|
| a | mudança no compilador exige rebuildar **harbour E hbmk2** (o hbmk2 EMBUTE o compilador — linka `libhbcplr`; hbmk2 velho emite dump de schema antigo mesmo com harbour novo) | apaga e reconstrói os dois |
| b | o `make` **mente "up to date"** e não relinca | `rm -f bin/linux/gcc/{harbour,hbmk2}` antes do build |
| c | `HB_REBUILD_PARSER=yes` regenera `obj/<plat>/harboury.c` a partir do `.y`, mas **NÃO** os `harbour.yyc/.yyh` COMMITADOS | copia o parser regenerado para os `.yyc/.yyh` e faz um rebuild **default** para provar que o parser commitado carrega a feature |

## Como rodar

```bash
# mudança só no C do compilador/pp:
.claude/skills/build-core/rebuild.sh

# mudança na gramática (harbour.y):
.claude/skills/build-core/rebuild.sh --grammar

# core em outro caminho (default: derivado de HB_BIN, senão ~/devel/harbour-core/harbour):
.claude/skills/build-core/rebuild.sh --grammar /caminho/para/harbour-core/harbour
```

O script:
1. apaga `harbour` e `hbmk2` (armadilha b);
2. `make` — com `HB_REBUILD_PARSER=yes` se `--grammar` (armadilha c);
3. se `--grammar`: copia `obj/**/harboury.{c,h}` → `src/compiler/harbour.{yyc,yyh}` e
   **reconstrói sem a flag** para provar o parser commitado;
4. **verifica**: os dois binários existem e o `harbour` carrega o schema do dump
   (`strings bin/linux/gcc/harbour | grep ast-` — a prova do core CLAUDE.md).

## O que o script NÃO faz — e por quê

- **Não commita.** Commit no core é autorização por-commit do Diego (§6). Com
  `--grammar`, o lembrete final diz para commitar os **três juntos** (`.y` +
  `.yyc` + `.yyh`) — nunca só o `.y`, ou o parser commitado fica fora de passo.
- **Não mexe no NEWS.md nem na landing page do core.** Isso é o pipeline
  `commit → NEWS.md → site` (skill `/update-manual`, CLAUDE.md §5), passo seguinte.
- **Não decide** se a mudança no core é a certa — só a materializa em binário
  confiável para a ferramenta consumir.

## Depois

- Rode `make test` no hbrefactor com o `HB_BIN` novo — o **caso 122** fica
  vermelho na hora se core e ferramenta divergirem de schema (§1.5).
- Confira `git -C ~/devel/harbour-core/harbour status` antes de qualquer commit.
