#!/usr/bin/env bash
# Prints the Homebrew cask for a release, for the MohitSharma0101/homebrew-tap repo.
#
#   scripts/cask.sh VERSION SHA256 [DOWNLOAD_URL]
#
# DOWNLOAD_URL defaults to the release's dev-servers.sh on GitHub; tests pass a file:// URL.
set -euo pipefail

[ $# -ge 2 ] || {
  echo "usage: $0 VERSION SHA256 [DOWNLOAD_URL]" >&2
  exit 1
}
version=$1
sha=$2
url=${3:-'https://github.com/MohitSharma0101/swiftbar-dev-servers/releases/download/v#{version}/dev-servers.sh'}

cat <<EOF
cask "dev-servers" do
  version "$version"
  sha256 "$sha"

  url "$url"
  name "Dev Servers"
  desc "SwiftBar plugin to see, start and stop local dev servers"
  homepage "https://github.com/MohitSharma0101/swiftbar-dev-servers"

  depends_on cask: "swiftbar"
  depends_on formula: "jq"
  depends_on macos: :ventura

  artifact "dev-servers.sh", target: "~/.swiftbar/dev-servers.sh"

  preflight_steps do
    set_permissions "dev-servers.sh", "0755", base: :staged_path
  end

  zap trash: [
    "~/.config/dev-servers",
    "~/Library/Application Support/dev-servers",
    "~/Library/Caches/dev-servers",
    "~/Library/Logs/dev-servers",
  ]

  caveats <<~EOS
    One more step, to point SwiftBar at Dev Servers and start it:

      ~/.swiftbar/dev-servers.sh enable

    If you already use another plugin folder, run the installer from the README instead.
  EOS
end
EOF
