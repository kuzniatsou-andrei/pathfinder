# Pathfinder

Simple macOS file-search app. Search text files by text, regex, or fuzzy;
read results with surrounding context lines; preview whole files;
search-and-replace with undo; reveal in Finder.

## Build

    git submodule update --init --recursive
    (cd Vendor/fff && cargo build --release -p fff-c)
    swift build
    swift run PathfinderApp

`fff` is vendored as a git submodule and provides the native search engine
via a C shim; it must be built with `cargo` before `swift build`/`swift run`,
since the dev rpath points at `Vendor/fff/target/release`. On a fresh clone,
build fff first or `swift build` will fail to link.

## Test

    swift test

Search engine: [fff](https://github.com/dmtrKovalenko/fff) (MIT) via a C shim.
