<!-- guarda: corpus_deriv -->
# Família DERIVAÇÃO — `clone` × `paste` × `stringify` (o que a diretiva FAZ com o nome)

Índice: [README.md](README.md). Ensina: **o que um nome SIGNIFICA depende do que a
diretiva faz com ele.** O mesmo `<n>` pode atravessar intacto (o nome continua
sendo o que era) ou virar CÓDIGO NOVO (um símbolo colado dele, uma string com ele).
O pp distingue os dois **por fato**, e essa distinção já explicou **três** achados
independentes. Canais: `ast-3` (`from`), `ast-12` (`generates`), `ast-13`
(genealogia). ADR: [../adr-003](../adr-003-derivacao-pp-como-fato.md).

---

## As três operações

Cada pedaço de token sintetizado carrega a operação que o gerou:

| op | sintaxe na regra | o que faz com o nome | o nome continua sendo um nome? |
|---|---|---|---|
| **`clone`** | `<n>` | o valor **atravessa** como está | **SIM** — pass-through |
| **`paste`** | `pre_<n>` | concatena num **novo identificador** | NÃO — virou outro símbolo |
| **`stringify`** | `<"n">` | despeja numa **string** | NÃO — virou texto |

```harbour
#xcommand REGISTRO <n> => FUNCTION reg_<n>() ;; LOCAL <n> := <"n"> ;; RETURN Anota( <n> )
//                                     paste          clone   stringify        clone
```

`generates: true` (ast-12) marca o recheio de marker cujo nome escrito alimenta um
**paste ou stringify** — ou seja, "este nome VIRA código". Ausente = `clone`.

---

## Por que isso é a chave (e não uma curiosidade)

### Achado 1 — resolver o KIND de um rename (fase U / P1)

Duas leituras opostas do MESMO site davam ambas errado:

- *papel-de-pp primeiro*: `? nTotal` — o `?` **é** `#command`, então `nTotal` é
  recheio de marker → "é um marker". **Errado**: `nTotal` é o seu LOCAL.
- *binding primeiro*: `REGISTRO Salva` — a expansão fabrica um `LOCAL Salva`, então
  "é um local" → renomeia 1 site e perde os artefatos. **Errado**: `Salva` é o
  marker que GERA.

Nenhuma **ordem** entre os dois acerta. O que acerta é o TERCEIRO fato: `Salva`
**gera** (paste), `nTotal` **não gera** (clone).

### Achado 2 — `usages --at` (P3)

O mesmo fato estreita o find-references: cursor num marker que gera → só a rede de
derivação dele; cursor num símbolo real → exclui markers homônimos sem relação.
Antes, `LABEL Vendas` (stringify) e `FUNCTION Vendas()` (função real) devolviam o
**mesmo blob** — coincidência de texto tratada como identidade.

### Achado 3 — a guarda de órfão estava CEGA (P6)

O caso mais instrutivo, porque o erro foi **meu** e do mesmo formato:

```harbour
VULK Escudo          // gera FUNCTION vk_Escudo()
? vk_Escudo()        // o fonte soletra o nome GERADO, à mão
```

A guarda que impede renomear o gerador (deixando `? vk_Escudo()` órfão) testava
*"grafia manual = token **sem** `from`"*. Mas **`?` também é `#command`** e CLONA o
argumento — então `vk_Escudo` chega ao stream **COM** `from`, e a guarda não o via.
Sintoma: `--dry-run` **aprovava** e o apply desfazia tarde ("contagem de símbolos
mudou").

**O fato que separa já existia:** `clone` = a grafia é do USUÁRIO (orfanável);
`paste`/`stringify` = o texto foi **FABRICADO** (é o artefato que o rename
re-deriva). Não é "tem `from` ou não" — é **qual operação**.

> **Lição transversal:** três bugs diferentes, uma causa só — tratar "passou por uma
> diretiva" como se fosse "virou outra coisa". Em Harbour **quase tudo** passa por
> diretiva (`?`, `SET`, `@…SAY`, a classe inteira). Passar por uma diretiva é o
> caso NORMAL, não o excepcional.

---

## Genealogia de regra (`ast-13`) — o fato irmão

Quando o valor de um marker vira **token de uma regra GERADA**, a derivação entra no
REGISTRO da regra, **não no stream** — então `generates` não a vê. É o caso do
`DEFREGRA <n> => #xcommand USA <n> => ...`. O `from` nos tokens de `match[]`/`result[]`
de uma regra gerada liga a regra à aplicação que a criou. Detalhes e limites:
[generated-rules.md](generated-rules.md).

Por isso a resolução do rename testa **`generates` OU `genrule`**.

---

## Lacunas (VERIFICADO)

- **[Consumo futuro]** `generates` funde `paste` e `stringify` num booleano. A
  granularidade fina (QUAL artefato, QUE faixa de bytes) **já está** no `from`
  (`op`/`at`/`len`) — quem precisa dela usa o rastro, não o resumo. Veredito P1: o
  booleano basta para o KIND; um `genOp` separado foi **recusado** por falta de
  consumidor.
- **[Consumo futuro]** Artefatos derivados como `Location` estruturada no `--json`
  do `usages` (hoje só texto colado sob `--show-expansion`). O fato existe no `from`;
  falta o consumo. Registrado como resíduo do P3.
