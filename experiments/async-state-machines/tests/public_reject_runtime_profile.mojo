# error: no matching function in initialization
from fp.effects.async_runtime import IO, Profile, Runtime


def main() raises:
    # A runtime takes a whole configuration; a profile is one of its fields.
    var runtime = Runtime(Profile.current_thread())
    _ = runtime.run(IO[Int, Int].pure(1))
