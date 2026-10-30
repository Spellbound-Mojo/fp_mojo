from fp.algebra import OptionalFamily,ResultFamily,StringMonoid,traverse,sequence
from fp.effects import Reader,State,WriterT,writer,run,run_writer
from fp.functions import pipeline,piped
from fp.data import Result,Ok,Err
from std.testing import assert_equal

comptime R=Reader[Int]
comptime S=State[Int]
comptime W=WriterT[R,StringMonoid]

def read(var value:Int) raises Int ->R.Pure[Int]:
    if value<0:raise 37
    return R.pure(value+1)

def state(var value:Int)->S.Pure[Int]:return S.pure(value+2)

def logged(var value:Int)->W.Pure[Int]:
    return writer[W,Int](R.pure(Tuple(String("recorded"),value)))

def main() raises:
    var env=0
    var free_output=Optional[Int]()
    var output=Optional[Int]()
    var construction_error=0
    try:
        var free=traverse[OptionalFamily,R](Optional(3),read)
        free_output=run[R](free^,env)
        var selected=pipeline(Optional(3)).raising[Int]().traverse[R](read).get()
        output=run[R](selected^,env)
    except error:
        comptime assert type_of(error)==Int
        construction_error=error
    assert_equal(construction_error,0)
    assert_equal(free_output.take(),4)
    assert_equal(output.take(),4)
    var legacy=piped(Optional(3)).traverse[S](state).get()
    var result=run[S](legacy^,10)
    assert_equal(result[0].take(),5)
    assert_equal(result[1],10)
    var seq=sequence[OptionalFamily,R](Optional(R.pure(9)))
    var seq_result=run[R](seq^,env)
    assert_equal(seq_result.take(),9)
    var result_seq=pipeline(Result[R.Pure[Int],String](Ok(R.pure(7)))).sequence[R]().get()
    var result_output=run[R](result_seq^,env)
    assert_equal(result_output^.raise_on_err(),7)
    var caught=0
    try:_=pipeline(Optional(-1)).raising[Int]().traverse[R](read).get()
    except error:caught=error
    assert_equal(caught,37)
    for present in [False,True]:
        var source=Optional(4) if present else Optional[Int]()
        var written=pipeline(source^).traverse[W](logged).get()
        var deferred_log=run_writer[W](written^)
        var logged_output=run[R](deferred_log^,env)
        assert_equal(logged_output[0],"recorded" if present else "")
        assert_equal(Bool(logged_output[1]),present)
        if present:assert_equal(logged_output[1].value(),4)
