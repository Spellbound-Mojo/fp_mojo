# error: 'Deferred' parameter 'T' has 'Copyable & Deinitable' type
from state_machine import Deferred
from coordination_owned import Owner

def main():
    var deferred = Deferred[Owner]()
    _ = deferred^
