// P-DOC corpus - familia SET (std.ch). std.ch e AUTO-incluida pelo
// compilador; NAO incluir explicito (duplicaria os #define -> W0002/-es2).
// `SET EXACT` mostra dois mecanismos do pp de uma vez: marker RESTRICT no
// match (<x:ON,OFF,&>) e result SMART-STRINGIFY (<(x)>).
PROCEDURE Main()
   LOCAL lFlag := .T.
   SET EXACT ON
   SET EXACT OFF
   SET EXACT (lFlag)
   RETURN
