#!/usr/bin/env python3
"""unit-brief.py <N> — o BRIEF de uma iteração da migração de teste.

Por que existe: migrar um `unit_N` exige três fatos espalhados — o corpo do
teste (num run.sh de milhares de linhas), a fixture que ele usa (num helper
`fresh*` lá no topo) e a COLUNA de cada alvo (que a lei manda COMPUTAR do
arquivo, nunca contar na cabeça). Caçá-los custa várias buscas por unit, ~127
vezes. Aqui sai tudo numa tela.

O que ele NÃO faz, e é a linha vermelha: **não escreve `expected/` nem
`outputs/`**. Ferramenta que grave esperado é proibida no repo — uma foi escrita
e deletada no mesmo dia (cicatrizes §6.4). Aqui só sai fato da ENTRADA: o que o
teste antigo roda e o que ele afirma hoje. O esperado é você que escreve, do
contrato (tests/README.md §2).

Uso:  tools/unit-brief.py 42
      tools/unit-brief.py 42 --raw     também despeja o corpo original
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(subprocess.run(["git", "rev-parse", "--show-toplevel"],
                           capture_output=True, text=True).stdout.strip())
RUN = ROOT / "tests" / "run.sh"


def corpo(n):
    """O texto do unit_<n>()."""
    src = RUN.read_text()
    m = re.search(rf"^unit_{n}\(\) \{{\n(.*?)^\}}", src, re.S | re.M)
    return m.group(1) if m else None


def fixture_de(txt, src):
    """Qual fixture o unit usa — pelo helper fresh<nome> que ele invoca."""
    m = re.search(r"\$\(fresh(\w*?)\s+\S+\)", txt)
    if not m:
        return None
    nome = m.group(1)
    # o helper diz de qual diretório ele copia; é ele quem sabe, não nós
    h = re.search(rf"^fresh{nome}\(\) \{{(.*?)^\}}", src, re.S | re.M)
    if h:
        d = re.search(r'\$HERE"?/(fix\w+)', h.group(1))
        if d:
            return d.group(1)
    return f"fix{nome}" if nome else None


def alvos(cmds, fixdir):
    """arquivo:linha:col -> o identificador que está NAQUELA posição.

    A coluna do dump é 0-based e a da CLI é 1-based; contar na cabeça é a
    origem de uma classe inteira de erro (CLAUDE.md §7). Aqui se LÊ do arquivo.
    """
    out = []
    for c in cmds:
        for f, l, col in re.findall(r"(\S+\.prg):(\d+):(\d+)", c):
            p = fixdir / f
            if not p.exists():
                out.append((f"{f}:{l}:{col}", "(arquivo fora da fixture)", ""))
                continue
            linhas = p.read_text().split("\n")
            if int(l) > len(linhas):
                out.append((f"{f}:{l}:{col}", "(linha inexistente)", ""))
                continue
            txt = linhas[int(l) - 1]
            i = int(col) - 1
            m = re.match(r"[A-Za-z_][A-Za-z0-9_]*", txt[i:]) if i < len(txt) else None
            out.append((f"{f}:{l}:{col}", m.group(0) if m else "(não é identificador)", txt))
    return out


def asserts(txt):
    """O que o teste antigo AFIRMA hoje — é o contrato a preservar na migração."""
    r = []
    for ln in txt.split("\n"):
        s = ln.strip()
        if s.startswith("check "):
            m = re.match(r'check\s+"([^"]*)"', s)
            if m:
                r.append(("check", m.group(1)))
        elif "$TCHECK" in s or s.startswith('"$TCHECK"'):
            r.append(("tcheck", re.sub(r'.*TCHECK"?\s*', "", s)))
        elif s.startswith("grep") or s.startswith("cmp"):
            r.append(("shell", s))
    return r


def main():
    if len(sys.argv) < 2 or not sys.argv[1].isdigit():
        sys.exit(__doc__)
    n = sys.argv[1]
    src = RUN.read_text()
    txt = corpo(n)
    if txt is None:
        # já migrado? o silêncio seria enganoso
        if f"unit_{n}" not in src:
            sys.exit(f"unit_{n} não existe em tests/run.sh — já migrado, ou número errado.\n"
                     f"Fila atual: tools/unit-brief.py --fila")
        sys.exit(f"unit_{n}: corpo não reconhecido (formato inesperado no run.sh)")

    desc = re.search(r'echo "([^"]*)"', txt)
    cmds = re.findall(r'"\$BIN"\s+(.*?)\s*>\s*\S+\.log', txt)
    fix = fixture_de(txt, src)
    fixdir = ROOT / "tests" / fix if fix else None

    print(f"unit_{n} — {desc.group(1) if desc else '(sem echo de descrição)'}")
    print(f"fixture: {fix or '(não identificada)'}", end="")
    if fixdir and fixdir.is_dir():
        print("   arquivos: " + " ".join(sorted(p.name for p in fixdir.iterdir())))
    else:
        print()

    print("\ncomandos (a ENTRADA — vira `cmd` no case.json):")
    for i, c in enumerate(cmds, 1):
        print(f"  {i}. {c}")
    if cmds and not all("--json" in c for c in cmds):
        print("     (o cenário novo roda SEMPRE com --json: a prosa é arrasto e o passo 3\n"
              "      da fase A.1 a deleta — teste o que vai sobreviver)")

    if fixdir and fixdir.is_dir():
        al = alvos(cmds, fixdir)
        if al:
            print("\nalvos resolvidos (coluna COMPUTADA do arquivo, 1-based):")
            for pos, sym, linha in al:
                print(f"  {pos:<18} -> {sym!r}")
                if linha:
                    print(f"  {'':<18}    {linha.rstrip()}")

    print("\no que o teste AFIRMA hoje (preservar na migração, não copiar):")
    for tipo, a in asserts(txt):
        print(f"  [{tipo}] {a}")

    print("\npróximo passo:  tools/caso-new.sh <nome-que-diz-o-que-prova> "
          f"{fix or '<fixture>'}")
    print("depois: escreva expected/ e outputs.json À MÃO, ANTES de rodar (tests/README.md §3)")

    if "--raw" in sys.argv:
        print("\n--- corpo original ---")
        print(txt)


def fila():
    src = RUN.read_text()
    m = re.search(r'ALL_UNITS="([^"]*)"', src)
    if not m:
        sys.exit("tests/run.sh sem ALL_UNITS — o runner legado já morreu?")
    us = m.group(1).split()
    print(f"faltam {len(us)} units: {' '.join(us)}")
    casos = sorted((ROOT / "tests" / "cases").glob("*")) if (ROOT / "tests" / "cases").is_dir() else []
    if casos:
        print(f"+ {len(casos)} em tests/cases/: {' '.join(p.name for p in casos)}")
    cen = sorted(p.name for p in (ROOT / "tests" / "scenarios").iterdir() if p.is_dir())
    print(f"já migrados: {len(cen)}")
    print(f"\npróximo:  tools/unit-brief.py {us[1] if len(us) > 1 else us[0]}"
          "   (o unit_0 sai por último: ele guarda a fixture fix01)")


if __name__ == "__main__":
    if "--fila" in sys.argv:
        fila()
    else:
        main()
