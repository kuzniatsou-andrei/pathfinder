#ifndef FFF_SHIM_H
#define FFF_SHIM_H
#include <stddef.h>
#include <stdint.h>

typedef struct {
    const char* file;
    uint32_t line;       // 1-based
    uint32_t col_start;  // 0-based byte offset in line
    uint32_t col_end;
    const char* text;    // the matched line
} ShimMatch;

typedef struct {
    ShimMatch* items;
    size_t count;
} ShimMatches;

// mode: 0 = text, 1 = regex, 2 = fuzzy. Returns 0 on success, non-zero on error.
int shim_grep(const char* base_path, const char* pattern, int mode, ShimMatches* out);
void shim_free(ShimMatches* m);

#endif
