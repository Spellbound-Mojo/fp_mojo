from fp.algebra import Monad, FlatTapContract, FlatPairWithContract, BeforeContract, FollowedByContract
from fp.callables import BorrowCallContract, ThunkContract
from fp.functions import pipeline

@fieldwise_init
struct MissingBorrow(BorrowCallContract, Movable):
    comptime Payload = Int
    comptime Result = Optional[Int]

@fieldwise_init
struct MissingThunk(ThunkContract, Movable):
    comptime Out = Optional[Int]

def checked_flat_tap[I: Monad, V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](var source: V, var callback: C) raises FlatTapContract[I,V,C].Error -> FlatTapContract[I,V,C].Out where FlatTapContract[I,V,C].InvocationCompatible:
    return pipeline[I](source^).flat_tap(callback^).get()

def checked_flat_pair_with[I: Monad, V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](var source: V, var callback: C) raises FlatPairWithContract[I,V,C].Error -> FlatPairWithContract[I,V,C].Out where FlatPairWithContract[I,V,C].InvocationCompatible:
    return pipeline[I](source^).flat_pair_with(callback^).get()

def checked_before[I: Monad, V: Movable & Deinitable, C: ThunkContract & Movable & Deinitable](var source: V, var callback: C) raises BeforeContract[I,V,C].Error -> BeforeContract[I,V,C].Out where BeforeContract[I,V,C].InvocationCompatible:
    return pipeline[I](source^).before(callback^).get()

def checked_followed_by[I: Monad, V: Movable & Deinitable, C: ThunkContract & Movable & Deinitable](var source: V, var callback: C) raises FollowedByContract[I,V,C].Error -> FollowedByContract[I,V,C].Out where FollowedByContract[I,V,C].InvocationCompatible:
    return pipeline[I](source^).followed_by(callback^).get()
