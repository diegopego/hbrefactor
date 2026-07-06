# hbrefactor

Refatoração automatizada para Harbour sobre a AST do compilador
(dump `.ast.json` do branch feature/compiler-ast-dump). Fontes de verdade:
docs/roadmap.md, docs/ast-schema.md e o Makefile — LER antes de codar.

## Regras de trabalho

- **Compile todo .prg (fixture, exemplo, teste) ANTES de usá-lo em
  qualquer teste** — `$HB_BIN/harbour arquivo.prg -n -q0` ou o projeto
  via hbmk2. Fixture que não compila gera diagnóstico enganoso.
- Fluxos definidos vivem no Makefile; hbmk2 direto é só experimentação.
- Nenhuma réplica de gramática na ferramenta: fatos vêm do compilador
  (dump ast, hb_compileFromBuf, harbour.hbx).
- Contrato executável: `make test` (deve permanecer verde).
- smoketest/hbrefactor-occ.prg é a primeira encarnação, arquivada:
  só leitura, nunca editar.
- Commits só com autorização explícita do Diego.
- Em sessão com o modelo Fable: delegar a subagentes **opus** para
  economizar tokens do Fable quando realmente compensar (trabalho
  mecânico bem especificado — varreduras, builds, baterias de teste);
  raciocínio central e código delicado ficam no Fable, que revisa o
  que os agentes entregam.
