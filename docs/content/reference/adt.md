# fp.adt

`fp.adt` defines algebraic and inductive data types from ordinary Mojo structs.
Use `Choice` to store a non-recursive sum type in place, or `Node` for shared
values and recursive structures such as expression trees. Both support
exhaustive pattern matching through [fp.matching](matching.md).

The tutorial covers [algebraic data and pattern matching](../tutorial/matching.md),
[storage in place](../tutorial/choices.md) and
[inductive data types](../tutorial/recursion.md).

<!-- api: adt -->
