"""Promote optional input to a Result with an error computed only on absence."""
from fp.functions import pipeline
from std.testing import assert_equal

def address(var host: String) -> String: return "https://" + host
def explain(var error: String) -> String: return error^

def main() raises:
    var errors = 0
    def missing() {mut errors} -> String:
        errors += 1
        return String("host is missing")
    var configured = pipeline(Optional(String("example.org"))).to_result(missing).map(address).value_or(explain)
    assert_equal(configured, "https://example.org")
    assert_equal(errors, 0)
    print(configured)
    var rejected = pipeline(Optional[String]()).to_result(missing).map(address).value_or(explain)
    assert_equal(rejected, "host is missing")
    assert_equal(errors, 1)
    print(rejected)
