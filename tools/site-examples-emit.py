#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Emite o bloco HTML de UM exemplo da pagina, a partir da rodada REAL.

Layout: codigo ANTES a esquerda, codigo DEPOIS a direita, e o comando/saida
embaixo. Sem marcacao de diff - o codigo aparece como ele e.

O `show` pode listar MAIS DE UM arquivo (um por linha): uma refatoracao que
atravessa a fronteira de arquivo (o .ch onde a regra nasce e o .prg onde ela
morre) so e honesta se a pagina mostrar os dois. Cada arquivo vira o seu proprio
par antes/depois; um arquivo que a rodada nao mexeu aparece uma vez so.

Nada aqui e digitado: o antes e o fonte da fixture, o depois e o fonte DEPOIS
da ferramenta rodar, e o meio e a saida REAL do comando.
"""
import sys, html

name, cmd, fout, expect, kind, workdir, snapdir = sys.argv[1:8]
shows = sys.argv[8:]

out = open(fout, encoding='utf-8').read().rstrip('\n').split('\n')


def read(path):
    return open(path, encoding='utf-8').read().rstrip('\n')


def numbered(src):
    """cada linha vira um <span class="l">; o NUMERO sai de um contador CSS,
    entao ele nao entra no copy/paste (como num editor de verdade)"""
    o = []
    for l in src.split('\n'):
        o.append(f'<span class="l">{html.escape(l) or " "}</span>')
    return '\n'.join(o)


def outblock(lines):
    o = []
    for l in lines:
        e = html.escape(l)
        low = l.lower()
        if low.startswith('verified:'):
            e = f'<span class="ok">{e}</span>'
        elif low.startswith('warning:'):
            e = f'<span class="warn">{e}</span>'
        elif low.startswith('hbrefactor:'):
            e = f'<span class="bad">{e}</span>'
        o.append(e)
    return '\n'.join(o)


def card(title, src):
    print(f'    <div class="code-card ex-code"><div class="code-top">{html.escape(title)}</div>')
    print(f'<pre class="num"><code>{numbered(src)}</code></pre></div>')


def term():
    print('  <div class="code term ex-run"><button class="copy" type="button">Copy</button>')
    print(f'<pre><code><span class="cmd">$ hbrefactor</span> {html.escape(cmd)}\n{outblock(out)}</code></pre></div>')


print(f'<!-- SITE-EX:{name}:BEGIN (GERADO por make site-examples - NAO editar a mao) -->')
print('<div class="ex">')

any_changed = False
for show in shows:
    before = read(f'{snapdir}/{show.replace("/", "_")}')
    after = read(f'{workdir}/{show}')
    if before != after:
        any_changed = True
        print('  <div class="exdiff">')
        card(f'before — {show}', before)
        card(f'after — {show}', after)
        print('  </div>')
    else:
        label = 'the code' if kind == 'report' else 'the code — unchanged'
        card(f'{label} — {show}', before)

term()

if not any_changed:
    if kind == 'report':
        print('  <p class="ex-note muted">This command only <strong>reads</strong>. It never edits — and the suite '
              'fails the build if a single byte of the source moves.</p>')
    else:
        print('  <p class="ex-note muted">It refused — and the source is <strong>byte-for-byte unchanged</strong>. '
              'This suite fails the build if a refusal ever edits a single character.</p>')

print('</div>')
print(f'<!-- SITE-EX:{name}:END -->')
