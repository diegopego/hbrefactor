#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Injeta (ou CONFERE) os blocos gerados entre os marcadores do index.html.

O marcador vazio na pagina e:
    <!-- SITE-EX:<nome> -->
Depois de gerado ele vira o par BEGIN/END. Reinjecoes substituem o par
inteiro, entao o alvo e sempre reencontravel.
"""
import sys, re, os, pathlib

page_path, fragdir, check = sys.argv[1], sys.argv[2], sys.argv[3] == '1'
page = open(page_path, encoding='utf-8').read()
orig = page

for frag in sorted(pathlib.Path(fragdir).glob('*.html')):
    name = frag.stem
    body = frag.read_text(encoding='utf-8').rstrip('\n')
    pat_done = re.compile(
        r'<!-- SITE-EX:' + re.escape(name) + r':BEGIN.*?<!-- SITE-EX:' + re.escape(name) + r':END -->',
        re.S)
    pat_slot = re.compile(r'[ \t]*<!-- SITE-EX:' + re.escape(name) + r' -->')
    if pat_done.search(page):
        page = pat_done.sub(lambda m: body, page, count=1)
    elif pat_slot.search(page):
        page = pat_slot.sub(lambda m: body, page, count=1)
    else:
        print(f'site-examples: marcador ausente na pagina: <!-- SITE-EX:{name} -->')
        sys.exit(1)

if check:
    if page != orig:
        print('site-examples: exemplos da pagina DEFASADOS - rode `make site-examples`')
        sys.exit(1)
    print('exemplos da pagina em dia (cada um rodou e foi provado)')
else:
    open(page_path, 'w', encoding='utf-8').write(page)
    n = len(list(pathlib.Path(fragdir).glob('*.html')))
    print(f'exemplos da pagina regenerados por EXECUCAO: {n}')
