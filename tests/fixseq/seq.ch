// DSL inventada NAO-espelho (P11): o SEQUESTRO REVERSO da cabeca.
//
// ROTULA tem 6 letras e NAO e usada em lugar nenhum do projeto. Como
// #command (familia SEM 'x') casa a cabeca abreviada a partir de 4 letras,
// renomear PAUTAR para um nome que COMECE com 4+ letras de ROTULA faz a
// regra renomeada passar a casar 'ROTU'/'ROTUL'/'ROTULA' - grafias que hoje
// pertencem a ROTULA. Como ROTULA nao tem NENHUM site, o .ppo/.hrb sai
// byte-identico e a rede de verificacao nao ve nada: a ambiguidade fica
// LATENTE e so quebra no proximo site que alguem escrever.
#command ROTULA <t> => qq_( <t>, 0 )

#command PAUTAR <x> => qq_( <x>, 1 )
