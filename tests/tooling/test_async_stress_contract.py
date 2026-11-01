"""Incomplete work and fabricated/partial measurements cannot qualify a soak."""
import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "experiments/async-state-machines"))
from stress_contract import stress_observation, memory_observation, performance_observation


class AsyncStressContractTests(unittest.TestCase):
    def test_work_floor_window_retirement_and_ownership_are_required(self):
        line = ("stress lifecycle cycles=64 elapsed_ns=1000000000 nodes=12 node_capacity=16 "
                "timers_peak=4 payloads=200 drops=200 withdrawals=64 polls=128 active=0 live_timers=0\n")
        self.assertEqual(stress_observation("lifecycle", line, 1, 64)["cycles"], 64)
        for bad in (line.replace("cycles=64", "cycles=0"), line.replace("active=0", "active=1"),
                    line.replace("drops=200", "drops=199"), line.replace("withdrawals=64", "withdrawals=63"),
                    line.replace("1000000000", "999999999"), line.replace(" live_timers=0", ""),
                    line + line, line.replace("nodes=12", "nodes=1000")):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                stress_observation("lifecycle", bad, 1, 64)

    def trace(self, growth=False):
        return "\n".join(json.dumps(dict(elapsed_seconds=t, rss_bytes=(8 + (t // 30 if growth else 0)) * 1024**2))
                         for t in range(0, 601, 5))

    def test_rss_requires_sustained_coverage_and_rejects_growth(self):
        self.assertTrue(memory_observation(self.trace(), 600)["qualified"])
        self.assertFalse(memory_observation(self.trace(), 1)["qualified"])
        for trace in ("", self.trace(True), "\n".join(self.trace().splitlines()[:20]),
                      self.trace().replace('"rss_bytes": 8388608', '"rss_bytes": 999999999'),
                      self.trace() + '\n{"elapsed_seconds": 0, "rss_bytes": 0}'):
            with self.subTest(trace=trace[:100]), self.assertRaises(ValueError):
                memory_observation(trace, 600)

    def performance(self):
        rows = []
        for size in (1024, 8192, 65536):
            for index in range(9):
                checksum = 17 + index
                for _ in range(size):
                    checksum = (checksum * 1664525 + 1013904223) & 268435455
                rows.append(f"sample sequence size={size} index={index} native_ns=100 async_ns={1000+index} checksum={checksum}")
        for size in (1, 64, 512):
            for index in range(9):
                rows.append(f"sample idle size={size} index={index} idle_ns=200 cancel_ns=300 calls=10000 polls=0")
        return "\n".join(rows)

    def test_performance_requires_every_sample_and_independent_checksums(self):
        text = self.performance()
        summaries = performance_observation(text)
        self.assertEqual(len(summaries), 6)
        sequence = next(row for row in summaries if row["kind"] == "sequence")
        self.assertEqual(sequence["async_ns"]["median"], 1004)
        self.assertEqual(sequence["async_ns"]["p95"], 1008)
        for bad in (text.rsplit("\n", 1)[0], text + "\n" + text.splitlines()[0],
                    text.replace("polls=0", "polls=1", 1), text.replace("checksum=", "checksum=1", 1),
                    text.replace("native_ns=100", "native_ns=0", 1)):
            with self.subTest(bad=bad[:120]), self.assertRaises(ValueError):
                performance_observation(bad)


if __name__ == "__main__":
    unittest.main()
