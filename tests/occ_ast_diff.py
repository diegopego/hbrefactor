#!/usr/bin/env python3
# Comparador occ<->ast da Fase B1 (roadmap v3): os fatos semânticos do dump
# antigo (.occ.json, schema 2, binário do branch feature/refactoring-mechanism)
# devem existir TODOS no dump novo (.ast.json, schema ast-1) - occ ⊆ ast.
# Extras do ast são classificados (ex.: write do inicializador de declaração,
# que o occ não enxergava - melhoria conhecida).
#
# Uso: occ_ast_diff.py <arquivo.occ.json> <arquivo.ast.json>
import json
import sys


def key_fn(f):
    return (f["name"], f["fileDecl"])


def occ_set(fn):
    out = set()
    for o in fn.get("occurrences", []):
        out.add(("occ", o["sym"], o["line"], o["access"], o["scope"], o["block"]))
    for c in fn.get("calls", []):
        out.add(("call", c["sym"], c["line"], c["block"]))
    for s in fn.get("sends", []):
        out.add(("send", s["sym"], s["line"], s["block"]))
    for d in fn.get("declarations", []):
        out.add(("decl", d["sym"], d["declLine"], d["scope"], d["param"]))
    return out


def main():
    occ = json.load(open(sys.argv[1]))
    ast = json.load(open(sys.argv[2]))
    missing = 0
    extra_known = 0
    extra_odd = []

    afuncs = {key_fn(f): f for f in ast["functions"]}
    for of in occ["functions"]:
        af = afuncs.get(key_fn(of))
        if af is None:
            print("FALTA função no ast:", of["name"])
            missing += 1
            continue
        for fld in ("kind", "static", "line", "usesMacro"):
            if of[fld] != af[fld]:
                print("CAMPO difere em %s.%s: occ=%r ast=%r" %
                      (of["name"], fld, of[fld], af[fld]))
                missing += 1
        oset, aset = occ_set(of), occ_set(af)
        for item in sorted(oset - aset):
            print("FALTA no ast:", of["name"], item)
            missing += 1
        decl_lines = {d["declLine"] for d in of.get("declarations", [])}
        rtvar_lines = {o["line"] for o in of.get("occurrences", [])
                       if o["scope"] == "memvar"}
        for item in sorted(aset - oset):
            # write no inicializador da declaração: melhoria do ast
            # (o occ marcava a linha só como declaração)
            if item[0] == "occ" and item[3] in ("write", "use") and \
               (item[2] in decl_lines or item[2] in rtvar_lines):
                extra_known += 1
            else:
                extra_odd.append((of["name"], item))

    for name, item in extra_odd:
        print("EXTRA não classificado no ast:", name, item)

    print("occ<->ast: %d faltando, %d extras conhecidos (init-write), %d extras não classificados"
          % (missing, extra_known, len(extra_odd)))
    sys.exit(0 if missing == 0 and not extra_odd else 1)


if __name__ == "__main__":
    main()
