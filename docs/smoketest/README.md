# Era smoke test (arquivado em 2026-07-05)

Os documentos desta pasta descrevem a **primeira encarnação** do hbrefactor
(Fases 0-5 do roadmap v2): a ferramenta sobre o dump de ocorrências `-x`
(`.occ.json`, schema 2) do branch `feature/refactoring-mechanism`, com
tokenização/estrutura replicadas em `.prg` (TokenScan, StructureCheck etc.).

Esse ciclo foi um **smoke test bem-sucedido e superado**: provou o compilador
como oráculo, a verificação byte-idêntica com rollback e o hbmk2 como
resolvedor — e revelou que a camada sintática replicada era o elo frágil.
Por ordem do Diego, o projeto foi refundado sobre uma **AST emitida pelo
compilador** (branch `feature/compiler-ast-dump`, novo a partir do master).

Nada aqui descreve o projeto atual — consulte `../roadmap.md` (v3) e
`../arquitetura.md`. Estes arquivos ficam como registro histórico e fonte de
lições (casos de dogfooding, decisões e critérios da época):

- `arquitetura.md` — arquitetura da era occ (superada pela AST)
- `dump-schema.md` — schema 2 do `.occ.json` (superado pelo `ast-1`,
  ver `../ast-schema.md`)
- `dogfooding.md` — relatório das rodadas de dogfooding do smoke test
- `roadmap-v2-arquivado.md` — roadmap v2 completo com o histórico das fases
- `comandos.md` — catálogo de comandos com os status da era 1 (o catálogo
  vivo agora é a fase B2 do `../roadmap.md`)
- `inventario-ecossistema.md` — Tarefa 1: levantamento empírico do
  ecossistema que fundamentou tudo (fatos ainda válidos; conclusões de
  desenho superadas pela era AST)
