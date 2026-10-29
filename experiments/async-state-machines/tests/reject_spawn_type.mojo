# error: cannot be converted from 'Pure[Int, String]' to 'Pure[Int, Int]'
from state_machine import Nursery, Pure, pure

def main():
    var nursery = Nursery[Pure[Int, Int]](1)
    _ = nursery.spawner().try_spawn(pure[String](42))
