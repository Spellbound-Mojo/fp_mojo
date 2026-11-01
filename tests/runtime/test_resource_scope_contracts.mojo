"""Generic resource operations name public results and forward one scope proof."""
from fp.effects import ReaderAction, ScopedIO, IO, IOResourceContract, resource_io, scoped_io
from fp.callables import UnaryContract, as_unary
from fp.functions import pipeline
from fp.algebra import pure
from std.testing import assert_equal


def used[P: ReaderAction, R: UnaryContract & Movable & Deinitable, F: ScopedIO](var acquire: P, var release: R, var function: F
) -> IOResourceContract[P,R].Out.Used[F] where IOResourceContract[P,R].Compatible and IOResourceContract[P,R].Out.ScopedCompatible[F]:
    return resource_io(acquire^,release^).use(function^)


def mapped[P: ReaderAction, R: UnaryContract & Movable & Deinitable, F: ScopedIO](var acquire: P, var release: R, var function: F
) -> IOResourceContract[P,R].Out.EvalMapped[F] where IOResourceContract[P,R].Compatible and IOResourceContract[P,R].Out.ScopedCompatible[F]:
    return resource_io(acquire^,release^).eval_map(function^)


def tapped[P: ReaderAction, R: UnaryContract & Movable & Deinitable, F: ScopedIO](var acquire: P, var release: R, var function: F
) -> IOResourceContract[P,R].Out.EvalTapped[F] where IOResourceContract[P,R].Compatible and IOResourceContract[P,R].Out.ScopedCompatible[F]:
    return resource_io(acquire^,release^).eval_tap(function^)


def legacy_proof[P: ReaderAction, R: UnaryContract & Movable & Deinitable, F: ScopedIO](var acquire: P, var release: R, var function: F
) -> IOResourceContract[P,R].Out.Used[F] where IOResourceContract[P,R].Compatible and F.Input == IOResourceContract[P,R].Out.Value and F.Error == IOResourceContract[P,R].Out.Error and F.BuildError == Never:
    return resource_io(acquire^,release^).use(function^)


def close(var value: Int) -> IO[Int].Pure[Int]: return pure[IO[Int]](0)
def describe(value: Int) -> IO[Int].Pure[String]: return pure[IO[Int]](String(value))
def read_text(value: String) -> IO[Int].Pure[String]: return pure[IO[Int]](value.copy())
def read_int(value: Int) -> IO[Int].Pure[Int]: return pure[IO[Int]](value)


def main() raises:
    var direct = pipeline(used(pure[IO[Int]](7),as_unary(close),scoped_io(describe))).run_io()
    assert_equal(direct.take()._ok().value,"7")
    var before = pipeline(legacy_proof(pure[IO[Int]](8),as_unary(close),scoped_io(describe))).run_io()
    assert_equal(before.take()._ok().value,"8")
    var projected = mapped(pure[IO[Int]](9),as_unary(close),scoped_io(describe))
    comptime assert type_of(projected).Value == String
    var after = pipeline(projected^.use(read_text)).run_io()
    assert_equal(after.take()._ok().value,"9")
    var observed = tapped(pure[IO[Int]](10),as_unary(close),scoped_io(describe))
    comptime assert type_of(observed).Value == Int
    var kept = pipeline(observed^.use(read_int)).run_io()
    assert_equal(kept.take()._ok().value,10)
