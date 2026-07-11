// P-DOC corpus - familia @ ... SAY (std.ch): multi-marker + grupos OPCIONAIS
// no match ([PICTURE], [COLOR]) E no result ([, <clr>]); duas formas
// (DevOut vs DevOutPict) que o pp seleciona pelo que casou.
PROCEDURE Main()
   LOCAL nX := 42, cName := "Ana"
   @ 1, 1 SAY "Ola"
   @ 2, 1 SAY nX PICTURE "999"
   @ 3, 1 SAY nX PICTURE "999" COLOR "R/W"
   @ 4, 1 SAY cName COLOR "W/B"
   RETURN
