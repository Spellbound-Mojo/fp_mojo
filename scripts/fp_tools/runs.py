"""Run ownership and immutable-input lifecycle shared by developer commands."""
from dataclasses import dataclass
from pathlib import Path

from .runtime import (ROOT, binary_directory, environment, input_changes, inputs,
                      normalized, reserve_output, resolved)


@dataclass(frozen=True)
class RunContext:
    folder: Path
    binaries: Path
    host: dict
    before: dict

    @classmethod
    def start(cls, output, label, *, measured=False):
        host = environment(measured=measured)
        folder = reserve_output(output)
        return cls(folder, binary_directory(folder, label), host, inputs())

    def metadata(self):
        changes = input_changes(self.before, inputs())
        return dict(**self.host, report_version=2, output_directory=str(self.folder),
                    binary_directory=str(self.binaries), inputs=self.before,
                    input_changes=changes, inputs_unchanged=not changes)


def audit_run_paths(report, folder, root=ROOT):
    """A child cannot nominate another run's executable or log directory."""
    folder = Path(folder).resolve()
    if report.get("report_version") != 2:
        raise ValueError("unsupported run report version")
    if normalized(report.get("output_directory"), root) != normalized(folder, root):
        raise ValueError("wrong run directory")
    binaries = resolved(report.get("binary_directory", ""), root).resolve()
    parent = folder / "executables"
    if not binaries.is_relative_to(parent) or binaries == parent or not binaries.is_dir():
        raise ValueError("invalid executable directory")
    return binaries
