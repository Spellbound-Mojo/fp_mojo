"""The callback catalog yields exactly the forms Mojo 1.2 requires."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
from native_signatures import admissions  # noqa: E402


def kinds(forms):
    return [f.kind + ("!" if f.raising else "") for f in forms]


class CallbackCatalogTest(unittest.TestCase):
    def test_counts_per_shape(self):
        self.assertEqual(kinds(admissions("owned", ["E"])),
                         ["library", "view", "closure", "closure!", "thin", "thin", "thin!"])
        self.assertEqual(kinds(admissions("binary", ["A", "B"]))[2:],
                         ["closure", "closure!", "thin", "thin", "thin!"])
        borrow = kinds(admissions("borrow", ["P"]))
        self.assertEqual(borrow.count("thin"), 4)
        self.assertEqual(borrow.count("thin!"), 2)
        self.assertNotIn("view", kinds(admissions("thunk", [])))

    def test_closures_infer_their_inputs(self):
        for form in admissions("owned", ["I.Element[V]"]):
            if form.kind == "closure":
                self.assertIn("I.Element[V] == C0", form.conditions)
                self.assertNotIn("I.Element[V]", form.explicit[-1])

    def test_fixed_error_closures(self):
        closures = [f for f in admissions("owned", ["E"], fixed_error="Self.E", known_closure=True)
                    if f.kind == "closure"]
        self.assertEqual([f.error for f in closures], ["Never", "Self.E", "Never"])
        self.assertIn("Self.E != Never", closures[2].conditions)
        self.assertTrue(all("X:" not in p for f in closures for p in f.explicit))

    def test_plain_functions(self):
        thin = [f for f in admissions("owned", ["E"]) if f.kind == "thin"]
        pure = [f for f in thin if not f.raising]
        raising = [f for f in thin if f.raising]
        self.assertEqual(len(pure), 2)
        self.assertEqual(len(raising), 1)
        self.assertNotIn("not conforms_to(R, RegisterPassable)", raising[0].conditions)
        self.assertIn("_NativeOwnedArg[E]", raising[0].argument)
        self.assertTrue(all(f.type.startswith("NativeUnary[") for f in thin))


if __name__ == "__main__":
    unittest.main()
