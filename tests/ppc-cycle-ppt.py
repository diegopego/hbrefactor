#!/usr/bin/env python3
"""Guarda da familia CICLO: o .ppt prova que o pp ESGOTA o comando antes de avancar.

O traco tem pares "arquivo(linha) >entrada<" / "#tipo >saida<". Se o pp esgota a
linha, os quatro passes da cadeia (E1>E2>E3>E4>cy_Marca) aparecem TODOS com o numero
da linha do `E1` -- e nenhuma outra linha aparece no meio deles.

uso: ppc-cycle-ppt.py <cyc.ppt> <cyc.prg>
"""
import re
import sys

ppt = open(sys.argv[1]).read().split("\n")
src = open(sys.argv[2]).read().split("\n")

lin_e1 = [i + 1 for i, l in enumerate(src) if l.strip() == "E1"][0]

entradas = [(int(m.group(1)), m.group(2))
            for l in ppt
            for m in [re.match(r"cyc\.prg\((\d+)\) >(.*)<", l)] if m]

# os passes do comando E1: linhas consecutivas do traco, TODAS na linha do E1
bloco = []
for lin, txt in entradas:
    if lin == lin_e1:
        bloco.append(txt)
    elif bloco:
        break            # o pp avancou de linha: o bloco do E1 acabou

falhas = []
if bloco != ["E1", "E2", "E3", "E4"]:
    falhas.append("esperava os 4 passes na linha %d do fonte, veio: %s" % (lin_e1, bloco))

for f in falhas:
    print("  ", f)
sys.exit(1 if falhas else 0)
