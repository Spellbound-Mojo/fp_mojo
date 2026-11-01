"""The value-first argument order of free operations, applied in one place.

Free operations take the carrier first, then other data, then callbacks in
their existing order, then keyword-only arguments (see
docs/content/architecture/native-boundaries.md). Emitters may spell a free
signature in any order; generate_plain_overloads.py passes every generated
module through `rewrite_defs`, which reorders callback-first definitions of
the listed operations and their docstring Args, and leaves all else alone.
"""
import re

TARGETS = set("""map flat_map traverse traverse_void traverse_tap flat_traverse traverse_filter filter_effect
any_effect all_effect find_effect find_map_effect fold_map_effect fold_effect if_effect filter filter_map filter_not
tail_rec_m map2_lazy all any find find_map fold_map fold_left fold_until reduce reduce_optional scan_left scan_map
map_accumulate map_with_index zip_with take_while drop_while partition partition_map align_with count_where for_each
collect_fold min_by max_by sum_by reduce_non_empty reduce_map minimum_by_non_empty maximum_by_non_empty tap_each
pair_with censor local""".split())
CALLBACKS = {"function", "f", "predicate", "step", "key", "on_true", "on_false"}
CARRIERS = {"source", "iterator", "value", "condition", "values"}

OPEN, CLOSE = "([{", ")]}"


def matching(text, i):
    """Index just past the bracket group opening at text[i]."""
    depth = 0
    quote = None
    j = i
    while j < len(text):
        c = text[j]
        if quote:
            if c == "\\":
                j += 2
                continue
            if c == quote:
                quote = None
        elif c in "\"'":
            quote = c
        elif c in OPEN:
            depth += 1
        elif c in CLOSE:
            depth -= 1
            if depth == 0:
                return j + 1
        j += 1
    return -1


def split_top(s):
    out, depth, start, quote, i = [], 0, 0, None, 0
    while i < len(s):
        c = s[i]
        if quote:
            if c == "\\":
                i += 2
                continue
            if c == quote:
                quote = None
        elif c in "\"'":
            quote = c
        elif c in OPEN:
            depth += 1
        elif c in CLOSE:
            depth -= 1
        elif c == "," and depth == 0:
            out.append(s[start:i])
            start = i + 1
        i += 1
    out.append(s[start:])
    return out


def arg_name(a):
    a = a.strip()
    a = re.sub(r"^(var|ref\[[^\]]*\]|ref|mut|deinit|owned|read)\s+", "", a)
    return a.split(":")[0].split("=")[0].strip()


def reorder_params(args):
    """Definition argument list (pieces) -> reordered pieces, or None."""
    names = [arg_name(a) for a in args]
    if not names or names[0] not in CALLBACKS:
        return None
    star = next((i for i, n in enumerate(names) if n in ("*", "")), len(names))
    head = list(range(star))
    callbacks = [i for i in head if names[i] in CALLBACKS]
    carriers = [i for i in head if names[i] in CARRIERS]
    other = [i for i in head if i not in callbacks and i not in carriers]
    order = carriers + other + callbacks + list(range(star, len(names)))
    if order == list(range(len(names))):
        return None
    return order


def rewrite_defs(text):
    out, pos, count = [], 0, 0
    for m in re.finditer(r"^def ([a-z_0-9]+)\[", text, re.M):
        if m.group(1) not in TARGETS or m.start() < pos:
            continue
        b = matching(text, m.end() - 1)
        if b < 0 or text[b] != "(":
            continue
        e = matching(text, b)
        inner = text[b + 1:e - 1]
        pieces = split_top(inner)
        trailing = ""
        if pieces and not pieces[-1].strip():
            trailing = pieces.pop()
        order = reorder_params(pieces)
        if order is None:
            continue
        stripped = [p.strip() for p in pieces]
        lead = re.match(r"\s*", inner).group(0)
        tail = re.search(r"\s*$", inner).group(0)
        new_inner = lead + ", ".join(stripped[i] for i in order) + tail
        names = [arg_name(p) for p in pieces]
        out.append(text[pos:b + 1])
        out.append(new_inner)
        pos = e - 1
        # Docstring Args, when the next docstring documents these arguments.
        body_start = e
        doc = re.compile(r'"""(.*?)"""', re.S).search(text, body_start)
        nxt = re.compile(r"^(def |struct |@|comptime )", re.M).search(text, e)
        if doc and (not nxt or doc.start() < nxt.start()):
            out.append(text[pos:doc.start()])
            out.append(reorder_doc_args(doc.group(0), [names[i] for i in order]))
            pos = doc.end()
        count += 1
    out.append(text[pos:])
    return "".join(out), count


def reorder_doc_args(doc, order):
    m = re.search(r"(\n(\s*)Args:\n)((?:\2    \S.*\n(?:\2        .*\n)*)+)", doc)
    if not m:
        return doc
    indent = m.group(2) + "    "
    entries = re.findall(rf"({re.escape(indent)}(\w+):.*\n(?:{re.escape(indent)}    .*\n)*)", m.group(3))
    by = {name: block for block, name in entries}
    if set(by) - set(order):
        known = [n for n in order if n in by] + [n for n in by if n not in order]
    else:
        known = [n for n in order if n in by]
    return doc[:m.start(3)] + "".join(by[n] for n in known) + doc[m.end(3):]
