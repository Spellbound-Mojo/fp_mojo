"""Admission for fluent applicative combination; execution belongs to families."""

# Mojo 1.1 can erase mismatched embedded origins in a late ResultFamily
# assertion. A generic call on a held Result compares the other operand's native
# shape at admission, as the native Result signatures do.
def _result_boundary(other):
    error = 'downcast[Self.Value, _ResultType].Error'
    same = f'(({other} == Result[downcast[{other}, _ResultType].Value, {error}]) if conforms_to({other}, _ResultType) else False)'
    return f' and ({same} if conforms_to(Self.Value, _ResultType) else True)'
from combinator_docs import document_first_methods
from native_signatures import MD, callable_protocol, native_adapter, closure, source_default, defaulted



def methods(carrier=None, result=False):
    out=[]
    for kind in ('library', 'pure', 'raising'):
        native=kind!='library'
        params=([f'A: {MD}',f'B: {MD}',f'R: {MD}','o: ImmOrigin'] if native else [f'F: {callable_protocol("binary")} & {MD}'])
        a,b,r=('A','B','R') if native else ('F.First','F.Second','F.Out')
        # Infer the carrier independently of the native signature on Mojo 1.2;
        # its exact payload and origins remain an admission constraint below.
        independent_carrier = carrier or (result and not native)
        if independent_carrier: params += [f'W: {MD}']
        if carrier: params+=list(carrier.parameters)
        if not carrier and not result: params += [f'W: {MD}']
        error='X' if kind=='raising' else 'Never'
        if native:
            # Closures come from the shared catalog.
            form = closure('binary', kind == 'raising', names={'C': 'F', 'X': error, 'in0': 'A', 'in1': 'B'})
        if not carrier and not result:
            # The family defaults to the held value's; the callback parameters follow.
            params += ['//', 'I: Applicative = ' + source_default('Applicative', 'Self.Value'), *defaulted(form.explicit if native else ())]
        else:
            params += ['//', *(form.explicit if native else ())]
        cb=form.type if native else 'F'
        build=form.build if native else 'function^'
        if result:
            left=f'Result[{a}, Self.E]';right=f'Result[{b}, Self.E]';output=f'Result[{r}, Self.E]'
            raised=error if native else 'F.Error'
            condition=f'Self.T == {a}'
            body=f'return _result_map2[Self.E, X={raised}]({build}, rebind_var[{left}](self^), _ValueThunk(other^))'
        else:
            family=carrier.instance(a) if carrier else 'I'
            left=carrier.value(a) if carrier else 'Self.Value'
            right=carrier.value(b) if carrier else 'W'
            contract = f'Map2Contract[{family}, {left}, {right}, {cb}]' if not native and not carrier else None
            if contract:
                output, raised = contract + '.Out', contract + '.Error'
                condition = contract + '.InputCompatible'
            else:
                output=carrier.value(r) if carrier else f'{family}.Combined[{left}, {cb}, _ValueThunk[{right}]]'
                raised=(error if native else 'F.Error') if carrier else f'I.CombineError[{left}, {cb}, _ValueThunk[{right}]]'
                condition=f'Self.Value == {left}' if carrier else f'I.Element[Self.Value] == {a} and I.Element[W] == {b}'
            if not carrier or carrier.name == 'List':
                condition += ' and ' + (contract + '.OperationCompatible' if contract else
                                       f'_CombineCompatible[{family}, {left}, {cb}, _ValueThunk[{right}]]')
            if not carrier:
                condition = f'({condition})' + _result_boundary('W')
            value=f'rebind_var[{left}](self.value^)' if carrier else 'self.value^'
            body=f'return Piped(_map2_as[{family}, X={raised}]({build}, {value}, other^))'
            output=f'Piped[{output}]'
        if independent_carrier:
            condition += f' and W == {right}'
            body = body.replace('other^', f'rebind_var[{right}](other^)')
            right = 'W'
        out.append(f'''
    def map2[{', '.join(params)}](deinit self, var other: {right}, {'ref[o]' if native else 'var'} function: F) raises {raised} -> {output} where {condition}:
        """Combine two already evaluated carriers, following their Applicative semantics."""
        {body}
''')
    if result:
        params=[f'U: {MD}']; right='Result[U, Self.E]';output='Result[Tuple[Self.T, U], Self.E]';where=''
        body='return self^.map2(other^, _Pair[Self.T, U]())';raised=''
    else:
        params=[f'T: {MD}',f'U: {MD}',*carrier.parameters] if carrier else [f'W: {MD}','//','I: Applicative = ' + source_default('Applicative', 'Self.Value')]
        left=carrier.value('T') if carrier else 'Self.Value';right=carrier.value('U') if carrier else 'W'
        family=carrier.instance('T') if carrier else 'I'
        cb=f'_Pair[{family}.Element[{left}], {family}.Element[{right}]]'
        contract = f'ProductContract[I, {left}, {right}]' if not carrier else None
        output='Piped['+(carrier.value('Tuple[T, U]') if carrier else contract + '.Out')+']'
        where=f' where Self.Value == {left}' if carrier else f' where ({contract}.OperationCompatible)' + _result_boundary('W')
        if carrier and carrier.name == 'List':
            where += f' and _CombineCompatible[{family}, {left}, {cb}, _ValueThunk[{right}]]'
        value=f'rebind_var[{left}](self.value^)' if carrier else 'self.value^'
        body=f'return Piped(_family_product[{family}]({value}, other^))'
        if carrier and carrier.name == 'List':
            # Fixed native result/error types use the same checked bridge as map2.
            body=f'return Piped(_map2_as[{family}, X=Never]({cb}(), {value}, other^))'
        raised='' if carrier else f' raises {contract}.Error'
    out.append(f'''
    def product[{', '.join(params)}](deinit self, var other: {right}){raised} -> {output}{where}:
        """Combine two already evaluated carriers into pairs, following their Applicative semantics."""
        {body}
''')
    return document_first_methods(''.join(out) + ap_method(carrier, result))


