# Código da era smoke test (arquivado em 2026-07-05)

`hbrefactor-occ.prg` é a primeira encarnação da ferramenta (~2.700 linhas):
10 comandos sobre o dump de ocorrências `.occ.json` (`-x` do branch
`feature/refactoring-mechanism`), com tokenização e estrutura replicadas em
.prg (TokenScan, StructureCheck, ParseParenSpan, LineWords, StmtEdits).

Está aqui como **doador de código e referência de comportamento** para a
reescrita sobre a AST do compilador (branch `feature/compiler-ast-dump`,
schema `ast-1`) — ver `../docs/roadmap.md` (v3) e `../docs/arquitetura.md`.

O que dela é contrato e continua valendo (fora desta pasta):
- `../tests/` — fixtures e casos da suíte (o contrato de comportamento que a
  ferramenta nova precisa re-honrar, caso a caso);
- as políticas provadas: verificação editor ≠ verificador com rollback,
  strings nunca editadas automaticamente, recusas explícitas.

O que daqui tende a ser reaproveitado na reescrita: comparadores de HRB
(HrbParse/HrbEquivalent/HrbSymbolsEqual/HrbExtractCheck), IsValidIdent/
IsReserved, DefineCollision/PpHeadIn, a lógica de CLI/saída LSP. O que NÃO
deve voltar: TokenScan/LineWords/ParseParenSpan/StructureCheck/StmtEdits
(substituídos pelos fatos do `.ast.json`).
