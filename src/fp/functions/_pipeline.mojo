"""Stage execution shared by immediate pipelines and stored compositions."""
from std.builtin.variadics import TypeList
from std.builtin.rebind import rebind_var


trait _PipelineRunner:
    # Native environment packs are forwarded, never assembled or copied.
    # Concrete runners prove their own environment types before projection.
    @staticmethod
    def apply[index: Int, R: Movable & Deinitable, E: Movable & Deinitable,
              A: Movable & Deinitable, *Environment: Movable & Deinitable](
        var value: A, *environment: *Environment
    ) raises E -> R:
        ...


def _pipe_at[index: Int, Results: TypeList[Trait=Movable & Deinitable, ...],
             E: Movable & Deinitable, D: _PipelineRunner,
             A: Movable & Deinitable, *Environment: Movable & Deinitable](
    var value: A, *environment: *Environment
) raises E -> Results[Results.length - 1]:
    """Apply stage `index` and every later stage, left to right."""
    var result = D.apply[index, Results[index], E](value^, *environment)
    comptime if index + 1 == Results.length:
        comptime assert Results[index] == Results[Results.length - 1]
        return rebind_var[Results[Results.length - 1]](result^)
    else:
        return _pipe_at[index + 1, Results, E, D](result^, *environment)
