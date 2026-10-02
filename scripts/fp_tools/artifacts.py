"""Bind retained raw artifacts independently of report success flags."""
from .runtime import ROOT, sha


def library_inputs(include):
    """Bind the actual library selected by an include directory, even in .cache."""
    directory = (ROOT/include).resolve()
    paths = list((directory/'fp').rglob('*.mojo'))
    paths += [directory/name for name in ('fp.mojoc', 'fp.mojopkg')
              if (directory/name).is_file()]
    return {str(path): sha(path) for path in sorted(paths)}


def manifest(folder):
    return {str(p.relative_to(folder)): sha(p) for p in sorted(folder.rglob('*'))
            if p.is_file() and p != folder/'report.json'}


def audit(report, folder):
    recorded = report.get('artifact_sha256')
    if not isinstance(recorded, dict) or not recorded or recorded != manifest(folder):
        return ['missing/changed/uninventoried retained artifacts']
    return []
