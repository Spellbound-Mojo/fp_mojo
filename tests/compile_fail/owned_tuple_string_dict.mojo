# error: invalid call to 'tuple_left'
from fp.functions import pipeline,pipeline_values
from std.collections import Deque,LinkedList,StringDict
from owned_fill_support import Box
def main():
    _=pipeline_values(StringDict[Int]()).tuple_left(Box(1))
