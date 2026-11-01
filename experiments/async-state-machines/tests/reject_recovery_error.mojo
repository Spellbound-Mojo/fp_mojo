# error: no matching method in call to 'handle_error_with'
from fp.effects import EffectFailure
from fp.effects._async.engine import IO
from recovery_support import source

def wrong(var error: EffectFailure[Int]) raises String -> IO[Int, Int]:
    raise String("foreign error")
def main():
    _ = source(2).handle_error_with(wrong)
