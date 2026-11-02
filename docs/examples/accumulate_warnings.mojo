"""Keep a corrected value with its warnings, and keep warnings beside errors."""
from fp.data import Ior, Left, Right, Both, NonEmptyList
from fp.algebra import IorValidationFamily, NonEmptyListSemigroup
from fp.functions import pipeline
from std.testing import assert_equal

comptime Notes = NonEmptyList[String]
comptime Independent = IorValidationFamily[NonEmptyListSemigroup[String]]

@fieldwise_init
struct Profile(Movable):
    var name: String
    var age: Int

def checked_name(var name: String) -> Ior[Notes, String]:
    var trimmed = String(name.strip())
    if trimmed.byte_length() == 0: return Left(Notes(String("name is empty")))
    if trimmed != name: return Both(Notes(String("name trimmed")), trimmed^)
    return Right(trimmed^)

def checked_age(age: Int) -> Ior[Notes, Int]:
    if age < 0: return Left(Notes("age " + String(age) + " is negative"))
    if age > 120: return Both(Notes("age " + String(age) + " lowered to 120"), 120)
    return Right(age)

def profile(var name: String, var age: Int) -> Profile:
    return Profile(name^, age)

def joined(var notes: Notes) -> String:
    var text = String()
    for note in notes^:
        if text.byte_length() > 0: text += "; "
        text += note
    return text^

def shown(person: Profile) -> String:
    return person.name + ", " + String(person.age)

def describe(var outcome: Ior[Notes, Profile]) -> String:
    if outcome.isa[Left[Notes]]():
        return "rejected: " + joined(outcome^.unwrap[Left[Notes]]().into_payload())
    if outcome.isa[Right[Profile]]():
        return "accepted " + shown(outcome[Right[Profile]].value)
    ref both = outcome[Both[Notes, Profile]]
    var count = String(len(both.left))
    return "accepted " + shown(both.right) + " with " + count + " warnings, first: " + both.left.first()

def review(var name: String, age: Int) -> String:
    return describe(pipeline[Independent](checked_name(name^)).map_n((checked_age(age),), profile).get())

def main() raises:
    var clean = review("ana", 30)
    assert_equal(clean, "accepted ana, 30")
    print(clean)
    var corrected = review(" ana ", 150)
    assert_equal(corrected, "accepted ana, 120 with 2 warnings, first: name trimmed")
    print(corrected)
    var mixed = review(" ana ", -4)
    assert_equal(mixed, "rejected: name trimmed; age -4 is negative")
    print(mixed)
    var failed = review(" ", -4)
    assert_equal(failed, "rejected: name is empty; age -4 is negative")
    print(failed)
