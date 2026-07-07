// B4f-3, módulo 1: homônimos ENTRE donos de DSL (Totem/Idolo, ambos com
// Brilho) e CRUZADOS com classe hbclass (Farol:Brilho) - o find-references
// de qualquer um dos três donos não pode listar os sites dos outros.
#include "hbclass.ch"
#include "rig.ch"

CREATE CLASS Farol
   METHOD New() CONSTRUCTOR
   METHOD Brilho()
ENDCLASS

METHOD New() CLASS Farol
   RETURN Self

METHOD Brilho() CLASS Farol
   RETURN 1

RIG Totem
COG Brilho GIVES Totem
COG Rodar GIVES Totem
ENDRIG

FORGE Brilho OF Totem RETORNA 2
FORGE Rodar OF Totem RETORNA 3

RIG Idolo
COG Brilho GIVES Idolo
ENDRIG

FORGE Brilho OF Idolo RETORNA 4

PROCEDURE UsaRig()

   LOCAL oF := Farol():New()
   LOCAL oT := Totem()
   LOCAL oI := Idolo()

   oF:Brilho()
   oT:Brilho()
   oT:Rodar()
   oI:Brilho()

   RETURN
