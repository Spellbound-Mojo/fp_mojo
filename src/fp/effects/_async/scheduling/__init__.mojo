"""Concurrent structures of the work-stealing pool, built and qualified in isolation.

The per-worker local ring (`_LocalQueue`), the striped external queue
(`_ExternalQueue`), and the per-worker timer heap (`_TimerHeap`) follow Cats
Effect's `LocalQueue`, `ScalQueue`, and `TimerHeap`. Each module documents the
memory ordering of every atomic operation. The engine does not use them yet.
"""
