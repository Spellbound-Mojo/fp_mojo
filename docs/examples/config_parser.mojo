"""Configuration parsing: lazy parsing, Result aggregation and a validating fold.

Grammar: batch=<integer> and workers=<integer>, exactly once each. Parsing stops
at the first malformed line; validation runs only after every line has parsed.
"""
import fp
from fp.data import Result, Ok, Err, Break, Continue, ControlFlow, collect_results
from fp.functions import pipe
from fp.iteration import map, fold_until
from std.testing import assert_equal


@fieldwise_init
struct Entry(Movable):
    var key: String
    var value: Int


@fieldwise_init
struct Config(Copyable):
    var batch: Int
    var workers: Int


@fieldwise_init
struct ConfigError(Copyable):
    var message: String


comptime Parsed = Result[List[Entry], ConfigError]
comptime Checked = Result[Config, ConfigError]


def parse(var line: String) -> Result[Entry, ConfigError]:
    var parts = line.split("=")
    if len(parts) != 2:
        return Err(ConfigError("syntax"))
    try:
        return Ok(Entry(String(parts[0]), Int(String(parts[1]))))
    except:
        # A native conversion error becomes a domain error at this boundary.
        return Err(ConfigError("integer"))


def record(var seen: Config, var entry: Entry) -> ControlFlow[ConfigError, Config]:
    """Take one entry into the configuration, or stop at the first invalid one."""
    if entry.value <= 0:
        return Break(ConfigError("positive values required"))
    if entry.key == "batch" and seen.batch == 0:
        seen.batch = entry.value
    elif entry.key == "workers" and seen.workers == 0:
        seen.workers = entry.value
    else:
        return Break(ConfigError("unknown or duplicate key"))
    return Continue(seen^)


def complete(config: Config) -> Checked:
    if config.batch == 0 or config.workers == 0:
        return Err(ConfigError("missing key"))
    if config.workers > config.batch:
        return Err(ConfigError("workers exceeds batch"))
    return Ok(config.copy())


def validate(var entries: List[Entry]) -> Checked:
    return fp.match(fold_until(record, Config(0, 0), entries^),
        lambda (stop: Break[ConfigError]) -> Checked: Err(stop.value.copy()),
        lambda (done: Continue[Config]) -> Checked: complete(done.value))


def check(var parsed: Parsed) -> Checked:
    return parsed^.flat_map(validate)


def describe(var config: Config) -> String:
    return "batch=" + String(config.batch) + ", workers=" + String(config.workers)


def render(var checked: Checked) -> Result[String, ConfigError]:
    return checked^.map(describe)


def finish(var rendered: Result[String, ConfigError]) -> String:
    return fp.match(rendered,
        lambda (ok: Ok[String]) -> String: "ready: " + ok.value,
        lambda (err: Err[ConfigError]) -> String: "error: " + err.value.message)


def configure(var lines: List[String], mut parsed: Int) -> String:
    """Parse lazily, stopping at the first bad line; `parsed` counts the lines read."""
    def counted(var line: String) {mut parsed} -> Result[Entry, ConfigError]:
        parsed += 1
        return parse(line^)
    return pipe(collect_results(map(counted, lines^)), check, render, finish)


def scenario(var lines: List[String], expected: String, parsed_lines: Int) raises:
    var parsed = 0
    assert_equal(configure(lines^, parsed), expected)
    assert_equal(parsed, parsed_lines)


def main() raises:
    scenario(["batch=12", "workers=4"], "ready: batch=12, workers=4", 2)
    scenario(["bad", "workers=4"], "error: syntax", 1)
    scenario(["batch=12", "workers=no", "ignored=99"], "error: integer", 2)
    scenario(["batch=12", "batch=4"], "error: unknown or duplicate key", 2)
    scenario(["batch=12", "workers=0"], "error: positive values required", 2)
    scenario(["batch=2", "workers=4"], "error: workers exceeds batch", 2)
    scenario([], "error: missing key", 0)
    var parsed = 0
    print(configure(["batch=12", "workers=4"], parsed))
