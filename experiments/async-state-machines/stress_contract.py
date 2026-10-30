"""Maintained observations for the opt-in async qualification runner."""
import json
import math
import statistics

CLIENTS = ("metadata", "lifecycle", "workers")
ROUTES = ("source", "package")
LEVELS = (0, 3)
MEMORY_BYTES = 512 * 1024**2
MINIMUM_CYCLES = 64
RSS_INTERVAL = 5


def fields(line, prefix):
    if not line.startswith(prefix + " "):
        raise ValueError("missing observation prefix")
    result = {}
    for token in line[len(prefix) + 1:].split():
        key, value = token.split("=")
        if key in result or not value.isdecimal():
            raise ValueError("duplicate or nonnegative-integer observation")
        result[key] = int(value)
    return result


def stress_observation(name, stdout, seconds, minimum):
    lines = stdout.splitlines()
    if len(lines) != 1 or name not in CLIENTS:
        raise ValueError("incomplete or unexpected stress output")
    row = fields(lines[0], "stress " + name)
    common = {"cycles", "elapsed_ns", "active", "live_timers"}
    extra = {
        "metadata": {"nodes", "node_capacity", "subscriptions", "subscription_capacity", "timers_peak"},
        "lifecycle": {"nodes", "node_capacity", "timers_peak", "payloads", "drops", "withdrawals", "polls"},
        "workers": {"queue_capacity", "subscription_capacity", "modes"},
    }[name]
    if set(row) != common | extra:
        raise ValueError("missing or unknown stress counters")
    if (row["cycles"] < max(MINIMUM_CYCLES, minimum) or row["elapsed_ns"] <= 0
            or row["elapsed_ns"] < seconds * 10**9
            or row["active"] != 0 or row["live_timers"] != 0):
        raise ValueError("insufficient work/window or live registrations at shutdown")
    if name == "metadata" and not (
            row["nodes"] == row["node_capacity"] == 4
            and row["subscriptions"] == row["subscription_capacity"] == 2
            and 32 < row["timers_peak"] <= 37):
        raise ValueError("metadata did not exercise bounded reuse and compaction")
    if name == "lifecycle" and not (
            1 < row["nodes"] <= row["node_capacity"] <= 64
            and 0 < row["timers_peak"] <= 49
            and row["payloads"] == row["drops"] >= 2 * row["cycles"]
            and row["withdrawals"] == row["cycles"] and row["polls"] >= row["cycles"]):
        raise ValueError("lifecycle ownership or retained-storage evidence")
    if name == "workers" and not (
            row["modes"] == 4 and 0 < row["queue_capacity"] <= 64
            and 0 < row["subscription_capacity"] <= 2):
        raise ValueError("worker coordination evidence")
    return row


def memory_observation(text, seconds):
    samples = [json.loads(line) for line in text.splitlines()]
    previous = -1
    for row in samples:
        t, rss = row["elapsed_seconds"], row["rss_bytes"]
        if (set(row) != {"elapsed_seconds", "rss_bytes"}
                or type(t) not in (int, float) or not math.isfinite(t) or t <= previous
                or type(rss) is not int or not 0 <= rss <= MEMORY_BYTES):
            raise ValueError("invalid RSS sample or exceeded memory budget")
        previous = t
    if not samples:
        raise ValueError("missing RSS trace")
    if seconds < 120:
        return {"qualified": False, "reason": "short calibration; RSS plateau requires at least 120 seconds"}
    # Ignore startup, then compare early and late quarters. RSS is an additional
    # allocator-level check; exact logical bounds are asserted by the clients.
    warm = [s for s in samples if s["elapsed_seconds"] >= seconds * .1 and s["rss_bytes"] > 0]
    if (len(warm) < 16 or warm[-1]["elapsed_seconds"] < seconds * .9
            or any(b["elapsed_seconds"] - a["elapsed_seconds"] > 4 * RSS_INTERVAL + 5
                   for a, b in zip(samples, samples[1:]))):
        raise ValueError("incomplete sustained RSS coverage")
    width = len(warm) // 4
    early = statistics.median(s["rss_bytes"] for s in warm[:width])
    late = statistics.median(s["rss_bytes"] for s in warm[-width:])
    peak = max(s["rss_bytes"] for s in warm)
    allowance = max(4 * 1024**2, early * .2)
    if late > early + allowance or peak > early + max(8 * 1024**2, early * .4):
        raise ValueError("retained RSS grew beyond the declared allowance")
    return dict(qualified=True, samples=len(warm), early_median_bytes=early,
                late_median_bytes=late, peak_bytes=peak, allowance_bytes=allowance)


def performance_observation(stdout):
    groups = {}
    for line in stdout.splitlines():
        if len(line.split()) < 2:
            raise ValueError("missing performance observation")
        kind = line.split()[1]
        if kind not in ("sequence", "idle"):
            raise ValueError("unknown performance observation")
        row = fields(line, "sample " + kind)
        expected = ({"size", "index", "native_ns", "async_ns", "checksum"} if kind == "sequence"
                    else {"size", "index", "idle_ns", "cancel_ns", "calls", "polls"})
        sizes = (1024, 8192, 65536) if kind == "sequence" else (1, 64, 512)
        if set(row) != expected or row["size"] not in sizes or row["index"] not in range(9):
            raise ValueError("invalid performance sample shape")
        group = groups.setdefault((kind, row["size"]), {})
        if row["index"] in group:
            raise ValueError("duplicate performance sample")
        if kind == "sequence":
            checksum = 17 + row["index"]
            for _ in range(row["size"]):
                checksum = (checksum * 1664525 + 1013904223) & 268435455
            if row["checksum"] != checksum or min(row["native_ns"], row["async_ns"]) <= 0:
                raise ValueError("incorrect sequence checksum or duration")
        elif row["calls"] != 10000 or row["polls"] != 0 or min(row["idle_ns"], row["cancel_ns"]) <= 0:
            raise ValueError("idle work was performed or duration missing")
        group[row["index"]] = row
    if len(groups) != 6 or any(len(group) != 9 for group in groups.values()):
        raise ValueError("incomplete warmed performance matrix")
    summaries = []
    for (kind, size), group in sorted(groups.items()):
        metrics = ("native_ns", "async_ns") if kind == "sequence" else ("idle_ns", "cancel_ns")
        summary = dict(kind=kind, size=size, samples=9)
        for metric in metrics:
            values = sorted(row[metric] for row in group.values())
            summary[metric] = dict(min=values[0], median=values[4], p95=values[-1], max=values[-1])
        summaries.append(summary)
    return summaries
