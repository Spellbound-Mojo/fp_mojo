"""Algebraic data types declared from your own structs, and their values.

A data type lists its constructors, ordinary structs, in a `Cases`; a
constructor field that holds a value of the same type has the layer's
parameter `R`, `List[R]` or `Optional[R]`:

```text
struct Expr(Data):
    comptime Layer[R: Value] = Cases[Num, Add[R], If[R, R]]
```

A value holds one constructor, and comes in two kinds:

- `Node[F]` is immutable and shared: copying it shares it in constant time. A
  node can only refer to nodes that already exist, so a value is a finite
  acyclic graph. Recursive data needs it; each node is one allocation.
- `Choice[F]` is owned and stored in place, in a native `Variant`, with no
  allocation, for a type with no recursive field. Copying it copies the
  constructor.

A constructor converts to either implicitly. `fp.match` matches both, and
`fp.rewrite` transforms nodes.
"""

from .data import Cases, CaseList, Choice, Data, Node, Value
