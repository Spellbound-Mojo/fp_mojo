"""Admission for fluent applicative combination; execution belongs to families."""
from combinator_docs import document_first_methods

MD = 'Movable & Deinitable'


def methods(carrier=None, result=False):
    out=[]
    for kind in ('library', 'pure', 'raising'):
        native=kind!='library'
        params=([f'A: {MD}',f'B: {MD}',f'R: {MD}','o: ImmOrigin'] if native else [f'F: BinaryContract & {MD}'])
        a,b,r=('A','B','R') if native else ('F.First','F.Second','F.Out')
        if not native and (carrier or result): params += [f'W: {MD}']
        if carrier: params+=list(carrier.parameters)
        if not carrier and not result: params += [f'W: {MD}']
        params += ['//']
        if not carrier and not result: params += ['I: Applicative']
        error='X' if kind=='raising' else 'Never'
        if kind=='raising': params += [f'{error}: {MD}']
        if native: params += [f'F: _RaisingBinary[A, B, R, {error}]' if kind=='raising' else 'F: _Binary[A, B, R]']
        cb=f'_NativeBinaryRef[A, B, R, {error}, F, {kind=="raising"}, o]' if native else 'F'
        build=f'{cb}(Pointer(to=function))' if native else 'function^'
        if result:
            left=f'Result[{a}, Self.E]';right=f'Result[{b}, Self.E]';output=f'Result[{r}, Self.E]'
            raised=error if native else 'F.Error'
            condition=f'Self.T == {a}'
            body=f'return _result_map2[Self.E, X={raised}]({build}, rebind_var[{left}](self^), _ValueThunk(other^))'
        else:
            family=carrier.instance(a) if carrier else 'I'
            left=carrier.value(a) if carrier else 'Self.Value'
            right=carrier.value(b) if carrier else 'W'
            output=carrier.value(r) if carrier else f'{family}.Combined[{left}, {cb}, _ValueThunk[{right}]]'
            raised=(error if native else 'F.Error') if carrier else f'I.CombineError[{left}, {cb}, _ValueThunk[{right}]]'
            condition=f'Self.Value == {left}' if carrier else f'I.Element[Self.Value] == {a} and I.Element[W] == {b}'
            if not carrier: condition += f' and _CombineCompatible[I, {left}, {cb}, _ValueThunk[{right}]]'
            value=f'rebind_var[{left}](self.value^)' if carrier else 'self.value^'
            body=f'return Piped(_map2_as[{family}, X={raised}]({build}, {value}, other^))'
            output=f'Piped[{output}]'
        if not native and (carrier or result):
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
        params=[f'T: {MD}',f'U: {MD}',*carrier.parameters] if carrier else [f'W: {MD}','//','I: Applicative']
        left=carrier.value('T') if carrier else 'Self.Value';right=carrier.value('U') if carrier else 'W'
        family=carrier.instance('T') if carrier else 'I'
        cb=f'_Pair[{family}.Element[{left}], {family}.Element[{right}]]'
        output='Piped['+(carrier.value('Tuple[T, U]') if carrier else f'I.Combined[{left}, {cb}, _ValueThunk[{right}]]')+']'
        where=f' where Self.Value == {left}' if carrier else f' where _CombineCompatible[I, {left}, {cb}, _ValueThunk[{right}]]'
        value=f'rebind_var[{left}](self.value^)' if carrier else 'self.value^'
        body=f'return Piped(_family_product[{family}]({value}, other^))'
        raised='' if carrier else f' raises I.CombineError[{left}, {cb}, _ValueThunk[{right}]]'
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
        body = f'return Piped(_map2_as[{family}, X={raised}](_Apply[{function}](), rebind_var[{left}](self.value^), rebind_var[{carrier.value(function + ".Arg")}](values^)))'
    else:
        function = 'downcast[I.Element[Self.Value], UnaryContract & Movable & Deinitable]'
        params = [f'W: {MD}', '//', 'I: Applicative']
        right = 'W'
        cb = f'_Apply[{function}]'
        output = f'Piped[I.Combined[Self.Value, {cb}, _ValueThunk[W]]]'
        raised = f'I.CombineError[Self.Value, {cb}, _ValueThunk[W]]'
        condition = f'conforms_to(I.Element[Self.Value], UnaryContract) and I.Element[W] == {function}.Arg'
        body = f'return Piped(_map2_as[I, X={raised}]({cb}(), self.value^, values^))'
    parameters = '[' + ', '.join(params) + ']' if params else ''
    return f'''
    def ap{parameters}(deinit self, var values: {right}) raises {raised} -> {output} where {condition}:
        """Apply the callbacks in this carrier to an already evaluated carrier of arguments."""
        {body}
'''
