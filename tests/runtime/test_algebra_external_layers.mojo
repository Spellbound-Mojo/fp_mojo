"""Sum transformer entry point for the shared external Box traversal checks."""
from test_algebra_external_traversal import check

def main() raises:
    check[2]()
    check[3]()
    print("external base traversal: OptionalT and ResultT")
