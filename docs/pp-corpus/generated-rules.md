# Família REGRA QUE GERA REGRA — a diretiva que cria outra diretiva

Índice: [README.md](README.md). Ensina: uma diretiva pode **CRIAR outra diretiva**
em tempo de preprocessamento — é assim que o `hbclass` funciona por dentro — e o
pp põe **limites precisos** em quem pode fazer isso. Guarda: `corpus_gen`; fixture
`tests/ppc-gen/genx.prg`.

## A fixture (`tests/ppc-gen/genx.prg`) — compila limpo sob `-w3 -es2`

```harbour
#xcommand DEFREGRA <n> => #xcommand USA <n> => ? Marca( <"n"> )

PROCEDURE Main()
   DEFREGRA Ponto      // cria, em tempo de pp, a regra `USA Ponto`
   USA Ponto           // usa a regra que acabou de nascer
   RETURN
```

## O `.ppt` — a regra nasce e é usada, na mesma compilação

```
genx.prg(8) >DEFREGRA Ponto<
#xcommand >#xcommand USA Ponto => ? Marca( "Ponto" )<     <- a REGRA NOVA
genx.prg(9) >USA Ponto<
#xcommand >? Marca( "Ponto" )<                            <- e já é usada
genx.prg(9) >? Marca( "Ponto" )<
#command >QOut( Marca( "Ponto" ) )<                       <- multi-passe
```

Repare o encadeamento: `DEFREGRA` **emite uma diretiva**; o pp a **registra**; a
linha seguinte já casa a regra recém-nascida; e o resultado dela ainda passa pelo
`?` (`#command`). Três passes numa linha.

## ⚠️ Os LIMITES do pp (descobertos por FATO — e são restritivos)

Nem toda diretiva gerada entra em vigor. Provado rodando:

| forma | registra? |
|---|---|
| `#xcommand DEF <n> => #xcommand USA <n> => …` | **SIM** ✅ |
| `#xcommand DEF <n> => #xtranslate T_<n> => …` | **NÃO** ❌ — a regra sai como texto e o nome fica literal (`W0001`) |
| `#xcommand DEF <n> => #xcommand SHOW_<n> => …` (keyword **COLADA**) | **NÃO** ❌ — o comando não casa (`E0020`) |

Ou seja: **só `#[x]command` gerado registra**, e a keyword do comando gerado não
pode ser colada. É exatamente o que o hbclass usa (as regras `METHOD` por-método) —
e é a fronteira do que uma DSL sua pode gerar.

## O fato do dump — a GENEALOGIA (`ast-13`)

Quando uma regra nasce da expansão de outra, os tokens do `match[]`/`result[]` dela
carregam **`from`** — a ligação com a **aplicação que a criou**. Sem isso a
ferramenta não saberia que a regra `USA Ponto` "pertence" ao `DEFREGRA Ponto`.

## Explicação

**Para o programador Harbour.** Aquele `CLASS`/`METHOD` que você escreve funciona
assim: cada `METHOD Deposita` **gera, em tempo de pp, uma regra** que reconhece a
sua implementação `METHOD Deposita CLASS Conta` e a transforma na função real
`Conta_Deposita()`. A classe não é gramática do compilador — é uma diretiva que
escreve outras diretivas. E você pode fazer o mesmo na sua DSL: uma diretiva
"declaradora" que cria os comandos que o resto do seu código vai usar.

## Lente de refatoração

Graças à genealogia, renomear o nome no `DEFREGRA` **ou** no `USA` edita **os dois
sites juntos** e prevê a string derivada — a ferramenta sabe que a regra e o uso
têm o mesmo dono. Vale para o hbclass real e para qualquer DSL sua.

Provas: **caso 108** (fixture `fixgen`) + [spec-p § P1](../spec-p-pp-refatoracao.md).

## Lacunas (o que os oráculos NÃO mostram)

> Classificação por FATO (VERIFICADO rodando). Regra em [README.md](README.md).

- **[Recusa documentada — VERIFICADO] `#xtranslate` gerado não registra.** Não é
  lacuna da ferramenta nem do dump: é **limite do pp** (provado: o nome sai
  literal, `W0001`). Nada a consumir — a construção simplesmente não existe.
- **[Recusa documentada — VERIFICADO] Comando gerado com keyword COLADA não casa**
  (`E0020`). Idem: limite do pp, não do dump.
