"""Documentation for the native admission signatures of derived combinators."""
import re
from api_docs import parse_signature

NAMES = frozenset({'ap', 'fold_effect', 'any_effect', 'all_effect', 'if_effect', 'find_effect', 'find_map_effect', 'fold_map_effect', 'sequence_filter', 'fill', 'replace', 'void', 'tuple_left', 'tuple_right', 'pair_with',
                   'tap_each', 'tap', 'filter_map', 'compact', 'find_map', 'fold_map',
                   'combine_all', 'sum', 'sum_by', 'min_by', 'max_by', 'flat_map',
                   'flatten', 'traverse', 'sequence', 'map2', 'product', 'traverse_void', 'traverse_tap', 'sequence_void', 'flat_traverse', 'flat_sequence', 'traverse_filter', 'filter_effect', 'par_traverse', 'par_sequence'})
PARAMETERS = {
    'Z': 'The exact construction error for generic fold forwarding; checked without converting errors.',
    'Y': 'The exact native error type of the true branch.',
    'D': 'The exact native error type of the false branch.',
    'q': 'The origin of the borrowed false-branch factory.',
    'L': 'The true-branch factory, retaining its native error and receiver mode.',
    'S': 'The Traversable source family, preserving its native shape and origins.',
    'X': 'The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.',
    'B': 'The second callback input type, including its origins.',
    'W': 'The second carrier type, including its origins.',
    'T': 'The element type, including its native origins.',
    'U': 'The constant or result payload type; repeated constants must be Copyable.',
    'A': 'The callback input type, including its native origins.',
    'P': 'The borrowed callback payload type, including its native origins.',
    'R': 'The native callback result type.',
    'F': 'The callback type, retaining its receiver, captures and error contract.',
    'C': 'The borrowing library callback type.',
    'V': 'The consumed source or carrier type.',
    'G': 'The target Applicative family; it determines effect sequencing and failure.',
    'M': 'The Monoid providing the result type, identity and ordered combination.',
    'o': 'The origin of the borrowed native callback.',
    'E': 'The exact native callback error type.',
    'dtype': 'The numeric SIMD element dtype, inferred from the payload or callback result.',
    'size': 'The native SIMD lane count; lanes are added independently.',
    'N': 'The native array length, preserved by mapping.',
    'K': 'The native dictionary key type.',
    'H': 'The native dictionary hasher.',
    'Failure': 'The error payload type retained by Result.',
}
RETURNS = {
    'sequence_filter': 'The target effect containing present Optional payloads in source shape, using identity traverse_filter; effect failure remains distinct from discarded absence.',
    'find_effect': 'The target effect of Optional, stopping each live branch at its first accepted original element; empty input lifts None.',
    'find_map_effect': 'The target effect of the first present Optional in each live branch; empty input lifts None and target failure stays in the effect.',
    'fold_map_effect': 'The target effect of ordered monoid combination. Identity is constructed before source binding, including for deferred targets; callbacks and combinations follow the target timing.',

    'par_sequence': 'A Result containing unwrapped payloads in source shape (List for Iter), or stored errors accumulated in source order. An empty source succeeds; a source Result error stays inside the target Result.',
    'par_traverse': 'A Result containing the transformed source shape (List for Iter), or stored errors accumulated in source order. Every finite input is visited unless a native error is raised.',
    'ap': 'The carrier of callback results. List applies each callback to each value in function-major order; Optional and Result invoke at most once.',
    'fold_effect': 'The target effect containing the final accumulator; empty input lifts the initial value.',
    'any_effect': 'The target effect of Bool, stopping each branch at True; empty input lifts False.',
    'all_effect': 'The target effect of Bool, stopping each branch at False; empty input lifts True.',
    'if_effect': 'The selected branch effect; absence or failure in the condition skips both factories.',
    'filter_effect': 'The target effect containing original elements whose effectful Bool predicate succeeds with True; False discards an element and target failure follows the effect.',
    'sequence_void': 'The target effect of NoneType; existing source errors stay inside the target effect.',
    'flat_traverse': 'The target effect containing the flattened source shape. The callback produces a target effect of the same source family.',
    'flat_sequence': 'The target effect containing the source shape after sequencing effects and flattening one source-family layer.',
    'traverse_filter': 'The target effect containing present Optional results in source shape; absence discards an element and target failure follows the effect.',

    'traverse_void': 'The target effect of NoneType, without an output collection. Target failures follow the effect.',
    'traverse_tap': 'The target effect containing the original payloads, gathered in a List.',
    'map2': 'The combined carrier; Result keeps the first stored error, Optional requires both values, and List produces a Cartesian product in left-major order.',
    'product': 'The carrier of pairs. List copies elements for its Cartesian product; Result and Optional move their payloads without copying.',
    'fill': 'The source shape with a copy of value at each payload position; empty input stays empty.',
    'replace': 'The source shape with matching elements replaced and unmatched elements moved unchanged.',
    'void': 'The source shape with NoneType payloads; a lazy iterator is not drained.',
    'tuple_left': 'The source shape containing a copied constant followed by each original element.',
    'tuple_right': 'The source shape containing each original element followed by a copied constant.',
    'pair_with': 'The source shape containing each original element beside its borrowed projection.',
    'tap_each': 'The original elements after inspection; callback results are discarded.',
    'tap': 'The unchanged whole pipeline value, after one inspection call.',
    'filter_map': 'The carrier of present transformed Optional payloads, in source order.',
    'compact': 'The carrier of unwrapped present Optional payloads, in source order.',
    'find_map': 'The first present Optional result, or absence; no later element is pulled.',
    'fold_map': 'The projected values combined in order, or the monoid identity on empty input.',
    'combine_all': 'The values combined in order, or the monoid identity on empty input.',
    'sum': 'The ordered sum from zero, preserving the numeric type and SIMD lanes.',
    'sum_by': 'The ordered sum of projections from zero, without a mapped intermediate collection.',
    'min_by': 'An Optional containing the element with the smallest key; ties retain the first element.',
    'max_by': 'An Optional containing the element with the largest key; ties retain the first element.',
    'flat_map': 'The family result of transforming and flattening one level.',
    'flatten': 'The result of removing one nesting level according to the family.',
    'traverse': 'The target effect containing transformed payloads; Iter and direct calls gather a List.',
    'sequence': 'The target effect containing unwrapped payloads; Iter and direct calls gather a List.',
}


