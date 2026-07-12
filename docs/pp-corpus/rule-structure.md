# Família ESTRUTURA DA REGRA — cabeça, grupos opcionais e multi-passe

Índice: [README.md](README.md). Ensina: **a forma de uma diretiva tem mais graus
de liberdade do que parece** — ela pode não ter cabeça, seus grupos opcionais
podem ser escritos fora de ordem, e o resultado de uma regra pode ser
re-consumido por outra. Fixture: `tests/fixp6/` (DSL inventada não-espelho);
prova executável: **caso 113** da suíte. Registro de fase: [spec-p § P6](../spec-p-pp-refatoracao.md).

---

## 1. Regra SEM CABEÇA — o match começa com um marker

Uma diretiva não precisa começar por uma palavra:

```harbour
#xtranslate <x> ZORBADO => ( <x> * 2 )
```

`nTotal := nQtd ZORBADO` → `( nTotal := nQtd * 2 )`.

**Fato do core:** `ppcore.c:1161` grava `szHead = NULL` quando o primeiro token de
match é um marker (`HB_PP_TOKEN_ISMATCH`), e o dump traz `"head": null`.

**O que isso ensina para um refatorador:** a cabeça **não é a identidade** da
regra. Uma ferramenta que se ancore na cabeça (para achar a diretiva, para
renomear, para listar) simplesmente não vê essas regras. A âncora correta é
posicional: `marker: 0` (palavra literal da regra) nos `ppApplications[].tokens[]`
e as posições de `match[]`/`result[]` (ast-5).

**Medição no corpus real:** `grep` em `include/` + `contrib/` do core → **ZERO**
regras sem cabeça. É forma legal e suportada que **ninguém usa** — por isso nunca
tinha aparecido. (Vale como aviso: a ausência no corpus não prova a ausência na
linguagem.)

> **Estado no hbrefactor:** funciona **por construção**, sem código novo — a
> ferramenta nunca chaveou no `head` (ele só alimenta o RÓTULO, `<sem cabeça>`, e
> o vocabulário). `resolve-at`, `usages` e `rename` operam normalmente; o rename
> edita o uso E a regra no `.ch`, com round-trip byte-exato.

---

## 2. Grupos OPCIONAIS podem vir FORA DE ORDEM

```harbour
#xcommand VULK <n> [ KRAN <cMat> ] [ PLIX <nPeso> ] => ;
          FUNCTION vk_<n>() ;; RETURN { <"n">, <cMat>, <nPeso> }
```

O pp casa **em qualquer ordem**, e ausentes também:

```harbour
VULK Lamina KRAN "aco" PLIX 7      // ordem declarada
VULK Elmo PLIX 3 KRAN "bronze"     // INVERTIDA - casa igual
VULK Escudo                        // ambos AUSENTES
```

`.ppo`:
```
FUNCTION vk_Lamina() ;; RETURN { "Lamina", "aco", 7 }
FUNCTION vk_Elmo()   ;; RETURN { "Elmo", "bronze", 3 }   ← cada valor no slot certo
FUNCTION vk_Escudo() ;; RETURN { "Escudo",, }            ← ausentes viram vazio
```

**Mecânica:** `hb_pp_patternMatch()` trata `HB_PP_MMARKER_OPTIONAL` num laço que
re-tenta os grupos até nenhum casar mais — por isso a ordem do autor da regra é
irrelevante para o casamento.

**O que isso ensina:** **nunca derive nada da ORDEM** dos tokens. Um consumidor
que pareie "o N-ésimo literal consumido com o N-ésimo literal da regra" erra aqui.
As posições têm de vir do que o pp **consumiu** (`ppApplications[].tokens[]`, cada
um com linha/coluna byte-exatas), não da ordem declarada no `match[]`.

> **Estado no hbrefactor:** a partir da linha INVERTIDA, o rename da keyword acha
> **as duas ordens** + a regra; o LOCAL que só atravessa o grupo (clone) resolve
> `rename-local`; o marker gerador prevê paste E stringify. Nenhuma posição se
> perde.

---

## 3. MULTI-PASSE — o resultado de uma regra é re-consumido por outra

```harbour
#xcommand GLIMER <n> => VULK <n> KRAN "base"    // expande em OUTRA diretiva
```

`GLIMER Broquel` → `VULK Broquel KRAN "base"` → `FUNCTION vk_Broquel() ...`

Visível no dump, na ORDEM em que o pp aplicou:
```
app7  rule=GLIMER  line=20
app8  rule=VULK    line=20     ← a VULK reaplicada sobre o RESULTADO da GLIMER
```

O rastro `from` (ast-3) atravessa as passadas: o `from` de um token só referencia
aplicações **anteriores**, então uma varredura em ordem fecha o transitivo. Por
isso renomear `Broquel` prevê corretamente `VK_BROQUEL` — o artefato nasceu na
**segunda** passada.

### O LIMITE honesto (não é bug — é fato)

Na `GLIMER`, a palavra `KRAN` é **EMITIDA no result**. Essa ocorrência foi
**fabricada pelo pp**: ela não existe no seu fonte, logo **não tem posição** para
editar.

```
$ hbrefactor rename p6.hbp p6.prg:18:18 LIGA
hbrefactor: aplicação de #xcommand VULK em p6.prg:20 sem posição no fonte
            (include ou expansão de outra regra) - recuso
```

**Regra geral:** uma palavra de DSL que **outra regra emite** não é renomeável só
editando o fonte — parte dos seus sites nasceu da expansão. O honesto é **recusar
nomeando o motivo**, não editar as ocorrências visíveis e deixar a DSL incoerente.

---

## Lacunas (VERIFICADO)

- **[Consumo futuro]** A ordem das aplicações no dump já expõe o multi-passe
  (evidência acima: `app7` GLIMER → `app8` VULK, mesma linha). Nada falta no core.
- **[Fato do core, RESOLVIDO]** "Qual literal da regra este token casou?" NÃO era
  exportado — só `marker: 0` ("é um literal"). Isso virou bug real e foi consertado
  no core: ver [abbreviation.md](abbreviation.md) (`ast-15`/`ruletok`).