def ap_method(carrier=None, result=False):
    if result:
        function = 'downcast[Self.T, UnaryContract & Movable & Deinitable]'
        params = [f'W: {MD}']
        right = 'W'
        admitted = f'Result[{function}.Arg, Self.E]'
        output = f'Result[{function}.Out, Self.E]'
        raised = f'{function}.Error'
        condition = f'conforms_to(Self.T, UnaryContract) and W == {admitted}'
        body = f'return _result_map2[Self.E, X={raised}](_Apply[{function}](), rebind_var[Result[{function}, Self.E]](self^), _ValueThunk(rebind_var[{admitted}](values^)))'
    elif carrier:
        family = carrier.instance('A')
        function = f'downcast[{family}.Element[Self.Value], UnaryContract & {MD}]'
        params = [f'A: {MD}', *carrier.parameters]
        left, right = carrier.value(function), carrier.value('A')
        output = f'Piped[{carrier.value(function + ".Out")}]'
        raised = f'{function}.Error'
        condition = f'conforms_to({family}.Element[Self.Value], UnaryContract) and Self.Value == {left} and A == {function}.Arg'
        if carrier.name == 'List':
            condition += f' and _CombineCompatible[{family}, {left}, _Apply[{function}], _ValueThunk[{carrier.value(function + ".Arg")}]]'
        body = f'return Piped(_map2_as[{family}, X={raised}](_Apply[{function}](), rebind_var[{left}](self.value^), rebind_var[{carrier.value(function + ".Arg")}](values^)))'
    else:
        contract = 'ApContract[I, Self.Value, W]'
        params = [f'W: {MD}', '//', 'I: Applicative = ' + source_default('Applicative', 'Self.Value')]
        right = 'W'
        cb = f'_Apply[{contract}.Function]'
        output = f'Piped[{contract}.Out]'
        raised = contract + '.Error'
        # Admission checks repetition and copying too, as the native carriers did.
        condition = f'({contract}.InputCompatible and {contract}.OperationCompatible)' + _result_boundary('W')
        body = f'return Piped(_map2_as[I, X={raised}]({cb}(), self.value^, values^))'
    parameters = '[' + ', '.join(params) + ']' if params else ''
    return f'''
    def ap{parameters}(deinit self, var values: {right}) raises {raised} -> {output} where {condition}:
        """Apply the callbacks in this carrier to an already evaluated carrier of arguments."""
        {body}
'''
