// Fixture de generalidade da RD: o tipo do receptor de um bloco GERADO por
// diretiva vira FATO via _HB_INLINESELF, numa DSL INVENTADA (self.ch), nao
// no hbclass. O bloco de STOKE registra {|oIt _HB_INLINESELF Anvil|
// oIt:Ring() }: o param oIt nao tem token de fonte (gerado pela diretiva),
// mas o canal do core carrega a classe Anvil. A consulta Anvil:Ring deve
// dar confirmed no send oIt:Ring() DENTRO do bloco - so o _HB_INLINESELF o
// prova (sem ele, possible). oOutra:Ring (classe sem parentesco, homonimo)
// fica de fora.
#include "self.ch"

FORGE Anvil
BELLOW Ring
STOKE hit ROUSES Ring
ENDFORGE

EMBER Ring OF Anvil YIELDS 7

PROCEDURE UsaGiz()

   LOCAL oA AS CLASS Anvil

   oA := Anvil()
   oA:Ring()

   RETURN
