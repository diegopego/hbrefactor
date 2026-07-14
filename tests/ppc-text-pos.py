#!/usr/bin/env python3
"""Guarda da familia TEXT/ENDTEXT -- os fatos que so' o DUMP tem.

  (a) ast-17: a STRING que o bloco produziu carrega a linha do fonte de onde saiu,
      e prov 's' (antes do ast-17: line 0, col null, prov 'n' -- sem origem).
  (b) o bloco NAO passa pela maquinaria de regras: a aplicacao da regra TEXT consumiu
      um token so' (a palavra TEXT). As linhas do bloco nao sao recheio de marker.
  (c) o compilador nao ve variavel nenhuma na linha do bloco: as ocorrencias do local
      sao so' a declaracao e a leitura do fim.

As linhas se COMPUTAM do fonte -- nunca se contam na mao.
"""
import json
import sys

d = json.load(open(sys.argv[1]))
src = open(sys.argv[2]).read().split("\n")

lin_txt = [i + 1 for i, l in enumerate(src) if l.strip() == "cSaldo apurado no periodo"][0]

falhas = []

# escolhe pela POSICAO, nunca pelo texto: o mesmo texto aparece tambem como valor
# esperado de um HBTEST mais abaixo -- filtrar por conteudo pegaria os dois
s = [t for t in d["tokens"]
     if t.get("type") == 41 and t.get("line") == lin_txt and t.get("col") == 0]
if len(s) != 1 or s[0].get("prov") != "s" or "cSaldo apurado" not in str(s[0].get("text")):
    falhas.append("(a) a string do bloco deveria vir de line %d, col 0, prov 's': %s" % (lin_txt, s))

app = [a for a in d["ppApplications"]
       if (d["ppRules"][a["rule"]].get("head") or "") == "TEXT"]
if len(app) != 1 or len(app[0]["tokens"]) != 1:
    falhas.append("(b) a aplicacao do TEXT deveria consumir UM token so': %s" % app)

occ = [o["line"] for f in d["functions"] if f["name"] == "MAIN"
       for o in f["occurrences"] if o["sym"] == "CSALDO"]
if lin_txt in occ:
    falhas.append("(c) o compilador NAO deveria ver o local na linha do bloco: %s" % occ)

for f in falhas:
    print("  ", f)
sys.exit(1 if falhas else 0)
