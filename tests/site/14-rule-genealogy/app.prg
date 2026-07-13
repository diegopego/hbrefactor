#include "app.ch"

PROCEDURE Main()

   DEFREGRA Ponto   // creates, at preprocess time, the rule `USA Ponto`
   USA Ponto        // uses the rule that was just created

   RETURN

FUNCTION Marca( cNome )

   RETURN cNome
