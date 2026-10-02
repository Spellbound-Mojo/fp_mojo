"""Pattern matching on algebraic data: `match`, `rewrite`, `when` and `Next`.

`match` takes a `Node` value, or two or three values, and one to sixteen
clauses: plain functions or lambdas without captures, whose parameter types
select the constructors they handle. The clauses are checked when the program
compiles and the match runs as one loop, so it is exhaustive, ends on every
value and is not limited by the native stack. `when` adds a guard to a clause,
`Next` continues with a smaller value, and `rewrite` transforms a value
bottom-up. Declare data with `fp.adt.Data`, `Cases` and `Node`.
"""

from .clauses import Guarded, Next, when
from .matcher import `match`, rewrite
