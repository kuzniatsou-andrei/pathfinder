# Pathfinder

Simple macOS file-search app. Search text files by text, regex, or fuzzy;
read results with surrounding context lines; preview whole files;
search-and-replace with undo; reveal in Finder.

## Features

**Search**
- Three modes: **Text**, **Regex**, **Fuzzy** (native engine: `fff`).
- Explicit **Start / Stop** button (also Enter). No folder yet → the Start
  button opens the folder picker, then searches.
- **Search within results** — restrict the next search to the files currently
  in the result set.
- **Search history** — last 50 queries (deduped, persisted); pick one, delete
  one, or clear all from the clock popover.
- **Clear** button — resets the query and results.

**Filters**
- Include / exclude **glob patterns**: `*` = any number of chars, `!` = exactly
  one char. A pattern matches the filename, **any folder component**, or the
  full path relative to the search folder — so `build` excludes everything
  under any `build/` directory.
- Multiple patterns separated by **comma or `|`** (e.g. `build, target | *.iml`).
- Exclude binary files; max file-size limit.
- **Context lines** ±N (default 1), adjustable.

**Results & preview**
- Grouped by file, showing the path **relative to the search folder** (so
  same-named files in different directories are distinguishable) and a match
  count.
- The matched substring is **highlighted yellow**; the whole-file preview
  highlights **every** occurrence and its text is selectable for copy.
- **Display cap**: the first 100 matches are shown; the rest are counted in the
  background (status bar notes "показаны первые 100").
- Result context menu: reveal in Finder, open in external editor, copy
  full / relative path / filename / containing folder, copy the matched line
  or the whole block (with context), **exclude this file / this folder**, and
  delete (to Trash).

**Editing**
- **Search-and-replace** (text/regex; disabled in fuzzy mode) with **undo**;
  a summary / errors are shown in the status bar. Text files only — binary
  files are skipped.

**App**
- Runs as a proper **`.app` bundle** with an app icon and bundle identifier
  (Dock/Finder/Spotlight). `scripts/make-app.sh install` copies it to
  Applications and pins it to the Dock.
- Remembers and restores the **last searched folder** on launch.
- Follows the **system light/dark theme**.

## Build

    git submodule update --init --recursive
    (cd Vendor/fff && cargo build --release -p fff-c)
    swift build

`fff` is vendored as a git submodule and provides the native search engine
via a C shim; it must be built with `cargo` before `swift build`, since the
dev rpath points at `Vendor/fff/target/release`. On a fresh clone, build fff
first or `swift build` will fail to link.

## Run

Run it as a proper macOS app bundle (has an app icon and a bundle identifier,
so it shows up correctly in the Dock and Finder):

    ./scripts/make-app.sh        # builds Pathfinder.app in the repo root
    open Pathfinder.app

### Install (Applications + Dock)

    ./scripts/make-app.sh install

Builds the bundle, copies it to `/Applications` (or `~/Applications` if that
isn't writable without sudo) and pins it to the Dock. After that, launch
"Pathfinder" from the Dock, Launchpad, or Spotlight — no terminal needed.

> Do **not** run via `swift run PathfinderApp` or Xcode's Run for day-to-day
> use: that launches the bare executable with no bundle identifier, which
> spews harmless console warnings ("missing main bundle identifier",
> App Intents / `linkd` registration errors) and shows no Dock icon. Always
> use the `.app` bundle.
>
> Note: the installed app's binary keeps an absolute rpath into this repo's
> `Vendor/fff/target/release`, so keep the repo in place (a release build for
> distribution would relocate the dylib with an `@loader_path` rpath instead).

## Test

    swift test

Search engine: [fff](https://github.com/dmtrKovalenko/fff) (MIT) via a C shim.
