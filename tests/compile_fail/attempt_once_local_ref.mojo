# error: cannot
from fp.data import Result, attempt_once
from attempt_once_support import Reference


def escape[origin: ImmOrigin](owner: Pointer[String, origin]) -> Result[Pointer[String, origin], Never]:
    var local = String('does not survive')
    return attempt_once(Reference(Pointer(to=local)))


def main():
    var owner = String('survives')
    _ = escape(Pointer(to=owner))
