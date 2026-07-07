// Q4 m2: os sends. t:Pintar() e f:Pintar() NUNCA despacham para
// LOUSA:PINTAR (Lousa nao e pai de ninguem) - em runtime seriam erro.
PROCEDURE UsaArmas()

   LOCAL t := Totem()
   LOCAL f := Faca()
   LOCAL l := Lousa()

   l:Pintar()
   t:Pintar()
   t:Rodar()
   f:Pintar()

   RETURN
