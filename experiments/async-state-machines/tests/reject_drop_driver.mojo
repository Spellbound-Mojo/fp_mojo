# error: type 'Driver' does not conform to 'Deinitable'
from state_machine import Driver, pure

def main():
    var driver = Driver(pure[Int](42))
    _ = driver.poll(0)
