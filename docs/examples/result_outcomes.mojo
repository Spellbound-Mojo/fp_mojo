"""Map, observe and continue either Result branch without wrapper lambdas."""
from fp.data import Result, Ok, Err, ok, err
from fp.functions import pipeline


def format_invoice(value: Int) -> String: return "invoice: " + String(value)
def error_code(var error: String) -> Int: return error.byte_length()


def audit(outcome: Result[String, Int]) -> Result[NoneType, Int]:
    print("observed error:", outcome.is_err())
    return Ok(NoneType())


def accept(var invoice: String) -> Result[String, String]: return Ok(invoice^)


def retry(code: Int) -> Result[String, String]:
    if code == 7: return Ok(String("default invoice"))
    return Err("code " + String(code))


def keep(var invoice: String) -> String: return invoice^
def explain(var error: String) -> String: return "failed: " + error


def main() raises:
    for branch in range(3):
        var source = ok[String](4) if branch == 0 else err[Int](String("missing" if branch == 1 else "fatal"))
        var message = (
            pipeline(source^)
            .map_both(format_invoice, error_code)
            .attempt_tap(audit)
            .redeem_with(accept, retry)
            .redeem(keep, explain)
            .raise_on_err()
        )
        print(message)
