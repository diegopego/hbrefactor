// B4f-3, módulo 2: DSL declarativa PURA com donos homônimos (Sol/Lua,
// ambas com Fulgor) - as donas existem SÓ no canal declared (nenhuma
// função geradora, nenhum registro por string).
#include "amuleto.ch"

AMULETO Sol FEITO_POR FazSol
DOTE Fulgor RENDE Sol
DOTE Zenite RENDE Sol

AMULETO Lua FEITO_POR FazLua
DOTE Fulgor RENDE Lua

PROCEDURE UsaAmuleto()

   LOCAL s := FazSol()
   LOCAL l := FazLua()

   s:Fulgor()
   s:Zenite()
   l:Fulgor()

   RETURN
