"""Bind retained raw artifacts independently of report success flags."""
from .runtime import ROOT, sha, input_changes, normalized


def library_inputs(include, root=ROOT):
    """Bind the actual library selected by an include directory, even in .cache."""
    directory = (root/include).resolve()
    paths = list((directory/'fp').rglob('*.mojo'))
    paths += [directory/name for name in ('fp.mojoc', 'fp.mojopkg')
              if (directory/name).is_file()]
    return {str(path): sha(path) for path in sorted(paths)}


def library_binding(include, before, root=ROOT):
    """Retain the selected library snapshot and changes across a run."""
    return dict(library_inputs=before,
                library_changes=input_changes(before, library_inputs(include, root)))


def audit_library_binding(report, *, include, expected_inputs, root=ROOT):
    """Recheck source/package bytes independently of reported change flags."""
    def canonical(snapshot):
        return {normalized(path, root): digest for path, digest in snapshot.items()}
    try:
        expected = canonical(expected_inputs)
        if (not expected or canonical(report.get('library_inputs', {})) != expected
                or report.get('library_changes') != []
                or canonical(library_inputs(include, root)) != expected):
            return ['missing/stale/changed selected library binding']
    except (AttributeError, TypeError, OSError):
        return ['invalid selected library binding']
    return []


def manifest(folder):
    return {str(p.relative_to(folder)): sha(p) for p in sorted(folder.rglob('*'))
            if p.is_file() and p != folder/'report.json'}


def audit(report, folder):
    recorded = report.get('artifact_sha256')
    if not isinstance(recorded, dict) or not recorded or recorded != manifest(folder):
        return ['missing/changed/uninventoried retained artifacts']
    return []
