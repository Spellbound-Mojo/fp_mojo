# error: invalid call to 'fill'
from fp.functions import pipeline,pipeline_values
from std.collections import Deque,LinkedList,StringDict
from owned_fill_support import Box
def main():
    _=pipeline(LinkedList[Int]()).fill(Box(1))
