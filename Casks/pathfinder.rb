# Homebrew Cask for Pathfinder.
#
# Ship this file from a tap repo named `homebrew-<something>` (e.g.
# github.com/<owner>/homebrew-tap), at Casks/pathfinder.rb. Then:
#     brew tap <owner>/tap
#     brew install --cask pathfinder
#
# Fill `version`/`sha256` from `scripts/make-release.sh`, and point `url` at the
# zip you attached to the matching GitHub Release. Replace <owner>.
cask "pathfinder" do
  version "1.0"
  sha256 "REPLACE_WITH_SHA256_FROM_make-release.sh"

  url "https://github.com/<owner>/pathfinder/releases/download/v#{version}/Pathfinder-#{version}.zip"
  name "Pathfinder"
  desc "Simple macOS file-search app (text/regex/fuzzy) over the fff engine"
  homepage "https://github.com/<owner>/pathfinder"

  app "Pathfinder.app"

  # The build is ad-hoc signed, not notarized. Strip the quarantine flag so
  # Gatekeeper doesn't block first launch. Remove this once the app is signed
  # with a Developer ID and notarized.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/Pathfinder.app"],
                   sudo: false
  end

  zap trash: [
    "~/Library/Preferences/com.akuzniatsou.pathfinder.plist",
  ]
end
