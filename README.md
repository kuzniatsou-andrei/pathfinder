# Pathfinder

Simple macOS file-search app. Search text files by text, regex, or fuzzy;
read results with surrounding context lines; preview whole files;
search-and-replace with undo; reveal in Finder.

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
