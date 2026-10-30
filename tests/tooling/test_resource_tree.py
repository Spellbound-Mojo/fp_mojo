"""RSS accounting must follow compiler subprocesses under the native timer."""

import ctypes
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
from fp_tools.runtime import ROOT, _linux_tree_rss, command, audit_command


class ResourceTreeTests(unittest.TestCase):
    @unittest.skipUnless(sys.platform == "linux", "Linux process accounting")
    def test_retained_rss_trace_is_audited_and_never_overwritten(self):
        with tempfile.TemporaryDirectory(dir=ROOT / ".cache") as name:
            folder = Path(name)
            trace = folder / "rss.jsonl"
            record = command(
                [sys.executable, "-c", "import time; data=bytearray(8*1024*1024); time.sleep(.7)"],
                folder / "run.log", timeout=5, memory_limit_bytes=128 * 1024**2,
                rss_samples_log=trace, rss_interval_seconds=.1)
            rows = [json.loads(line) for line in trace.read_text().splitlines()]
            self.assertEqual(record["exit_code"], 0)
            self.assertGreaterEqual(len(rows), 3)
            self.assertGreater(max(row["rss_bytes"] for row in rows), 8 * 1024**2)
            self.assertTrue(all(b["elapsed_seconds"] > a["elapsed_seconds"] for a, b in zip(rows, rows[1:])))
            self.assertTrue(audit_command(record))
            with self.assertRaises(FileExistsError):
                command([sys.executable, "-c", "pass"], folder / "other.log",
                        memory_limit_bytes=128 * 1024**2, rss_samples_log=trace)
            trace.write_text(trace.read_text() + "{}\n")
            self.assertFalse(audit_command(record))

    def test_parent_snapshot_includes_descendants_without_task_children(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            for pid, parent, rss in [
                (10, 1, 5),
                (11, 10, 7),
                (12, 11, 13),
                (20, 1, 1000),
            ]:
                folder = root / str(pid)
                folder.mkdir()
                (folder / "status").write_text(f"PPid:\t{parent}\nVmRSS:\t{rss} kB\n")
            (root / "self").mkdir()
            (root / "99").mkdir()  # Process disappeared before its status was read.
            self.assertEqual(_linux_tree_rss(10, root), 25 * 1024)
            self.assertEqual(_linux_tree_rss(11, root), 20 * 1024)
            self.assertEqual(_linux_tree_rss(20, root), 1000 * 1024)
            self.assertEqual(_linux_tree_rss(30, root), 0)
            # A zombie or exiting intermediate process can have no VmRSS field.
            (root / "11/status").write_text("PPid:\t10\n")
            self.assertEqual(_linux_tree_rss(10, root), 18 * 1024)

    @unittest.skipUnless(sys.platform == "linux", "Linux process accounting")
    def test_memory_limit_reaches_the_timers_child_and_kills_it(self):
        # Adopt and reap this test's killed grandchild rather than leaving it
        # to a container PID 1 that may not reap orphans.
        libc = ctypes.CDLL(None, use_errno=True)
        previous = ctypes.c_int()
        self.assertEqual(libc.prctl(37, ctypes.byref(previous), 0, 0, 0), 0)
        self.assertEqual(libc.prctl(36, 1, 0, 0, 0), 0)
        child = None
        try:
            with tempfile.TemporaryDirectory(dir=ROOT / ".cache") as name:
                script = "import os,time; print(os.getpid(),flush=True); data=bytearray(128*1024*1024); time.sleep(10)"
                record = command(
                    [sys.executable, "-c", script],
                    Path(name) / "memory.log",
                    timeout=5,
                    timed=True,
                    memory_limit_bytes=64 * 1024 * 1024,
                )
                child = int(record["stdout"].strip())
                self.assertTrue(record["memory_limit_exceeded"])
                self.assertFalse(record["timeout"])
                self.assertFalse(record["crashed"])
                self.assertGreater(
                    record["sampled_tree_peak_rss_bytes"], 64 * 1024 * 1024
                )
                self.assertEqual(record["exit_code"], -9)
                try:
                    reaped, status = os.waitpid(child, 0)
                except ChildProcessError:
                    # The timer may reap its child before the group kill takes
                    # effect on the timer itself. No child is then adopted by
                    # this subreaper; it must already have disappeared.
                    self.assertFalse(Path(f"/proc/{child}").exists())
                else:
                    self.assertEqual(reaped, int(record["stdout"].strip()))
                    self.assertTrue(os.WIFSIGNALED(status))
                    self.assertEqual(os.WTERMSIG(status), 9)
                child = None
        finally:
            if child is not None:
                try:
                    os.waitpid(child, 0)
                except ChildProcessError:
                    pass
            libc.prctl(36, previous.value, 0, 0, 0)


if __name__ == "__main__":
    unittest.main()
