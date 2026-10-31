"""Reviewed migration coverage over the existing public export inventory."""
from collections import Counter

from fp_tools.runtime import ROOT


def audit_compatibility(catalog, exports, root=ROOT):
    assert catalog['version'] == 1, 'Unknown compatibility catalog version'
    assert set(catalog['packages']) == set(exports['modules']), 'Unclassified public package'
    for package, entry in catalog['packages'].items():
        assert entry['scope'] and entry['restrictions'] and entry['evidence'], package
        for path in entry['evidence']:
            assert (root / path).is_file(), f'Missing compatibility evidence: {path}'

    pipeline = set(exports['exports']['functions.Pipeline']['methods'])
    # The retired Piped surface's methods, recorded in the catalog: each must
    # have a Pipeline replacement or a pending migration group.
    legacy = set(catalog['legacy_methods'])
    covered = []
    for group in catalog['pipeline']:
        assert group['status'] in ('selected', 'result_only'), group['name']
        for field in ('families', 'callbacks', 'ownership', 'errors', 'timing', 'owner', 'evidence'):
            assert group[field], f'Missing {field}: {group["name"]}'
        for path in group['owner'] + group['evidence']:
            assert (root / path).is_file(), f'Missing compatibility source: {path}'
        covered.extend(group['methods'])
    assert set(covered) == pipeline, 'Unclassified Pipeline method'
    assert all(n == 1 for n in Counter(covered).values()), 'Multiply classified Pipeline method'
    pending = [name for group in catalog['migration'] for name in group['methods']]
    assert set(pending) == legacy - pipeline, 'Incomplete Pipeline migration inventory'
    assert all(n == 1 for n in Counter(pending).values()), 'Duplicate migration assignment'
    for path in catalog['legacy_diagnostic_controls']:
        assert (root / path).is_file(), f'Missing legacy diagnostic control: {path}'
    return dict(packages=len(catalog['packages']), pipeline=len(pipeline),
                legacy=len(legacy), pending=len(pending))


def compatibility_markdown(section, catalog):
    def table(headers, rows):
        return '\n'.join(['| ' + ' | '.join(headers) + ' |',
                          '| ' + ' | '.join('---' for _ in headers) + ' |',
                          *['| ' + ' | '.join(row) + ' |' for row in rows]]) + '\n'
    names = lambda values: ', '.join('`' + value + '`' for value in values)
    if section == 'packages':
        return table(('Package', 'Checked scope', 'Restrictions and next work'),
                     [(f'`fp.{name}`', item['scope'], item['restrictions'])
                      for name, item in catalog['packages'].items()])
    if section == 'pipeline':
        return table(('Operations', 'Family / status', 'Ownership and evaluation', 'Errors'),
                     [(names(g['methods']), g['families'] + ' (' + g['status'] + ')',
                       g['ownership'] + ' ' + g['timing'], g['errors']) for g in catalog['pipeline']])
    if section == 'migration':
        return table(('Pass', 'Legacy operations awaiting Pipeline admission', 'Execution contract'),
                     [(g['name'], names(g['methods']), g['contract']) for g in catalog['migration']])
    if section in ('qualification', 'current-qualification'):
        checkpoint = 'current' if section == 'current-qualification' else 'baseline'
        return table(('Check', 'Result', 'Scope'),
                     [(g['check'], g['result'], g['scope']) for g in catalog[checkpoint]['checks']])
    raise ValueError('Unknown compatibility section: ' + section)
