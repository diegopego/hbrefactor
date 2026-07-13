PROCEDURE Main()

   Registra( "erro", "disco cheio" )
   Registra( "aviso", "memoria baixa" )

   RETURN

FUNCTION Registra( cNivel, cTexto )

   RETURN cNivel + ": " + cTexto
