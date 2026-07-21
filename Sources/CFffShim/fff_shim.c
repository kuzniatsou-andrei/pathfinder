#include "fff_shim.h"
#include "fff.h"      // from Vendor/fff/crates/fff-c/include
#include <stdlib.h>
#include <string.h>

// Append one match to a dynamically grown array. Returns 0 on success, 1 on OOM.
static int push_match(ShimMatch** items, size_t* count, size_t* cap,
                      const char* base_path, const struct FffGrepMatch* m) {
    if (*count == *cap) {
        size_t new_cap = (*cap == 0) ? 16 : (*cap * 2);
        ShimMatch* grown = (ShimMatch*)realloc(*items, new_cap * sizeof(ShimMatch));
        if (grown == NULL) return 1;
        *items = grown;
        *cap = new_cap;
    }

    // Build an absolute file path: base_path + "/" + relative_path.
    const char* rel = m->relative_path ? m->relative_path : "";
    size_t base_len = strlen(base_path);
    size_t rel_len = strlen(rel);
    // Avoid a doubled separator if base already ends with one.
    int need_sep = (base_len > 0 && base_path[base_len - 1] != '/') ? 1 : 0;
    char* full = (char*)malloc(base_len + (size_t)need_sep + rel_len + 1);
    if (full == NULL) return 1;
    memcpy(full, base_path, base_len);
    if (need_sep) full[base_len] = '/';
    memcpy(full + base_len + need_sep, rel, rel_len);
    full[base_len + need_sep + rel_len] = '\0';

    const char* line = m->line_content ? m->line_content : "";
    char* text = strdup(line);
    if (text == NULL) { free(full); return 1; }

    // Prefer the first highlight range for byte columns; fall back to `col`.
    uint32_t col_start = m->col;
    uint32_t col_end = m->col;
    if (m->match_ranges_count > 0 && m->match_ranges != NULL) {
        col_start = m->match_ranges[0].start;
        col_end = m->match_ranges[0].end;
    }

    ShimMatch* slot = &(*items)[*count];
    slot->file = full;
    slot->line = (uint32_t)m->line_number;
    slot->col_start = col_start;
    slot->col_end = col_end;
    slot->text = text;
    (*count)++;
    return 0;
}

int shim_grep(const char* base_path, const char* pattern, int mode, ShimMatches* out) {
    out->items = NULL;
    out->count = 0;

    struct FffCreateOptions opts;
    memset(&opts, 0, sizeof(opts));
    opts.version = FFF_CREATE_OPTIONS_VERSION;
    opts.base_path = base_path;
    opts.enable_mmap_cache = false;
    opts.enable_content_indexing = true;
    opts.watch = false;
    opts.ai_mode = false;

    struct FffResult* create_res = fff_create_instance_with(&opts);
    if (create_res == NULL) return 1;
    if (!create_res->success) {
        fff_free_result(create_res);
        return 1;
    }
    void* picker = create_res->handle;
    fff_free_result(create_res); // handle outlives the envelope

    // Ensure the initial file scan has completed so files are discoverable.
    struct FffResult* scan_res = fff_wait_for_scan(picker, 10000);
    if (scan_res != NULL) fff_free_result(scan_res);

    ShimMatch* items = NULL;
    size_t count = 0;
    size_t cap = 0;
    int rc = 0;
    uint32_t file_offset = 0;

    for (;;) {
        struct FffResult* res = fff_live_grep(
            picker, pattern, (uint8_t)mode,
            /*max_file_size*/ 0, /*max_matches_per_file*/ 0, /*smart_case*/ false,
            /*file_offset*/ file_offset, /*page_limit*/ 0, /*time_budget_ms*/ 0,
            /*before_context*/ 0, /*after_context*/ 0, /*classify_definitions*/ false);

        if (res == NULL) { rc = 1; break; }
        if (!res->success) {
            fff_free_result(res);
            rc = 1;
            break;
        }

        struct FffGrepResult* g = (struct FffGrepResult*)res->handle;
        if (g != NULL) {
            for (uint32_t i = 0; i < g->count; i++) {
                if (push_match(&items, &count, &cap, base_path, &g->items[i]) != 0) {
                    rc = 1;
                    break;
                }
            }
        }
        uint32_t next = (g != NULL) ? g->next_file_offset : 0;

        fff_free_grep_result(g);
        fff_free_result(res);

        if (rc != 0) break;
        if (next == 0 || next <= file_offset) break; // done / guard against no progress
        file_offset = next;
    }

    fff_destroy(picker);

    if (rc != 0) {
        // Roll back any partial allocation.
        for (size_t i = 0; i < count; i++) {
            free((void*)items[i].file);
            free((void*)items[i].text);
        }
        free(items);
        return rc;
    }

    out->items = items;
    out->count = count;
    return 0;
}

void shim_free(ShimMatches* m) {
    if (m->items == NULL) return;
    for (size_t i = 0; i < m->count; i++) {
        free((void*)m->items[i].file);
        free((void*)m->items[i].text);
    }
    free(m->items);
    m->items = NULL; m->count = 0;
}
