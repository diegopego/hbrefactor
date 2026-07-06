# hbrefactor

Refatoração automatizada para Harbour sobre a AST do compilador
(dump `.ast.json` do branch feature/compiler-ast-dump). Fontes de verdade:
docs/roadmap.md, docs/ast-schema.md e o Makefile — LER antes de codar.

## Regras de trabalho

- **Compile todo .prg (fixture, exemplo, teste) ANTES de usá-lo em
  qualquer teste** — `$HB_BIN/harbour arquivo.prg -n -q0` ou o projeto
  via hbmk2. Fixture que não compila gera diagnóstico enganoso.
- Fluxos definidos vivem no Makefile; hbmk2 direto é só experimentação.
- **Exportar `HB_BIN` ao invocar a ferramenta fora do Makefile**: sem ele o
  `HbMk2Bin()` cai no hbmk2 do SISTEMA (`/usr/local/bin`, sem `-x`) e o
  sintoma é o enganoso "o projeto não compila" (custou um diagnóstico na
  P2a; a suíte exporta, invocação manual esquece).
- Nenhuma réplica de gramática na ferramenta: fatos vêm do compilador
  (dump ast, hb_compileFromBuf, harbour.hbx).
- Reutilizar o **hbmk2** (builder oficial) para projeto/flags/build: entende
  `.hbp`/`.hbc`, resolve `-I`/`-D` (`hbmk2 -trace` expõe a linha do harbour),
  repassa `-prgflag=`. Todo parsing paralelo é cópia degradada que diverge —
  reescrever só o estritamente necessário.
- Contrato executável: `make test` (deve permanecer verde).
- **roadmap.md é minha responsabilidade e vive preenchido**: fases futuras com
  escopo + critério de pronto ANTES de executá-las; concluída uma fase,
  atualizar o status na mesma sessão; trabalho novo entra como fase/item.
  Decisões de produto e autorizações continuam com o Diego.
- **Genérico > específico**: comando dedicado só com razão forte (o
  `usages-dsl` foi absorvido pelo `usages`); ao consumir fatos de pp, operar
  sobre o genérico (cabeça/kind/marker), nunca por DSL/família conhecida.
- **Nunca editar o não-verificável**: a ferramenta só aplica o que o oráculo
  prova e a recompilação verifica; conteúdo sem verificação (strings, dados,
  comentários) recebe detecção e relato preciso, jamais edição automática (nem
  com opt-in) — editar string por coincidência de nome é "ajeito".
- **Extensão VSCode sempre com os últimos recursos**: todo comando/capacidade
  nova do CLI tem que chegar à `extension.js` — expô-la é escopo da fase que a
  entrega, não fase adiável (é o consumidor de uso diário do Diego).
- smoketest/hbrefactor-occ.prg é a primeira encarnação, arquivada:
  só leitura, nunca editar.
- Commits só com autorização explícita do Diego **para AQUELE commit**;
  concluir/aprovar o trabalho não autoriza o commit. Um pedido por commit —
  não encadear. Sem push salvo pedido.
- Em sessão com o modelo Fable: delegar a subagentes **opus** para
  economizar tokens do Fable quando realmente compensar (trabalho
  mecânico bem especificado — varreduras, builds, baterias de teste);
  raciocínio central e código delicado ficam no Fable, que revisa o
  que os agentes entregam.
- Regra/preferência durável deste repo vai AQUI (versionado), não na memória
  privada do Claude (que não viaja com o repo); a memória fica para o que não
  pertence a um repo.

## Harbour (linguagem) — armadilhas ao escrever fixtures/.prg

Os fixtures da suíte são `.prg` idiomático (o "caso 0" exige saída limpa sob
`-w3 -es2`). Armadilhas que já morderam:

- **Não nomear variável formando keyword em uppercase**: Harbour é
  case-insensitive e lê identificadores em uppercase — `LOCAL nIL` vira a
  reservada `NIL` (`E0030 syntax error`). Evitar `nIL`, `cFor`, etc.
- **MEMVAR antes de PRIVATE/PUBLIC**: referenciar `PRIVATE`/`PUBLIC` sem uma
  declaração `MEMVAR` compile-time gera W0002 na criação e W0001 em cada uso —
  com `-es2` o build falha. Idioma: `MEMVAR xCfg` / `PRIVATE xCfg := 7`.
- **Comentário de linha `//` em .prg** (não `/* */`): um `*/` que apareça no
  conteúdo (ex.: `assert_*/`) fecha o bloco antes da hora e o resto vira
  código. Aplicar em código novo/editado, sem conversão em massa.
- **Verificar comportamento no fonte do Harbour ANTES de afirmar** (não
  teorizar): ler/grep o `src/` relevante. `Empty(" ")` é `.T.` — usar
  `Len(c) == 0` para "vazia".
