#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>
int main(int argc, char** argv) {
    if (argc < 2) { fprintf(stderr, "usage: %s <MiB> [stride_bytes]\n", argv[0]); return 1; }
    size_t mib = strtoull(argv[1], NULL, 10);
    size_t stride = (argc>2)? strtoull(argv[2], NULL, 10) : 64;
    size_t bytes = mib * 1024ULL * 1024ULL, step = stride/sizeof(uint64_t);
    if (step==0) step=1;
    uint64_t *a = (uint64_t*) aligned_alloc(64, bytes);
    for (size_t i=0;i<bytes/8;i+=1) a[i]=i;
    volatile uint64_t s=0; for (size_t i=0;i<bytes/8;i+=step) s+=a[i];
    printf("SUM=%llu\n",(unsigned long long)s); return 0;
}
