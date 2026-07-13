#include "app.ch"

PROCEDURE Main()

   REGISTRAR Caldeira AS Temperatura
   REGISTRAR Bomba    AS Pressao

   RETURN

FUNCTION AddSensor( cNome, cTipo )

   RETURN cNome + "/" + cTipo
