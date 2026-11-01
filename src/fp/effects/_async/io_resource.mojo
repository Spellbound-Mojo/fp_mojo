"""Resource[T, E], defined in `engine` beside IO, whose `background` returns one; re-exported here.

A resource erases its typed plan once, at construction. Each use erases its
scoped body to one carrier per resource type and runs the plan's Scope as an
IO leaf; the body's value is boxed by that carrier and unboxed by the same use.
Composition reuses the typed plan owners: flat_map joins this resource as the
left plan of the canonical join. Defining it in `engine` keeps the module
graph acyclic.
"""
from .engine import Resource, _ErasedScoped, _UsePlan, _Factory, _Joins, _PureFactory
