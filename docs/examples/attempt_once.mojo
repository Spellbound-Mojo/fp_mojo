"""Capture a native failure while consuming a thunk's owned state once."""
from fp.callables import OnceThunk
from fp.data import attempt_once


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


def main():
    var message = Message(String('used once'))
    var success = attempt_once(message^)
    _ = success^.fold_owned(show_message, show_error)
    var failure = attempt_once(Message(String()))
    _ = failure^.fold_owned(show_message, show_error)
