"""Operation contracts for generic code that forwards family operations.

Each contract groups one operation's admission (`Compatible`), result (`Out`)
and error (`Error`) for a family, source and callback, so a generic wrapper can
state exactly what the operation it calls requires:
`def wrapper[I: Functor, V: ..., F: ...](...) raises MapContract[I, V, F].Error
-> MapContract[I, V, F].Out where MapContract[I, V, F].Compatible`.
Everyday code calls the operations directly and never names a contract.
"""
from fp.algebra.errors import RecoverIfContract, OrElseIfContract, RecoverContract, TapErrContract, FlatTapErrContract
from fp.algebra._outcomes import EnsureContract, AttemptContract, AttemptTapContract
from fp.algebra.error_mapping import MapBothContract, MapErrContract
from fp.algebra._contracts import ApContract, ProductContract, Map2Contract, IfContract, AnyContract, AllContract, FindContract, FindMapContract, FoldMapContract, FoldContract, MapContract, FilterMapContract, BindContract, TraverseContract, TraverseTapContract, FilterContract, CombineContract, FillContract, VoidContract, TupleLeftContract, TupleRightContract, ProductLeftContract, ProductRightContract
from fp.algebra.sequencing import FlatTapContract, FlatPairWithContract, BeforeContract, FollowedByContract
from fp.algebra._traversal import FilterEffectContract, TraverseFilterContract, FlatTraverseContract
from fp.algebra.absence import AbsenceContract
from fp.algebra.looping import TailRecContract
