"""Generic native boundaries retain their read/result ABI and IO witness."""
from fp.effects import IO, IOContract, Outcome, ReaderAction, lift_resource, pure_resource, run_io
from test_resource_thin import RegisterIO, checked, failed, rr, rm, mr, mm
from std.testing import assert_true


def register_input[A: TrivialRegisterPassable, P: ReaderAction](value: A, function: def(A) thin -> P) -> Outcome[P.Value,Int] where IOContract[P].Compatible and IOContract[P].Error == Int and not conforms_to(P, RegisterPassable):
    return run_io(lift_resource(pure_resource[Int](value)).use(function))


def memory_input[A: Movable & Deinitable, P: ReaderAction](var value: A, function: def(A) thin -> P) -> Outcome[P.Value,Int] where IOContract[P].Compatible and IOContract[P].Error == Int and not conforms_to(A,TrivialRegisterPassable) and not conforms_to(P,RegisterPassable):
    return run_io(lift_resource(pure_resource[Int](value^)).use(function))


def register_output[A: TrivialRegisterPassable, P: ReaderAction & RegisterPassable](value: A, function: def(A) thin -> P) -> Outcome[P.Value,Int] where IOContract[P].Compatible and IOContract[P].Error == Int:
    return run_io(lift_resource(pure_resource[Int](value)).use(function))


def memory_to_register[A: Movable & Deinitable, P: ReaderAction & RegisterPassable](var value: A, function: def(A) thin -> P) -> Outcome[P.Value,Int] where IOContract[P].Compatible and IOContract[P].Error == Int and not conforms_to(A,TrivialRegisterPassable):
    return run_io(lift_resource(pure_resource[Int](value^)).use(function))


def projected[P: ReaderAction](function: def(Int) thin -> P) -> Outcome[NoneType,Int] where IOContract[P].Compatible and IOContract[P].Error == Int and not conforms_to(P,RegisterPassable):
    return run_io(lift_resource(pure_resource[Int](17)).eval_map(function).use_void())


def observed[P: ReaderAction](function: def(Int) thin -> P) -> Outcome[Int,Int] where IOContract[P].Compatible and IOContract[P].Error == Int and not conforms_to(P,RegisterPassable):
    return run_io(lift_resource(pure_resource[Int](19)).eval_tap(function).use(rm))


def raising[E: Movable & Deinitable, A: Movable & Deinitable, P: ReaderAction](var value: A, function: def(A) raises E thin -> P) -> Outcome[P.Value,E] where IOContract[P].Compatible and IOContract[P].Error == E and not conforms_to(A,TrivialRegisterPassable) and not conforms_to(P,RegisterPassable):
    return run_io(lift_resource(pure_resource[E](value^)).use(function))


def checked_length(value: String) raises Int -> IO[Int].Pure[Int]:
    if value.byte_length() == 0: raise 71
    return IO[Int].pure(value.byte_length())


def main() raises:
    var rr_pointer: def(Int) thin -> RegisterIO = rr
    var rm_pointer: def(Int) thin -> IO[Int].Pure[Int] = rm
    var mr_pointer: def(String) thin -> RegisterIO = mr
    var mm_pointer: def(String) thin -> IO[Int].Pure[Int] = mm
    checked(register_input(11,rm_pointer),11)
    checked(memory_input(String("word"),mm_pointer),4)
    checked(register_output(13,rr_pointer),13)
    checked(memory_to_register(String("words"),mr_pointer),5)
    var projection = projected(rm_pointer)
    assert_true(projection.take().is_ok())
    checked(observed(rm_pointer),19)
    var raising_pointer: def(String) raises Int thin -> IO[Int].Pure[Int] = checked_length
    checked(raising(String("word"),raising_pointer),4)
    failed(raising(String(""),raising_pointer))
