# error: BorrowOnceCallable
from fp.data import Result, Ok
from result_once_support import Address

def main():
    var subject = Result[String,String](Ok(String('scoped')))
    _ = subject.fold_once(Address(),Address())
