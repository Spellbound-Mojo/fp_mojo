"""The payload thread-safety walk and its marker: the one owner of both.

Mojo 1.2 has no `Send` or `Sync`. This module finds, by reflection, the two
hazards the compiler can see in a payload's field tree, and owns the marker
that lets an author claim a type is safe anyway. When Mojo adds `Send` and
`Sync`, only this module and the marker's definition change.

The walk is conservative and has known holes (see the async thread-safety
architecture page): standard-library types are trusted owners of their
allocations, and the walk enters their elements only through `IterableOwned`
(`List`, `Optional`), so `Dict` values, `Variant`, `Tuple` and `OwnedPointer`
payloads are invisible.
"""
from std.builtin.rebind import downcast


trait ThreadTransferable:
    """A type its author claims may move to, be used on, and be destroyed on another thread.

    Conforming is an explicit claim that the compiler cannot check. Claim it for
    a type that owns memory through a raw `Pointer` it never shares
    unsynchronized, or that synchronizes every access to state it shares, such
    as a structure behind an `ArcPointer` to atomics or a lock. Never claim it
    for a type holding a borrowed view of another owner's state.

    The payload check and `assert_thread_transferable` stop at a conforming
    type and do not inspect its fields. The marker gives way to Mojo's `Send`
    and `Sync` if they arrive.
    """

    pass


def _is_std[T: AnyType]() -> Bool:
    return reflect[T].name[qualified_builtins=True]().startswith("std.")


def _is_hazard[T: AnyType, with_shared: Bool]() -> Bool:
    comptime r = reflect[T]
    comptime if not r.is_struct():
        return False
    elif r.base_name() == "Pointer":
        return True
    else:
        return with_shared and (r.base_name() == "ArcPointer" or r.base_name() == "WeakPointer")


comptime _HELD = ", which is not ThreadTransferable"


def _offender[T: AnyType, with_shared: Bool]() -> String:
    """Describe the first hazard in T's field tree, or return an empty string.

    A hazard is a `Pointer` and, with `with_shared`, an `ArcPointer` or
    `WeakPointer`. The walk stops at a ThreadTransferable type, trusts the
    standard library's own fields, and enters standard containers only through
    `IterableOwned`. A description ends with `_HELD` once it names the
    unmarked struct holding the hazard; until then it names only the hazard.
    """
    # Every branch is an elif: code after a `return` inside `comptime if` is
    # still elaborated, and field reflection on a non-struct fails to compile.
    comptime r = reflect[T]
    comptime if conforms_to(T, ThreadTransferable):
        return String()
    elif not r.is_struct():
        return String()
    elif _is_hazard[T, with_shared]():
        return (String("an `") if r.base_name().startswith("A") else String("a `")) + r.base_name() + "`"
    elif _is_std[T]():
        comptime if conforms_to(T, IterableOwned):
            return _offender[downcast[T, IterableOwned].IteratorOwnedType.Element, with_shared]()
        else:
            return String()
    else:
        comptime types = r.field_types()
        comptime for i in range(r.field_count()):
            comptime inner = _offender[types[i], with_shared]()
            comptime if inner.byte_length() == 0:
                pass
            elif inner.endswith(_HELD):
                return inner
            elif _is_hazard[types[i], with_shared]():
                return inner + " field of `" + r.name() + "`" + _HELD
            else:
                return inner + " in a `" + reflect[types[i]].base_name() + "` field of `" + r.name() + "`" + _HELD
        return String()


def _described[T: AnyType, with_shared: Bool]() -> String:
    """The first hazard in T's field tree with its holder, or an empty string."""
    comptime offender = _offender[T, with_shared]()
    comptime if offender.byte_length() == 0 or offender.endswith(_HELD):
        return offender
    else:
        return offender + " outside any ThreadTransferable struct"


def _payload_rejection[T: AnyType]() -> String:
    """The diagnostic for erasing T, or an empty string when erasure admits T.

    Erasure rejects a raw or borrowed `Pointer` outside a ThreadTransferable
    struct. Shared ownership is left to `assert_thread_transferable`.
    """
    comptime offender = _described[T, False]()
    comptime if offender.byte_length() == 0:
        return String()
    else:
        return (
            String("cannot erase `") + reflect[T].name() + "`: it reaches " + offender
            + ". An erased payload must own its state and be safe to move to, use"
            + " on and destroy on another thread. Own the state instead of"
            + " pointing to it, or conform the struct to"
            + " `fp.effects.ThreadTransferable` to claim that it is safe."
        )


def assert_thread_transferable[T: AnyType]():
    """Reject T at compile time unless the payload walk finds it transferable.

    Stricter than the check every erased payload passes: besides a raw or
    borrowed `Pointer`, it rejects shared ownership (`ArcPointer` and
    `WeakPointer`) outside a ThreadTransferable struct, because fibers that
    mutate the target through copies on two workers race. Calling it has no
    run-time effect.

    The walk cannot prove transferability. It trusts standard-library types,
    enters their elements only through `IterableOwned` (`List`, `Optional`),
    and cannot see `Dict` values or the payloads of `Variant`, `Tuple` and
    `OwnedPointer`.

    Parameters:
        T: The type to check.
    """
    comptime offender = _described[T, True]()
    comptime assert offender.byte_length() == 0, (
        String("`") + reflect[T].name() + "` is not thread-transferable: it reaches "
        + offender + ". Share mutable state through the library's synchronized"
        + " owners, or conform the struct to `fp.effects.ThreadTransferable` to"
        + " claim that it synchronizes every access."
    )


trait _RootBound:
    """A value tied to the root that made it: `Fiber`, `Supervisor` and `Poll`.

    Such a value names state of its own root's scheduler, so it must not leave
    or enter an `IO.eval_on` region, which runs as another root
    (`_root_bound_rejection`). Private: only the library's handles conform.
    """

    pass


def _root_bound_offender[T: AnyType]() -> String:
    """The path to the first root-bound type in T's field tree, or an empty string.

    Unlike the payload walk it does not stop at `ThreadTransferable` types,
    since a `Fiber` is one. It enters standard containers only through
    `IterableOwned` (`List`, `Optional`), so `Tuple`, `Variant`, `Dict` values
    and `OwnedPointer` payloads are not seen.
    """
    comptime r = reflect[T]
    comptime if conforms_to(T, _RootBound):
        return String("`") + r.base_name() + "`"
    elif not r.is_struct():
        return String()
    elif _is_std[T]():
        comptime if conforms_to(T, IterableOwned):
            comptime inner = _root_bound_offender[downcast[T, IterableOwned].IteratorOwnedType.Element]()
            comptime if inner.byte_length() == 0:
                return String()
            else:
                return inner + " in `" + r.base_name() + "`"
        else:
            return String()
    else:
        comptime types = r.field_types()
        comptime for i in range(r.field_count()):
            comptime inner = _root_bound_offender[types[i]]()
            comptime if inner.byte_length() != 0:
                return inner + " in a field of `" + r.base_name() + "`"
        return String()


def _root_bound_rejection[T: AnyType](site: StaticString) -> String:
    """The diagnostic for T crossing a region boundary at `site`, or an empty string."""
    comptime offender = _root_bound_offender[T]()
    comptime if offender.byte_length() == 0:
        return String()
    else:
        comptime subject = (String("`") + reflect[T].base_name() + "` is") if conforms_to(T, _RootBound) else (String("`") + reflect[T].base_name() + "` reaches " + offender + ", which is")
        return (
            String(site) + ": " + subject
            + " tied to the root that made it. A region runs as another"
            + " root: start, join or supervise fibers inside the region, and"
            + " return their results instead."
        )

