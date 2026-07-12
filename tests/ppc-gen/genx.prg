// P-DOC corpus - familia REGRA QUE GERA REGRA. Uma diretiva pode CRIAR outra
// diretiva em tempo de pp - e o hbclass faz exatamente isso (cada METHOD gera a
// regra que reconhece a implementacao). Mas o pp poe LIMITES: so `#[x]command`
// gerado REGISTRA. Fixture nao-espelho (regua do caso 64).
#xcommand DEFREGRA <n> => #xcommand USA <n> => ? Marca( <"n"> )

PROCEDURE Main()
   DEFREGRA Ponto      // cria, em tempo de pp, a regra `USA Ponto`
   USA Ponto           // usa a regra que acabou de nascer
   RETURN

FUNCTION Marca( c )
   RETURN c
