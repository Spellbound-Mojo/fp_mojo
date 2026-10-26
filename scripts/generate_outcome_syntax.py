"""Family admission for validation and fixed-error outcome composition."""
from itertools import product
from native_signatures import callback
from operation_specs import ERROR_OPERATIONS, error_operations, native_errors_compatible


def parameters(callbacks):
    params = [p for cb in callbacks for p in cb.parameters if not p.startswith(('R:', 'S:'))]
    params += ['//', 'I: Applicative']
    params += [p for cb in callbacks for p in cb.parameters if p.startswith(('R:', 'S:'))]
    params += [p for cb in callbacks for p in cb.explicit]
    return params + ['Z: AnyType = _InferError']


def methods():
    out = []
    family = '_ErrorFamily[I]'
    monad = '_ErrorMonad[I]'
    elem = 'I.Element[Self.Value]'
    base = ['conforms_to(I, ApplicativeError)', f'{family}._ErrorCarrier[Self.Value]']
    operation = ERROR_OPERATIONS['ensure']
    primary, secondary = operation.callbacks
    for pk, fk in product(('library', 'pure', 'raising'), repeat=2):
        p = callback(primary.mode, pk, primary.argument)
        f = callback(secondary.mode, fk, secondary.argument, True)
        continuation = f'_Ensure[{family}, {elem}, {p.type}, {f.type}]'
        result = f'{monad}.Bound[Self.Value, {continuation}]'
        error = f'_EntryError[Z, {monad}.BindError[Self.Value, {continuation}]]'
        predicate_input = primary.input(elem, family + '.Failure')
        factory_input = secondary.input(elem, family + '.Failure')
        where = base + ['conforms_to(I, Monad)', f'{p.payload} == {predicate_input}', f'{p.result} == Bool', f'{f.payload} == {factory_input}', f'{f.result} == {family}.Failure']
        where += [native_errors_compatible(p.error, f.error)]
        doc = 'Keep accepted successes; construct a stored failure for rejected values.'
        if pk == fk == 'library':
            doc += '''

        Existing failures skip both callbacks. Predicate and error factory borrow
        the success; the factory runs only on rejection. Branching requires
        repeatable callbacks. Native callbacks remain borrowed until execution;
        library callbacks move into the computation. Stored error types stay fixed.

        Parameters:
            C: The borrowing Bool predicate.
            G: The borrowing stored-error factory.
            I: A Monad with ApplicativeError.
            Z: Optional exact native construction error for generic forwarding.

        Args:
            predicate: Tests each success without consuming it.
            make_error: Borrows a rejected success and returns the selected error type.

        Returns:
            A pipeline holding accepted successes or stored failures.

        Raises:
            Exact callback and family errors; deferred run errors stay deferred.
        '''
        out.append(f'''
    def ensure[{', '.join(parameters([p, f]))}](deinit self, {p.argument}, {f.argument}) raises {error} -> Piped[{result}] where {' and '.join(where)}:
        """{doc}"""
        comptime assert _ErrorCompatible[{error}, {monad}.BindError[Self.Value, {continuation}]]
        return Piped(_flat_map_as[{error}, {monad}]({continuation}({p.build}, {f.build}), self.value^))
''')
    for operation in error_operations('redeem'):
        name, effect = operation.name, operation.effect
        primary, secondary = operation.callbacks
        for lk, rk in product(('library', 'pure', 'raising'), repeat=2):
            left = callback(primary.mode, lk, primary.argument)
            right = callback(secondary.mode, rk, secondary.argument, True)
            runner = f'_Redeem[{family}, Self.Value, {left.type}, {right.type}, {effect}]'
            error = f'_EntryError[Z, {runner}.Error]'
            success_input = primary.input(elem, family + '.Failure')
            error_input = secondary.input(elem, family + '.Failure')
            where = base + [f'{left.payload} == {success_input}', f'{right.payload} == {error_input}']
            where += [native_errors_compatible(left.error, right.error)]
            if effect:
                where += ['conforms_to(I, Monad)', f'{family}._ErrorCarrier[{left.result}]', f'{family}._ErrorCarrier[{right.result}]', f'I.Element[{left.result}] == I.Element[{right.result}]']
            else:
                where += [f'{left.result} == {right.result}']
            doc = ('Continue the original outcome with its selected handler effect.' if effect else 'Turn the selected success or stored failure into a successful value.')
            if lk == rk == 'library':
                doc += '''

        Exactly one handler consumes each original outcome. A handler failure
        passes onward without invoking the other handler. The selected stored
        error type stays fixed. Native callbacks remain borrowed until execution;
        library callbacks move into the computation. Branching requires repeatable
        handlers. Unselected callbacks are disposed through the existing family.

        Parameters:
            C: The consuming success handler.
            G: The consuming error handler.
            I: The selected error-capable family; redeem_with also requires Monad.
            Z: Optional exact native construction error for generic forwarding.

        Args:
            on_ok: Consumes an original success.
            on_err: Consumes an original stored error.

        Returns:
            A pipeline with the common success type and the original error type.

        Raises:
            Exact callback and family errors; native raises are never recovered.
        '''
            out.append(f'''
    def {name}[{', '.join(parameters([left, right]))}](deinit self, {left.argument}, {right.argument}) raises {error} -> Piped[{runner}.Out] where {' and '.join(where)}:
        """{doc}"""
        comptime assert _ErrorCompatible[{error}, {runner}.Error]
        var value = self^.get()
        try:
            return Piped({runner}.apply(value^, {left.build}, {right.build}))
        except raised:
            _propagate_error[{error}](raised^)
''')
    primary = ERROR_OPERATIONS['attempt_tap'].callbacks[0]
    for kind in ('library', 'pure', 'raising'):
        c = callback(primary.mode, kind, 'inspect')
        runner = f'_AttemptTap[{monad}, Self.Value, {c.type}]'
        error = f'_EntryError[Z, {runner}.Error]'
        where = base + ['conforms_to(I, Monad)', f'{c.payload} == ' + primary.input(elem, family + '.Failure', whole=f'Result[{elem}, {family}.Failure]'), f'{family}._ErrorCarrier[{c.result}]']
        doc = 'Observe the whole selected Result and restore it after observer success.'
        if kind == 'library':
            doc += '''

        The observer borrows each original Result, on either success or failure,
        and returns an effect in the same family. Observer failures replace the
        original outcome; empty observer effects stay empty. Branching requires
        a repeatable observer and copyable retained outcomes. Single-use paths
        admit move-only values. Native callbacks remain borrowed until execution.

        Parameters:
            C: The borrowing whole-outcome observer.
            I: A Monad with ApplicativeError, selecting the stored-error layer.
            Z: Optional exact native construction error for generic forwarding.

        Args:
            inspect: Borrows Result[success, stored error] and returns its effect.

        Returns:
            A pipeline retaining the outcome per successful observer branch.

        Raises:
            Exact callback and family errors, retaining deferred run boundaries.
        '''
        out.append(f'''
    def attempt_tap[{', '.join(parameters([c]))}](deinit self, {c.argument}) raises {error} -> Piped[{runner}.Out] where {' and '.join(where)}:
        """{doc}"""
        comptime assert _ErrorCompatible[{error}, {runner}.Error]
        var value = self^.get()
        try:
            return Piped({runner}.apply(value^, {c.build}))
        except raised:
            _propagate_error[{error}](raised^)
''')
    return ''.join(out)
