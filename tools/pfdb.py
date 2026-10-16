"""Tiny parser for the pfQuest database files (https://github.com/shagu/pfQuest, MIT).

Only understands the subset of Lua table syntax that pfQuest's generated db files use.
"""
import re

_ENTRY = re.compile(r'^  \[(-?\d+)\] = \{\s*$')
_COORD = re.compile(r'\{ (-?[\d.]+), (-?[\d.]+), (\d+), (-?\d+) \}')
_FIELD = re.compile(r'^    \["(\w+)"\] = "([^"]*)",')


def load_spawns(path):
    """Return {id: {"coords": [(x, y, zone, respawn)], "fac": str, "lvl": str}}."""
    out, cur = {}, None
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            m = _ENTRY.match(line)
            if m:
                cur = out.setdefault(int(m.group(1)), {"coords": []})
                continue
            if cur is None:
                continue
            m = _FIELD.match(line)
            if m:
                cur[m.group(1)] = m.group(2)
                continue
            m = _COORD.search(line)
            if m:
                cur["coords"].append((float(m.group(1)), float(m.group(2)),
                                      int(m.group(3)), int(m.group(4))))
    return out


_NAME = re.compile(r'^  \[(-?\d+)\] = "((?:[^"\\]|\\.)*)",')


def load_names(path):
    out = {}
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            m = _NAME.match(line)
            if m:
                out[int(m.group(1))] = m.group(2).replace("\\'", "'")
    return out


def load_meta(path, key):
    """Return {id: value} for pfDB["meta"][key]."""
    out, inside = {}, False
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            if line.startswith('  ["%s"]' % key):
                inside = True
                continue
            if inside:
                if line.startswith("  },"):
                    break
                m = re.match(r'^    \[(-?\d+)\] = "?([^",]*)"?,', line)
                if m:
                    out[int(m.group(1))] = m.group(2)
    return out


def load_minimap(path):
    out = {}
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            m = re.match(r'^  \[(\d+)\] = \{ ([\d.]+), ([\d.]+) \},', line)
            if m:
                out[int(m.group(1))] = (float(m.group(2)), float(m.group(3)))
    return out
