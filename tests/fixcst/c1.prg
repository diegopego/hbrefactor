// B4f-3 fatia 3: DSL REAL do contrib (xhb/cstruct.ch, apontada pelo
// Diego) - classes criadas em RUNTIME (hb_CStructure/__clsNew) com
// membros homônimos entre estruturas. Os .ch vêm da árvore do harbour em
// tempo de teste (freshcst). Fronteira honesta: tudo possible, nunca
// excluded/confirmed falso.
#include "cstruct.ch"

C STRUCTURE Ponto
   MEMBER x IS CTYPE_INT
   MEMBER y IS CTYPE_INT
END C STRUCTURE

C STRUCTURE Tela
   MEMBER x IS CTYPE_INT
   MEMBER altura IS CTYPE_INT
END C STRUCTURE

PROCEDURE UsaCst()

   LOCAL p IS Ponto
   LOCAL t IS Tela

   p:x := 1
   t:x := 2
   ? p:x, t:x, t:altura

   RETURN
