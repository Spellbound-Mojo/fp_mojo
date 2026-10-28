# error: use of uninitialized value
from shared_sequencing_support import Factory
from fp.effects import Reader,run
from fp.functions import pipeline
from std.memory import ArcPointer
def main():
    comptime R=Reader[Int]
    var factory=Factory(ArcPointer(0),False)
    var pending=pipeline[R](R.pure(4)).before(factory).get()
    var moved=factory^
    _=moved.fail
    try: _=run[R](pending^,0)
    except: pass
