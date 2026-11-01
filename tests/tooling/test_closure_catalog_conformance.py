"""Iter closure bounds are the catalog's closure forms.

Generated overloads take them from native_signatures.closure(); documented
hand-written overloads keep their own text, so this test holds every closure
bound in those modules to the catalog spelling for its shape.
"""
import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from native_signatures import closure  # noqa: E402
from value_first import matching, split_top  # noqa: E402

MODULES = ("src/fp/iteration/chaining.mojo",)
BOUND = re.compile(r"^\s*(\w+)\s*:\s*(def\((.*)\)(?:\s+raises\s+(\w+))?\s*->\s*(.+))$", re.S)


def closure_bounds(text):
    for m in re.finditer(r"^\s*def [a-z_]+\[", text, re.M):
        end = matching(text, m.end() - 1)
        for parameter in split_top(text[m.end():end - 1]):
            # A callback after a defaulted family defaults to its own bound.
            declared, separator, default = parameter.partition(" = def(")
            if separator:
                assert re.sub(r"\s+", " ", declared.split(":", 1)[1]).strip() == "def(" + re.sub(r"\s+", " ", default).strip(), parameter
                parameter = declared
            bound = BOUND.match(parameter)
            if bound and " thin" not in bound.group(2):
                yield text.count("\n", 0, m.start()) + 1, bound


def expected(bound):
    name, _, inputs, error, result = bound.groups()
    operands = [x.strip() for x in split_top(inputs) if x.strip()]
    if any(x.startswith("mut ") for x in operands):
        return None  # mutating callbacks are not a catalog shape
    owned = [x.startswith("var ") for x in operands]
    types = [x.removeprefix("var ") for x in operands]
    mode = {0: "thunk", 1: "owned" if owned and owned[0] else "borrow", 2: "binary"}[len(operands)]
    if mode == "binary" and not all(owned):
        return None  # read index with an owned element: not a catalog shape
    names = {"C": name, "R": result.strip(), **{f"in{i}": t for i, t in enumerate(types)}}
    if error == "Never":
        form = closure(mode, False, names=names, fixed_error="Self.E", never=True)
    else:
        form = closure(mode, error is not None, names={**names, "X": error or "X"})
    return form.explicit[-1]


class ClosureCatalogConformanceTest(unittest.TestCase):
    def test_closure_bounds_are_catalog_forms(self):
        checked = 0
        for module in MODULES:
            text = (ROOT / module).read_text()
            for line, bound in closure_bounds(text):
                want = expected(bound)
                if want is None:
                    continue
                got = f"{bound.group(1)}: {re.sub(r'\\s+', ' ', bound.group(2)).strip()}"
                self.assertEqual(got, want, f"{module}:{line}")
                checked += 1
        self.assertGreater(checked, 60)

    def test_no_alias_spelled_closure_bounds(self):
        alias = re.compile(r"\b\w+\s*:\s*_(?:Raising)?(?:Unary|Binary|Borrowing|Thunk)\[")
        for module in MODULES:
            text = (ROOT / module).read_text()
            for m in re.finditer(r"^\s*def [a-z_]+\[", text, re.M):
                parameters = text[m.end():matching(text, m.end() - 1) - 1]
                self.assertIsNone(alias.search(parameters), f"{module}:{text.count(chr(10), 0, m.start()) + 1}")


if __name__ == "__main__":
    unittest.main()
