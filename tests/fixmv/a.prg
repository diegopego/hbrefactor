// módulo 1 da fixture memvar (B4b): PUBLIC + PRIVATE homônimos (sombra
// DINÂMICA) e um fluxo de fecho limpo (xConta) para o rename
MEMVAR xSaldo, xConta

PROCEDURE Main()

   PUBLIC xSaldo := 100

   ? "pub:", xSaldo
   Deposita( 50 )
   ? "pos:", xSaldo
   ComSombraPrivada()
   ? "fim:", xSaldo
   ComLocalHomonimo()
   ViaMacro()
   Implicita()
   Fluxo()

   RETURN

STATIC PROCEDURE ComSombraPrivada()

   PRIVATE xSaldo := 7

   ? "priv:", xSaldo
   Deposita( 1 )
   ? "priv2:", xSaldo

   RETURN

STATIC PROCEDURE Fluxo()

   PRIVATE xConta := 10

   SomaConta( 5 )
   ? "conta:", xConta

   RETURN
