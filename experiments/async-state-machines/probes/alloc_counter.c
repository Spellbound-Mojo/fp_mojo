/* Count heap allocations and frees for the storage probes.

Build and preload:

    gcc -O2 -shared -fPIC -o .cache/alloc_counter.so \
        experiments/async-state-machines/probes/alloc_counter.c -ldl
    LD_PRELOAD=.cache/alloc_counter.so ./storage_cost

Mojo's heap is tcmalloc behind `KGEN_CompilerRT_AlignedAlloc(alignment,
size)` and `KGEN_CompilerRT_AlignedFree(pointer)`, exported by
`libKGENCompilerRTShared.so`: every `alloc`, `List`, `String`, `ArcPointer`
and `OwnedPointer` goes through them. Both are wrapped and forwarded to the
next definition (RTLD_NEXT). glibc's entry points (malloc, calloc, realloc,
free, posix_memalign, aligned_alloc, memalign), which `pthread_create` and
foreign code use, are wrapped too and counted apart.

The counts live in `fp_alloc_counts`, a data symbol the probe finds with
`dlsym(RTLD_DEFAULT, ...)`: words 0 to 2 count Mojo allocations, frees of a
non-null pointer and allocated bytes; words 3 and 4 count glibc allocations
and frees. They are process-wide relaxed atomics, so a probe reads
differences around a measured region.

`fp_alloc_sites` attributes Mojo allocations to their call sites: slot k
holds a return address in word 2k and its count in word 2k + 1, inserted
by compare-exchange into an open-addressed table of `SITES` slots (a full
table counts the rest in `fp_alloc_counts[5]`). A probe subtracts two
snapshots and resolves the addresses against the binary.

calloc is reached by dlsym itself before the real calloc is resolved; a small
static buffer serves those early calls and is never freed.
*/
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stddef.h>
#include <stdint.h>

unsigned long fp_alloc_counts[8];

#define SITES 4096
unsigned long fp_alloc_sites[2 * SITES];

static void count_site(unsigned long site) {
    unsigned long slot = (site >> 4) * 0x9E3779B97F4A7C15ul >> 52;
    for (int probe = 0; probe < SITES; ++probe, slot = (slot + 1) & (SITES - 1)) {
        unsigned long key = __atomic_load_n(&fp_alloc_sites[2 * slot], __ATOMIC_ACQUIRE);
        if (key == 0) {
            unsigned long expected = 0;
            if (__atomic_compare_exchange_n(&fp_alloc_sites[2 * slot], &expected, site, 0, __ATOMIC_ACQ_REL, __ATOMIC_ACQUIRE))
                key = site;
            else
                key = expected;
        }
        if (key == site) {
            __atomic_fetch_add(&fp_alloc_sites[2 * slot + 1], 1, __ATOMIC_RELAXED);
            return;
        }
    }
    __atomic_fetch_add(&fp_alloc_counts[5], 1, __ATOMIC_RELAXED);
}

static void *(*real_malloc)(size_t);
static void *(*real_calloc)(size_t, size_t);
static void *(*real_realloc)(void *, size_t);
static void (*real_free)(void *);
static int (*real_posix_memalign)(void **, size_t, size_t);
static void *(*real_aligned_alloc)(size_t, size_t);
static void *(*real_memalign)(size_t, size_t);

static void *(*real_kgen_alloc)(size_t, size_t);
static void (*real_kgen_free)(void *);

static char early[4096];
static size_t early_used;
static int resolving;

static void resolve(void) {
    if (real_malloc || resolving)
        return;
    resolving = 1;
    real_calloc = dlsym(RTLD_NEXT, "calloc");
    real_malloc = dlsym(RTLD_NEXT, "malloc");
    real_realloc = dlsym(RTLD_NEXT, "realloc");
    real_free = dlsym(RTLD_NEXT, "free");
    real_posix_memalign = dlsym(RTLD_NEXT, "posix_memalign");
    real_aligned_alloc = dlsym(RTLD_NEXT, "aligned_alloc");
    real_memalign = dlsym(RTLD_NEXT, "memalign");
    resolving = 0;
}

static void counted(size_t size) {
    (void)size;
    __atomic_fetch_add(&fp_alloc_counts[3], 1, __ATOMIC_RELAXED);
}

void *KGEN_CompilerRT_AlignedAlloc(size_t alignment, size_t size) {
    if (!real_kgen_alloc)
        real_kgen_alloc = dlsym(RTLD_NEXT, "KGEN_CompilerRT_AlignedAlloc");
    __atomic_fetch_add(&fp_alloc_counts[0], 1, __ATOMIC_RELAXED);
    __atomic_fetch_add(&fp_alloc_counts[2], size, __ATOMIC_RELAXED);
    count_site((unsigned long)__builtin_return_address(0));
    return real_kgen_alloc(alignment, size);
}

void KGEN_CompilerRT_AlignedFree(void *p) {
    if (!real_kgen_free)
        real_kgen_free = dlsym(RTLD_NEXT, "KGEN_CompilerRT_AlignedFree");
    if (p)
        __atomic_fetch_add(&fp_alloc_counts[1], 1, __ATOMIC_RELAXED);
    real_kgen_free(p);
}

static int is_early(void *p) {
    return (char *)p >= early && (char *)p < early + sizeof early;
}

void *malloc(size_t size) {
    resolve();
    counted(size);
    return real_malloc(size);
}

void *calloc(size_t n, size_t size) {
    if (!real_calloc) {
        resolve();
        if (!real_calloc) {
            size_t total = (n * size + 15) & ~(size_t)15;
            if (early_used + total > sizeof early)
                return NULL;
            void *p = early + early_used;
            early_used += total;
            return p;
        }
    }
    counted(n * size);
    return real_calloc(n, size);
}

void *realloc(void *p, size_t size) {
    resolve();
    if (!p)
        counted(size);
    return real_realloc(p, size);
}

void free(void *p) {
    if (!p || is_early(p))
        return;
    resolve();
    __atomic_fetch_add(&fp_alloc_counts[4], 1, __ATOMIC_RELAXED);
    real_free(p);
}

int posix_memalign(void **out, size_t alignment, size_t size) {
    resolve();
    counted(size);
    return real_posix_memalign(out, alignment, size);
}

void *aligned_alloc(size_t alignment, size_t size) {
    resolve();
    counted(size);
    return real_aligned_alloc(alignment, size);
}

void *memalign(size_t alignment, size_t size) {
    resolve();
    counted(size);
    return real_memalign(alignment, size);
}
