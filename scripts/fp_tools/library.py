"""Select the fp library a verification run compiles against."""
from pathlib import Path

from .runtime import ROOT, accepted, command


def add_library_arguments(parser):
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--package', help='A directory holding a built fp package (fp.mojoc or fp/), '
                                         'such as the output of pixi run build')
    group.add_argument('--source', action='store_true', help='Compile against src/ instead of a package')


def precompile(output, log, *, include='src', source='src/fp', timeout=180, **policy):
    """Precompile the whole library with --Werror; the caller judges the record."""
    return command(['mojo', 'precompile', '-I', include, '--Werror', source, '-o', output],
                   log, timeout=timeout, **policy)


def library_include(args, folder, *, timeout=180):
    """The include directory for --package, --source or a fresh precompiled package.

    Returns (include, precompilation record or None when an existing library is used).
    """
    if args.source:
        return 'src', None
    if args.package:
        directory = (ROOT / args.package).resolve()
        if not directory.is_relative_to(ROOT):
            raise SystemExit('The package directory must be inside the project')
        if not ((directory / 'fp.mojoc').is_file() or (directory / 'fp' / '__init__.mojo').is_file()):
            raise SystemExit(f'No fp package (fp.mojoc or fp/) in {args.package}')
        return str(directory), None
    directory = Path(folder) / 'package'
    directory.mkdir()
    built = precompile(directory / 'fp.mojoc', Path(folder) / 'package.log', timeout=timeout)
    if not accepted(built):
        raise SystemExit('Package precompilation failed:\n' + built['stdout'] + built['stderr'])
    return str(directory), built
