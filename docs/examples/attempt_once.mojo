"""Capture a native failure while consuming a thunk's owned state once."""
from fp.callables import OnceThunk, MutableThunk, shared_ref, mut_ref
from fp.functions import partial
from fp.data import Capture, attempt_once


@fieldwise_init
struct Message(OnceThunk):
    var text: String
    comptime Out = String
    comptime Error = Int
    def call_once(deinit self) raises Int -> String:
        if self.text.byte_length() == 0:
            raise 7
        return self.text^


def show_message(var text: String) -> Int:
    print('message:', text)
    return 0


def show_error(var code: Int) -> Int:
    print('error:', code)
    return code


@fieldwise_init
struct Counter(MutableThunk):
    comptime Out = Int
    comptime Error = Int
    var calls: Int
    def call_mut(mut self) raises Int -> Int:
        self.calls += 1
        if self.calls == 1:
            raise self.calls
        return self.calls


def add(first: Int, second: Int) -> Int: return first + second


def main():
    var message = Message(String('used once'))
    var success = attempt_once(message^)
    _ = success^.fold_owned(show_message, show_error)
    var failure = attempt_once(Message(String()))
    _ = failure^.fold_owned(show_message, show_error)
    print("bound result:", Capture[Error]().run(partial(add, 2, 3)).get_or(0))
    var counter = Counter(0)
    print("counter error:", attempt_once(mut_ref(counter)).swap().get_or(0))
    print("counter value:", attempt_once(mut_ref(counter)).get_or(0))
    print("retained calls:", counter.calls)
    var sum = partial(add, 2, 3)
    var reusable = shared_ref(sum)
    print("shared result:", attempt_once(reusable).get_or(0))
    print("shared again:", Capture[Error]().run(reusable).get_or(0))
