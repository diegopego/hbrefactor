MEMVAR cLayout

PROCEDURE Main()

   PRIVATE cLayout := "compacto"

   Imprime( "modelo &cLayout do relatorio" )
   Imprime( "arquivo &cLayoutBase nao e' o mesmo nome" )

   RETURN

STATIC PROCEDURE Imprime( cTexto )

   ? cTexto

   RETURN
