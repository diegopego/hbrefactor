#include "mk.ch"
PROCEDURE Main()
   LOCAL n := 7
   M_REG n
   M_LST 1, 2, 3
   M_RST LIGA
   M_WLD qualquer coisa aqui
   M_EXT ( n )
   M_NAM Fulano
   R_STD Beltrano
   R_BLK n + 1
   R_LOG n
   R_NUL n 42
   RETURN
