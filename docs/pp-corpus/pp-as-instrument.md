# Família O PP COMO INSTRUMENTO — os canais do core, e o que cada um dá

Índice: [README.md](README.md). Ensina: **o pp não é só uma fonte de fato — é um
motor que já roda em todo build.** Esta família cataloga os canais pelos quais o
core te deixa *usar* o pp, o que cada um entrega e **o que cada um destrói**.
Registro de fase: [spec-p § P7](../spec-p-pp-refatoracao.md).

> **Aviso de método (a lição mais cara desta fase):** eu **recusei** "o pp como
> motor de reescrita" olhando só um canal (`.ppo`) e declarei impossibilidade —
> veredito ERRADO, publicado. O Diego apontou `tests/hbpp/hbpptest.prg` e o
> `__pp_process` derrubou a premissa. **Antes de dizer "o pp não consegue X",
> varra a superfície inteira:** `--help` do `harbour`/`hbmk2`, a API pública
> (`include/hbpp.h`), e sobretudo os **`tests/` do core** — é lá que a API viva
> aparece.

---

## Catálogo dos canais

| canal | o que dá | o que DESTRÓI / limita |
|---|---|---|
| `-p` → **`.ppo`** | o módulo **inteiro** expandido | **comentários, `#include`, formatação** — irreversível |
| `-p+` → **`.ppt`** | o **traço** passo a passo, anotado por linha-fonte | é TEXTO, sem identidade estável de token |
| `-u` | **isola**: aplica só as SUAS regras, deixa o resto da linguagem em paz | ainda passa pelo `.ppo` (mesma destruição) |
| `-gd` (+ `-sm`) | **lista de dependências** (`.d`): quais includes o módulo usou, com o **caminho onde achou**, fecho transitivo | grava o `.d` no **CWD** (não ao lado do fonte) — use `-o<dir>` |
| `-x` → **dump AST** | o rastro estruturado (`ppRules`/`ppApplications`/`from`) | é o canal do hbrefactor; descreve o que **casou**, não o que casaria |
| **`__pp_init` / `__pp_process`** | o pp **vivo, em processo, LINHA A LINHA**, dirigido por código Harbour | *(a explorar — fatia P11)* |

---

## 1. `.ppo` — o expandido. Ótimo oráculo, **péssimo escritor**

```
$ harbour app.prg -p -u -I.      # -u: só as MINHAS regras
```

Com `-u` o isolamento é real: `ANTIGO Alfa COM nX` vira `MODERNO Alfa VALOR nX`,
e `? "oi"` **não** vira `QOut( "oi" )` — o resto da linguagem passa intacto.

Mas o `.ppo` guarda **o código e só o código**. Medido num fonte de 11 linhas com
4 comentários:

| | fonte | `.ppo` (mesmo com `-u`) |
|---|---|---|
| comentários | 4 | **0** |
| `#include` | sim | **destruído** |
| formatação | do autor | normalizada |

**Veredito: o `.ppo` NÃO pode ser a fonte de um arquivo que a ferramenta grava.**
Colide com o contrato do hbrefactor (o caso 107 exige *"comentário com o nome velho
INTACTO"*) e com a regra fundadora (**nunca editar o não-verificável**).

## 2. `.ppo` + `.hrb` como ORÁCULO DE EQUIVALÊNCIA — já em produção

O papel em que o `.ppo` é excelente é o de **juiz**, não de escriba. O padrão-ouro
do `rename-dsl` (e do `rename-rule-marker`):

> *edita → re-preprocessa → o `.ppo` e o `.hrb` de TODOS os módulos têm de sair
> **byte-idênticos**; qualquer diferença = **rollback**.*

Para um alpha-rename (trocar o nome de um marker, que é variável local da regra)
isso é a prova perfeita: a mudança **não pode** ser observável.

## 3. `-gd` — quais includes o projeto usa (a pergunta que o dump não responde bem)

```
$ harbour m.prg -sm -gd -Iinc
$ cat m.d
m.c: m.prg inc/far.ch          ← o caminho ONDE ACHOU, não o `far.ch` cru
```

- dá o **caminho resolvido** — a resolução é do **CORE**; quem consome não
  re-implementa a busca de include;
- dá o **fecho transitivo** (include de include entra);
- `-sm` = syntax check mínimo, sem codegen.

**Armadilha:** o `.d` vai para o **CWD**, não para o lado do fonte (ao contrário do
`.ppo`). Adivinhar o destino deixa lixo no projeto e devolve vazio para fonte em
subdiretório. Mande-o para onde você quer: **`-o<tmp>`**.

## 4. `__pp_init` / `__pp_process` — o pp VIVO (a fronteira)

Fonte: **`harbour-core/harbour/tests/hbpp/hbpptest.prg`**.

```harbour
pp := __pp_init()
__pp_process( pp, '#xtranslate AAA [A <a> [B <b>] ] => Qout([<a>][, <b>])' )
// ...e daí em diante cada LINHA alimentada volta TRANSFORMADA
```

É o pp do core **em processo**, alimentado linha a linha, com o conjunto de regras
que **você** registrar.

**Por que isso é grande:** derruba a premissa da recusa do § 1. O `.ppo` destrói
comentários porque é o canal de **arquivo** (`-p` despeja o módulo inteiro) — não
porque o pp destrói. Com `__pp_process` a ferramenta escolhe **o que** alimentar
(só a statement do site, cujas posições ela já tem do dump) e recebe **só aquilo**
transformado: o resto do arquivo **nunca passa pelo pp**, logo não pode ser
destruído.

"O pp calcula o QUE, a ferramenta escreve o ONDE" deixa de exigir o desenho
indireto `-u` + `.ppo` e vira uma **chamada direta ao motor do core**.

**Consumidores candidatos (fatia P11):**
1. **Migração de DSL** (portão D-P5): a regra de migração computa o texto novo, a
   ferramenta escreve por posição de byte, comentários preservados.
2. **Matar o resíduo do `AbbrevClash`** ([abbreviation.md](abbreviation.md)):
   *"o nome NOVO colidiria com outra cabeça sob abreviação?"* é predição de
   casamento FUTURO — em vez de replicar a aritmética do `ppcore.c:2533`,
   **pergunte ao pp**: registre as regras, alimente o nome novo, veja se casa.

---

## Lacunas (VERIFICADO)

- **[A explorar — P11]** A API `__pp_init`/`__pp_process` (+ `hb_compileFromBuf`,
  já fichada na [spec-b8](../spec-b8-macros.md)) não foi mapeada: falta provar
  equivalência com o pp do build e medir o que ela expõe (erros? posições? o estado
  de regras registradas?).
- **[Fato, não lacuna]** `.ppt` é **traço**, não grafo: prova que a informação
  existe no pp, mas é texto sem identidade estável de token entre passes. Quem
  precisa de estrutura usa o `from` (ast-3), não re-roteia o `.ppt`.
