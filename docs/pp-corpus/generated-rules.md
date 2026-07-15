<!-- guarda: corpus_gen -->
# Família REGRA QUE GERA REGRA — a diretiva que cria outra diretiva

Índice: [README.md](README.md). Ensina: uma diretiva pode **CRIAR outra diretiva**
em tempo de preprocessamento — é assim que o `hbclass` funciona por dentro — e o
pp põe **limites precisos** em quem pode fazer isso. Guarda: `corpus_gen`; fixture
`tests/ppc-gen/genx.prg`.

## A fixture — a prova é EXECUTÁVEL (METODO-V2)

Duas camadas, em dois arquivos:

- **`tests/ppc-gen/genx.prg`** (`hbtest` + pp vivo) —
  - camada A (o TEXTO, rule-gen no pp VIVO, em dois passos): `__pp_Process(pp,
    "DEFREGRA Ponto")` devolve **vazio** — ele emitiu uma *diretiva* (`#xcommand USA
    Ponto`), que o pp **registra** sem imprimir (mudança de estado, não texto); e o
    passo seguinte `__pp_Process(pp, "USA Ponto")` já casa a regra recém-nascida →
    `s_xUltimo := Marca( "Ponto" )`. É rule-generates-rule provado no pp vivo;
  - camada B (o VALOR): `DEFREGRA`/`USA` de escopo de arquivo rodam na compilação e
    `s_xUltimo` recebe `"Ponto"` (e `"Linha"` — o gerador faz uma regra nova por nome).
- **`tests/ppc-gen/genxdump.prg`** (raw-dumpável) — o `.ppt` (a regra nasce, é usada
  na linha seguinte, três passes) e a genealogia ast-13 (`from` → a app criadora).

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

- **[FALSA — derrubada em 2026-07-14] ~~`#xtranslate` gerado não registra~~.** É **falso**:
  um `#xtranslate` gerado **registra e casa** normalmente. Provado —
  `#xcommand DEF_C <n> => #xtranslate C <n>( \<v> ) => Marca( \<v> )` seguido de
  `? C Beta( 2 )` produz `QOut( Marca( 2 ) )`. *(A afirmação nasceu de um caso que falhava por
  OUTRO motivo — o de baixo — e foi generalizada sem teste. A fixture `ppc-gen` só exercitava
  `#xcommand`.)*
- **[VERDADEIRA, e agora com MECANISMO] Regra gerada com a cabeça COLADA não casa** — e o
  motivo é este: o laço do pp **desvia para o ramo de diretiva ANTES** de rodar a concatenação
  de keywords (`ppcore.c`, o `hb_pp_concatenateKeywords` fica **depois** do teste
  `ISDIRECTIVE`). Então a regra nasce com a cabeça em **DOIS tokens** (`B_` + `Beta`), enquanto
  o sítio de uso tem **um** (`B_Beta`) — e por isso não casa.
  **Prova executável do mecanismo:** com a regra gerada por `#xcommand DEF_B <n> => #xtranslate
  B_<n>( \<v> ) => Marca( \<v> )`, o uso `? B_Beta( 2 )` **não casa**, e o uso `? B_ Beta( 3 )`
  — com **espaço**, dois tokens — **casa**, produzindo `QOut( Marca( 3 ) )`.
  *(A mesma cabeça `B_Beta` escrita DIRETO numa regra casa sem problema: o defeito não é o nome
  colado, é a colagem **dentro de uma diretiva gerada**.)*
- **[Fato de uso] Marker dentro de regra gerada precisa de ESCAPE** (`\<v>`), senão a regra de
  FORA o consome — e o erro aparece já na definição (`E0008 Unknown result marker`). É o que a
  `xhb/cstruct.ch` faz em código real.
