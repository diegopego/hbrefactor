// Fixture de generalidade da RE.6/F6.3: a exclusão de send por FATO de
// parentesco vale para uma DSL INVENTADA (kin.ch), não só para o hbclass.
// Base tem Show; Kid herda Show de Base declarando o pai SÓ via _HB_SUPER
// (invisível à leitura por-forma); Rogue tem Show PRÓPRIO (homônimo sem
// parentesco). O veredito de Kid depende do canal _HB_SUPER:
//   - consulta Base:Show  -> oKid:Show() é uso REAL (herda), NÃO exclui
//   - consulta Rogue:Show -> oKid:Show() DESPACHA para Base:Show (pelo
//     _HB_SUPER) -> EXCLUÍDO; own-hit de Rogue -> confirmado
#include "kin.ch"

SPROUT Base
BUD Show
ENDSPROUT

LEAF Show OF Base YIELDS 1

SPROUT Kid OFFOF Base
ENDSPROUT

SPROUT Rogue
BUD Show
ENDSPROUT

LEAF Show OF Rogue YIELDS 2

PROCEDURE UsaKin()

   LOCAL oKid AS CLASS Kid
   LOCAL oRogue AS CLASS Rogue

   oKid := Kid()
   oRogue := Rogue()

   oKid:Show()
   oRogue:Show()

   RETURN
