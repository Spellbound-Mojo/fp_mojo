"""Generate native invocation bodies; existing views retain storage and origins."""

from pathlib import Path

from native_signatures import native_dispatch

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "src/fp/callables/native.mojo"

# These are the existing invocation owners. Capture delegates matching shapes
# here and uses the same emitter for its remaining mixed-convention bundles.
VIEWS = {
    "binary": ("oo", ["A", "B"], ["first", "second"], False, False),
    "keywords": ("", [], [], True, False),
    "mutating": ("m", ["A"], ["value"], False, True),
    "mut_owned": ("mo", ["A", "B"], ["first", "second"], False, True),
    "mutating_keywords": ("m", ["A"], ["first"], True, True),
    "mut_owned_keywords": ("mo", ["A", "B"], ["first", "second"], True, True),
}


def markers(name):
    indent = "        " if VIEWS[name][-1] else "    "
    return (
        indent + f"# --- native invocation: {name} (generated) ---\n",
        indent + "# --- end native invocation ---\n",
    )


def body(name):
    shape, types, values, keywords, view = VIEWS[name]
    prefix = "Self." if view else ""
    return native_dispatch(
        shape,
        [prefix + t for t in types],
        values,
        keyword=prefix + "K" if keywords else None,
        keyword_value="values",
        result=prefix + "R",
        error=prefix + "E" if name != "binary" else "X",
        function_type=prefix + "F",
        function="self.function[]" if view else "function",
        raising=prefix + "raising",
        indent="        " if view else "    ",
    )


def source(text=None):
    text = OUTPUT.read_text() if text is None else text
    for name in VIEWS:
        start, end = markers(name)
        before, remaining = text.split(start, 1)
        _, after = remaining.split(end, 1)
        text = before + start + body(name) + end + after
    return text.rstrip() + "\n"


if __name__ == "__main__":
    OUTPUT.write_text(source())
    print(f"wrote {OUTPUT.relative_to(ROOT)}")
