"""Build an importable package and execute a client before reporting success.

Source delivery preserves the canonical module paths and all generic code.
Single-file precompilation is explicit: creation alone does not establish that
the resulting package can be used by the pinned compiler.
"""
import argparse
from dataclasses import asdict
from pathlib import Path
import platform
import shutil
import uuid

from docs_contract import data
from fp_tools.artifacts import library_inputs, manifest
from fp_tools.cases import CompileCase, audit_case, execute_case
from fp_tools.runs import RunContext
from fp_tools.library import precompile
from fp_tools.runtime import ROOT, accepted, input_changes, sha, write_json


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output')
    parser.add_argument('--format', choices=('source', 'precompiled'), default='source',
                        help='Source package (default) or single-file Mojo bytecode')
    args = parser.parse_args()
    run = RunContext.start(args.output or f'.cache/packages/{uuid.uuid4().hex}',
                           'package')
    memory_limit = 4096 * 1024 * 1024 if platform.system() == 'Linux' else None
    built = None
    if args.format == 'source':
        # Copy only production Mojo modules, preserving their import paths. Do
        # not symlink back into the checkout or embed experiments/build products.
        canonical = {path: digest for path, digest in library_inputs('src').items()
                     if Path(path).suffix == '.mojo'}
        for path in canonical:
            source = Path(path)
            destination = run.folder/source.relative_to(ROOT/'src')
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
        expected = {str(run.folder/Path(path).relative_to(ROOT/'src')): digest
                    for path, digest in canonical.items()}
        created = bool(expected) and library_inputs(run.folder) == expected
        include, source_package = run.folder, run.folder/'fp'
        # Check the entire package, including modules outside the smoke client's
        # imports. Keep this bytecode with verification products, away from the
        # include directory: source clients must never resolve it accidentally.
        bytecode = run.binaries/'fp.mojoc'
    else:
        created = False
        include, source_package = 'src', 'src/fp'
        bytecode = run.folder/'fp.mojoc'
    if created or args.format == 'precompiled':
        built = precompile(bytecode, run.folder/'package.log', include=include,
                           source=source_package, timeout=60, timed=True,
                           memory_limit_bytes=memory_limit)
        if args.format == 'precompiled':
            created = accepted(built) and bytecode.is_file()

    packaged = library_inputs(run.folder)
    records = []
    if created and packaged and built is not None and accepted(built):
        source = 'docs/examples/algebra_core.mojo'
        expected = data('examples.json')['examples'][source]['stdout']
        case = CompileCase.from_source(source, 3, include=str(run.folder),
                                       expected_stdout=expected, compiler_threads=2,
                                       compile_timeout=60, measured=True,
                                       memory_limit_bytes=memory_limit)
        binary = run.binaries/'algebra_core'
        result = execute_case(case, binary, run.folder/'client')
        failures = audit_case(case, result, binary, folder=run.folder)
        records.append(dict(specification=asdict(case), **result, audit_failures=failures))

    report = dict(**run.metadata(), format=args.format, include_directory=str(run.folder),
                  artifact_created=created, compilation=built, library_inputs=packaged,
                  library_changes=input_changes(packaged, library_inputs(run.folder)),
                  verification_scope='Full-package precompilation and native core example at O3; not full library qualification',
                  example_manifest_sha256=sha(ROOT/'docs/examples.json'), records=records)
    report['passed'] = (created and bool(records) and report['inputs_unchanged']
                        and not report['library_changes']
                        and all(r['passed'] and not r['audit_failures'] for r in records))
    report['artifact_sha256'] = manifest(run.folder)
    write_json(run.folder / 'report.json', report)
    if report['passed']:
        print(f'{args.format} package ready: {run.folder}')
        print('Full-package precompilation passed; native core client ran at O3 with its expected output.')
    else:
        print('Package verification failed. See', run.folder/'report.json')
        if created:
            print('The artifact was created, but package/client verification did not pass.')
        if built is not None and not accepted(built):
            print(built['stdout'] + built['stderr'])
    return not report['passed']


if __name__ == '__main__':
    raise SystemExit(main())
