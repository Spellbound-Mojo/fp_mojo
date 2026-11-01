"""Re-audit a finished qualification bundle, then write its committed summary.

Run from the clean checkout that produced the bundle. The bundle's own runner
audits it first; nothing is written unless every check passes:

    pixi run python scripts/retain_evidence.py --kind qualification \
        --bundle .cache/pass14-gate-pool --label pass14-gate-pool

Commit the summary written under docs/content/architecture/evidence/.
"""
import argparse
from pathlib import Path
import sys

from fp_tools.evidence import KINDS, retain
from fp_tools.runtime import ROOT

EXPERIMENT = ROOT / 'experiments/async-state-machines'


def auditor(kind):
    """Each runner owns the audit of its report format."""
    if kind == 'documentation-examples':
        from verify_docs_examples import audit_report
        return audit_report
    sys.path.insert(0, str(EXPERIMENT))
    if kind == 'qualification':
        from qualify import audit_report
    else:
        from stress import audit_report
    return audit_report


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--kind', choices=KINDS, required=True)
    parser.add_argument('--bundle', required=True, help='The finished run directory')
    parser.add_argument('--label', required=True, help='The summary name: lowercase words joined by hyphens')
    parser.add_argument('--host-load', help='The host load while the run ran, as noted by its operator')
    args = parser.parse_args()
    if Path.cwd().resolve() != ROOT:
        parser.error('Run from the repository root')
    failures = retain(args.kind, args.label, (ROOT / args.bundle), auditor(args.kind), host_load=args.host_load)
    print('RETAINED' if not failures else 'NOT RETAINED', failures)
    return bool(failures)


if __name__ == '__main__':
    raise SystemExit(main())
