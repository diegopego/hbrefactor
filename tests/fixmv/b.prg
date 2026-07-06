// módulo 2 da fixture memvar (B4b): usos na extensão dinâmica, sombra
// LÉXICA, criação via macro e memvar implícita
MEMVAR xSaldo, xConta

PROCEDURE Deposita( nQuanto )

   xSaldo += nQuanto

   RETURN

PROCEDURE SomaConta( nQuanto )

   LOCAL nAux := nQuanto + 1

   xConta += nAux - 1

   RETURN

PROCEDURE ComLocalHomonimo()

   LOCAL xSaldo := -1

   ? "loc:", xSaldo

   RETURN

PROCEDURE ViaMacro()

   LOCAL cNome := "xOculta"

   PRIVATE &cNome
   M->xOculta := 9
   ? "mac:", M->xOculta

   RETURN

PROCEDURE Implicita()

   xTaxa := 3
   ? "imp:", xTaxa

   RETURN
