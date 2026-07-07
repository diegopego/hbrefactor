// B4f-3, módulo 3 (alinhamento do Diego): comandos novos embrulhando
// classes EXISTENTES com métodos homônimos (Grade/Lousa, ambas com
// Pintar). MYBROWSE cria a instância na expansão; MYPAINT contém o send
// na expansão (o fonte escrito não tem "Pintar"); MYTELA embrulha classe
// de fora do projeto (honesto: possible).
#include "hbclass.ch"
#include "browse.ch"

CREATE CLASS Grade
   VAR nT INIT 0
   METHOD New( n ) CONSTRUCTOR
   METHOD Pintar()
ENDCLASS

METHOD New( n ) CLASS Grade
   ::nT := n
   RETURN Self

METHOD Pintar() CLASS Grade
   RETURN 1

CREATE CLASS Lousa
   VAR nT INIT 0
   METHOD New( n ) CONSTRUCTOR
   METHOD Pintar()
ENDCLASS

METHOD New( n ) CLASS Lousa
   ::nT := n
   RETURN Self

METHOD Pintar() CLASS Lousa
   RETURN 2

PROCEDURE UsaB()

   LOCAL g, l, t

   MYBROWSE g AT 1
   MYLOUSA l AT 2
   MYTELA t AT 3

   MYPAINT g
   MYPAINT l
   MYPAINT t

   g:Pintar()
   l:Pintar()

   RETURN
