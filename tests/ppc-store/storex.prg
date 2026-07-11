// P-DOC corpus - familia STORE (std.ch): o grupo opcional [,<vN>] REPETE -
// STORE <v> TO a, b, c casa o grupo uma vez por variavel extra e o result
// [ <vN> :=] emite um ":=" por repeticao (a multi-atribuicao classica).
PROCEDURE Main()
   LOCAL a, b, c
   STORE 0 TO a
   ? a
   STORE 9 TO a, b, c
   ? a, b, c
   RETURN
