"""Append the puzzle definitions from hypercubing.xyz's MPU page to MPUlt_puzzles.txt.

usage: python3 -I mpu-merge-puzzles.py <MPUlt_puzzles.txt> <magicpuzzleultimate.md>

The page keeps definitions in fenced code blocks nested inside `??? abstract "<category>"`
admonitions. Each category becomes a submenu under a "hypercubing.xyz" menu. Puzzles whose
name already exists in the file are skipped. The file is rewritten with CRLF line endings,
which MPU's own file uses.
"""
import re
import sys


def page_puzzles(md):
    """Yield (category path, definition lines) for each code block on the page."""
    stack = []  # (indent, category name)
    lines = md.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        indent = len(line) - len(line.lstrip())
        m = re.match(r'\s*\?\?\?\+? abstract "(.+)"', line)
        if m:
            while stack and stack[-1][0] >= indent:
                stack.pop()
            stack.append((indent, m.group(1)))
        elif line.strip().startswith("```"):
            while stack and stack[-1][0] >= indent:
                stack.pop()
            body = []
            i += 1
            while i < len(lines) and not lines[i].strip().startswith("```"):
                body.append(lines[i][indent:].rstrip())
                i += 1
            if any(l.startswith("Puzzle ") for l in body):
                yield [name for _, name in stack], body
        i += 1


def menu_name(s):
    return s.replace(" ", "_")  # MPU values can't contain spaces


def main(puzzles_path, md_path):
    text = open(puzzles_path, encoding="latin-1").read().replace("\r\n", "\n")
    existing = set(re.findall(r"^Puzzle (\S+)", text, re.M))
    tree = {}  # category tuple -> list of definitions
    added = 0
    for cats, body in page_puzzles(open(md_path, encoding="utf-8").read()):
        # A code block can hold several puzzles separated by blank lines.
        chunks, cur = [], []
        for l in body + [""]:
            if l.strip():
                cur.append(l)
            elif cur:
                chunks.append(cur)
                cur = []
        for chunk in chunks:
            if not chunk[0].startswith("Puzzle "):
                continue
            # MPU takes the name up to the first space (ln.Split(' ')[1]), so "Puzzle 3^4 Skewb"
            # on the page would load as "3^4". Join multi-word names with underscores.
            name = "_".join(chunk[0].split()[1:])
            chunk[0] = "Puzzle " + name
            if name in existing:
                continue
            existing.add(name)
            tree.setdefault(tuple(cats), []).append(chunk)
            added += 1
    if not tree:
        print("mpu-merge-puzzles: nothing to add")
        return
    # Nest categories that share a prefix ("4D Puzzles" > "Tesseract Family", "4D Puzzles" > "Other").
    nested = {}
    for cats, chunks in tree.items():
        node = nested
        for c in cats:
            node = node.setdefault(c, {})
        node.setdefault(None, []).extend(chunks)

    def emit(node):
        lines = []
        for chunk in node.get(None, []):
            lines += chunk + [""]
        for name in [k for k in node if k is not None]:
            lines += ["Block " + menu_name(name), ""] + emit(node[name]) + ["EndBlock", ""]
        return lines

    out = ["", "Block hypercubing.xyz", ""] + emit(nested) + ["EndBlock", ""]
    text = text.rstrip("\n") + "\n" + "\n".join(out)
    open(puzzles_path, "w", encoding="latin-1", newline="\r\n").write(text)
    print(f"mpu-merge-puzzles: added {added} puzzles")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
