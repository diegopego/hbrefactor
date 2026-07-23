// terceiro modulo do fixdado (P16 a) - o MESMO dado, porem RE-ESCANEADO por
// regra. Existe para cobrir o caminho FUNDO do selo, que o dado.prg nao toca.
//
// O que os oraculos mostram (.ppt deste modulo, tres linhas em sequencia):
//    #command    >text QOut, QQOut<     o TEXT poe o pp em modo de STREAM
//    eco.prg(19) >QOut( "Farol" )<      o pp FABRICA a chamada da linha crua
//    #xtranslate >Eco( "Farol" )<       a regra abaixo casa e CLONA a string
// O pp nao termina quando emite: o que ele emite VOLTA para a fila de regras.
//
// Consequencia no dump: o token que chega ao parser carrega SO' `op:"clone"`;
// o selo `op:"stream"` fica UM SALTO ATRAS, no token que a aplicacao consumiu
// (0 ocorrencias do selo em tokens[], 1 em ppApplications[]). Sem a recursao
// que segue o clone ate' a origem selada, esta linha volta a ser relatada como
// "possible reference in string" - o falso positivo que a P16(a) existe para
// matar. Compila limpo sob -w3 -es2.

#xtranslate QOut( <x> ) => Eco( <x> )

STATIC s_aEco := {}

PROCEDURE Trilha()

   TEXT
Farol
   ENDTEXT

   RETURN

STATIC FUNCTION Eco( cLinha )

   AAdd( s_aEco, cLinha )

   RETURN NIL
