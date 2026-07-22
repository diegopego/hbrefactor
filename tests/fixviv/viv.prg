// fixviv (P16 c) - a STRING que e' MACRO VIVO: uma string que contem
// '&nome' e' reavaliada em runtime e vale o VALOR do memvar que nomeia
// (prova executavel: tests/ppc-strfam/sf.prg, camada B). Renomear o memvar
// muda o comportamento de toda string que o mencione - a ferramenta diz
// ISSO e o PORQUE, e jamais edita a string. Compila limpo sob -w3 -es2.

MEMVAR xCfg

PROCEDURE Main()

   PRIVATE xCfg := "tema"

   ? Mostra()
   ? "modelo: &xCfg aplicado"
   ? "prefixo: &xCfgLote nao e' o alvo"

   RETURN
