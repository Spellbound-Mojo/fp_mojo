"""Move-only replacement used by fill admission fixtures."""
@fieldwise_init
struct Box(Movable):
    var value:Int
