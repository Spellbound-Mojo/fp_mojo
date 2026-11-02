"""Check independent form fields together, then run a dependent check on the form."""
from fp.data import Result, Ok, Err
from fp.algebra import ListMonoid, ValidationFamily
from fp.functions import pipeline
from std.testing import assert_equal

comptime Problems = List[String]

@fieldwise_init
struct Signup(Movable):
    var name: String
    var password: String
    var age: Int

def problem(var message: String) -> Problems:
    var problems: Problems = [message^]
    return problems^

def checked_name(var name: String) -> Result[String, Problems]:
    if name.byte_length() == 0: return Err(problem("name is empty"))
    return Ok(name^)

def checked_password(var password: String) -> Result[String, Problems]:
    if password.byte_length() < 8: return Err(problem("password is shorter than 8 bytes"))
    return Ok(password^)

def checked_age(age: Int) -> Result[Int, Problems]:
    if age < 18: return Err(problem("age " + String(age) + " is under 18"))
    return Ok(age)

def signup(var name: String, var password: String, var age: Int) -> Signup:
    return Signup(name^, password^, age)

def distinct(var form: Signup) -> Result[Signup, Problems]:
    print("comparing the password with the name")
    if form.name in form.password: return Err(problem("password contains the name"))
    return Ok(form^)

def welcome(var form: Signup) -> String:
    return "welcome " + form.name + ", age " + String(form.age)

def show_fields(var fields: Tuple[String, Int]) -> String:
    return fields[0] + ", " + String(fields[1])

def report(var problems: Problems) -> String:
    var text = String("rejected: ")
    for index in range(len(problems)):
        if index > 0: text += "; "
        text += problems[index]
    return text^

def register(var name: String, var password: String, age: Int) -> Result[Signup, Problems]:
    return (pipeline(checked_name(name^))
        .par_map_n((checked_password(password^), checked_age(age)), signup)
        .flat_map(distinct)
        .get())

def main() raises:
    var first = pipeline(checked_name("")).map_n((checked_password("short"), checked_age(12)), signup).get()
    var first_text = first^.fold_owned(welcome, report)
    assert_equal(first_text, "rejected: name is empty")
    print("map_n:", first_text)

    var every = pipeline(checked_name("")).par_map_n((checked_password("short"), checked_age(12)), signup).get()
    var every_text = every^.fold_owned(welcome, report)
    assert_equal(every_text, "rejected: name is empty; password is shorter than 8 bytes; age 12 is under 18")
    print("par_map_n:", every_text)

    comptime Validation = ValidationFamily[ListMonoid[String]]
    var selected = pipeline[Validation](checked_name("")).map_n((checked_password("short"), checked_age(12)), signup).get()
    assert_equal(selected^.fold_owned(welcome, report), every_text)

    var fields = pipeline(checked_name("ana")).par_product_n((checked_age(30),)).get()
    print("par_product_n:", fields^.fold_owned(show_fields, report))

    var accepted = register("ana", "correct-horse", 30).fold_owned(welcome, report)
    assert_equal(accepted, "welcome ana, age 30")
    print("accepted:", accepted)
    var conflict = register("ana", "ana-secret", 30).fold_owned(welcome, report)
    assert_equal(conflict, "rejected: password contains the name")
    print("conflict:", conflict)
    var skipped = register("", "short", 12).fold_owned(welcome, report)
    assert_equal(skipped, every_text)
    print("skipped:", skipped)
