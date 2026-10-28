"""Map, observe and continue either Result branch without wrapper lambdas."""
from fp.data import Result, Ok, Err
from fp.algebra import IdentityFamily, ResultFamily
from fp.functions import pipeline, kleisli


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
    var format_value = kleisli[IdentityFamily](format_invoice)
    var format_error = kleisli[IdentityFamily](error_code)
    var on_success = kleisli[ResultFamily[String]](accept)
    var on_failure = kleisli[ResultFamily[String]](retry)
    var final_value = kleisli[IdentityFamily](keep)
    var final_error = kleisli[IdentityFamily](explain)
    for branch in range(3):
        var source = Result[Int, String](Ok(4)) if branch == 0 else Result[Int, String](Err(String("missing" if branch == 1 else "fatal")))
        var message = (
            pipeline(source^)
            .map_both(format_value, format_error)
            .attempt_tap(audit)
            .redeem_with(on_success, on_failure)
            .redeem(final_value, final_error)
            .get()
        )
        print(message^.raise_on_err())
