from fp.effects import resource

def open_left() -> String:
    print("open: left")
    return "left"

def open_right() -> String:
    print("open: right")
    return "right"

def close_name(var name: String):
    print("close:", name)

def join_names(names: Tuple[String, String]) -> String:
    return names[0] + "+" + names[1]

def main():
    var scope = resource[Error](open_left, close_name).product(resource[Error](open_right, close_name))
    print("recipe ready")
    var result = scope^.use(join_names)
    try:
        print("value:", result^.raise_on_err())
    except failure:
        print("errors:", len(failure.errors))
    var completed = resource[Error](open_left, close_name).use_void()
    print("released without a body:", completed.is_ok())
