# error: no matching function
from fp.effects import EffectFailure
from fp.effects._async.composition import Pure, pure
from fp.effects._async.recovery import handle_error_with
from recovery_support import source

def wrong(var error: EffectFailure[Int]) raises String -> Pure[Int, Int]:
    raise String("foreign error")
def main():
    _ = handle_error_with(source(2), wrong)
