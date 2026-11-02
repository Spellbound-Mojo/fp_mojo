"""Overlay patch: widen the sum-type carriers so their success payload may be linear.

Used to let the compiler audit what admitting linear values in `Cases`/`Choice`,
`Ok`/`Err`/`Result` and `Outcome` would touch (24 errors across Result's family
conformances, branch helpers, validation and iteration, then a compiler crash
on Mojo 1.2.0). Apply with `experiments/overlay.py --patch`.
"""

# Each change: (file under fp/, old text, new text, expected occurrences).
CHANGES = [
    ('adt/data.mojo',
     '    comptime Subject: Value\n    """The stored value: one constructor at a time."""',
     '    comptime Subject: Movable\n    """The stored value: one constructor at a time."""', 1),
    ('adt/data.mojo',
     '    comptime Case[i: Int]: Value\n    """The constructor at position `i`."""',
     '    comptime Case[i: Int]: Movable\n    """The constructor at position `i`."""', 1),
    ('adt/data.mojo',
     'struct Cases[*Ts: Value](CaseList):',
     'struct Cases[*Ts: Movable](CaseList):', 1),
    ('adt/data.mojo',
     '    comptime Case[i: Int]: Value = Self.Ts[i]',
     '    comptime Case[i: Int]: Movable = Self.Ts[i]', 1),
    ('adt/data.mojo',
     '    _ChoiceType, Movable,\n',
     '    _ChoiceType, Movable,\n    Deinitable where conforms_to(F.Layer[Node[F]].Subject, Deinitable),\n', 1),
    ('data/_result.mojo',
     'struct Ok[T: Movable & Deinitable](Movable, Copyable',
     'struct Ok[T: Movable](Movable, Deinitable where conforms_to(T, Deinitable), Copyable', 1),
    ('data/_result.mojo',
     'struct _ResultCases[T: Movable & Deinitable, E: Movable & Deinitable](Data):',
     'struct _ResultCases[T: Movable, E: Movable & Deinitable](Data):', 1),
    ('data/_result.mojo',
     'struct Result[T: Movable & Deinitable, E: Movable & Deinitable](\n'
     '    _ResultType, _ChoiceType, Movable, Copyable',
     'struct Result[T: Movable, E: Movable & Deinitable](\n'
     '    _ResultType, _ChoiceType, Movable, Deinitable where conforms_to(T, Deinitable), Copyable', 1),
    ('data/_result.mojo',
     '    comptime Value: Movable & Deinitable\n    comptime Error: Movable & Deinitable\n',
     '    comptime Value: Movable\n    comptime Error: Movable & Deinitable\n', 1),
    ('effects/outcomes.mojo',
     'comptime Outcome[T: Movable & Deinitable, E: Movable & Deinitable] =',
     'comptime Outcome[T: Movable, E: Movable & Deinitable] =', 1),
]


def patch(folder, parts=None):
    for relative, old, new, expected in CHANGES:
        path = folder / 'fp' / relative
        text = path.read_text()
        found = text.count(old)
        if found != expected:
            raise SystemExit(f'patch_carriers: {relative}: expected {expected} occurrence(s), found {found}:\n{old}')
        path.write_text(text.replace(old, new))