def document_first_methods(source, names=NAMES):
    """Document the first admission form for each owner/name; preserve full docs."""
    lines = source.splitlines(keepends=True)
    owner, seen, edits = '', set(), []
    for index, line in enumerate(lines):
        declared = re.match(r'^(?:struct|trait) (\w+)', line)
        if declared:
            owner = declared[1]
        match = re.match(r'^( *)def (\w+)\[?', line)
        if not match or match[2] not in names:
            continue
        indent, name = match.groups()
        key = (owner if indent else '', name)
        if key in seen:
            continue
        seen.add(key)
        end = index
        while not lines[end].rstrip().endswith(':'):
            end += 1
        doc_start = end + 1
        if '"""' not in lines[doc_start]:
            continue
        doc_end = doc_start
        if lines[doc_start].count('"""') < 2:
            doc_end += 1
            while '"""' not in lines[doc_end]:
                doc_end += 1
        old = ''.join(lines[doc_start:doc_end + 1])
        if 'Parameters:' in old or 'Returns:' in old:
            continue
        signature = ' '.join(line.strip() for line in lines[index:end + 1]).removesuffix(':')
        parsed = parse_signature(signature)
        prefix = indent + '    '
        body = old.rstrip().removesuffix('"""').rstrip()
        sections = []
        if parsed['parameters']:
            sections.append('Parameters:')
            for p in parsed['parameters']:
                description = PARAMETERS.get(p['name'])
                if p['name'] == 'I':
                    description = ('The explicit capability family, including its result and error semantics.'
                                   if any(t in p['type'] for t in ('Functor', 'Monad', 'Traversable', 'Applicative')) else
                                   'The native source type: an iterator at its current position or an owned iterable.')
                if name in {'par_traverse', 'par_sequence'} and p['name'] == 'S':
                    description = 'The error Semigroup; defaults to concatenation of list-valued stored errors.'
                if name in {'fold_effect', 'any_effect', 'all_effect', 'if_effect', 'find_effect', 'find_map_effect', 'fold_map_effect'}:
                    if p['name'] == 'G':
                        description = 'The target Monad family; it determines dependent sequencing and failure.'
                    elif p['name'] == 'X':
                        description = ('The exact native step error type.' if name == 'fold_effect' else
                                       'The exact construction error for generic forwarding; checked without converting errors.')
                    elif p['name'] == 'R' and name == 'if_effect':
                        description = 'The false-branch factory, retaining its native error and receiver mode.'
                    elif p['name'] in ('U', 'W') and name == 'if_effect':
                        description = 'The complete branch effect type, including its native origins.'
                    elif p['name'] == 'N':
                        description = 'The native array length; the source moves through temporary List storage.'
                if description is None:
                    raise ValueError(f'Undescribed parameter {p["name"]} in {name}')
                sections.append(f'    {p["name"]}: {description}')
            sections.append('')
        if parsed['arguments']:
            sections.append('Args:')
            for a in parsed['arguments']:
                arg = a['name']
                if arg in ('function', 'f'):
                    ownership = 'consumed' if a['convention'] == 'var' else 'borrowed in place'
                    description = f'The callback, {ownership}; calls follow the operation\'s evaluation order.'
                elif arg == 'source' or (arg == 'value' and name in {'compact', 'filter_map'}):
                    description = 'The source, consumed with its native origins; iterator sources are not restarted.'
                elif arg == 'values': description = 'The already evaluated carrier of callback arguments, consumed.'
                elif arg == 'initial': description = 'The initial accumulator, consumed.'
                elif arg in ('on_true', 'on_false'):
                    ownership = 'consumed' if a['convention'] == 'var' else 'borrowed in place'
                    description = f'The branch factory, {ownership}; invoked only for its selected Bool outcome.'
                elif arg == 'condition': description = 'The effect containing Bool, consumed.'
                elif arg == 'other': description = 'The already evaluated second carrier, consumed. Constructing it is not deferred by this call.'
                elif arg == 'old': description = 'The value to compare against each payload, consumed.'
                elif arg == 'new': description = 'The replacement, consumed and copied only for matching payloads.'
                else: description = 'The constant, consumed and copied once per emitted payload.'
                sections.append(f'    {arg}: {description}')
            sections.append('')
        sections += ['Returns:', '    '+RETURNS[name]]
        if parsed['error']:
            sections += ['', 'Raises:', '    The exact callback, monoid or family error; Never for a non-raising operation.']
        new = body + '\n\n' + '\n'.join(prefix + x if x else '' for x in sections) + '\n' + prefix + '"""\n'
        edits.append((doc_start, doc_end + 1, new))
    for begin, end, replacement in reversed(edits):
        lines[begin:end] = [replacement]
    return ''.join(lines)
