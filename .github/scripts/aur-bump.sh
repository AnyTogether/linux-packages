#!/bin/bash
# Moves aur/anyps5-desktop-bin to the latest stable AnyPS5 Desktop release (GitHub's "latest",
# never a nightly pre-release): pkgver, pkgrel=1, the .deb's SHA-256 (checked against the
# release's SHA256SUMS) and .SRCINFO. Prints version=<new> to $GITHUB_OUTPUT when it moved.
# Run as root in archlinux:latest, from the repository's root.
set -euo pipefail

SOURCE=AnyTogether/AnyPS5-Desktop
dir=aur/anyps5-desktop-bin
api() { curl -fsSL -H "Accept: application/vnd.github+json" ${GH_TOKEN:+-H "Authorization: Bearer $GH_TOKEN"} "$@"; }

release="$(api "https://api.github.com/repos/$SOURCE/releases/latest")"
tag="$(jq -r .tag_name <<<"$release")"
if [ "$(jq -r .prerelease <<<"$release")" != "false" ] || [ "$(jq -r .draft <<<"$release")" != "false" ]; then
  echo "::notice::$tag is a pre-release or a draft, nothing to do"
  exit 0
fi
if ! [[ "$tag" =~ ^v([0-9]+(\.[0-9]+)+)$ ]]; then
  echo "::notice::$tag is not a vX.Y.Z release tag, nothing to do"
  exit 0
fi
latest="${BASH_REMATCH[1]}"
current="$(sed -nE 's/^pkgver=(.+)$/\1/p' "$dir/PKGBUILD")"
echo "PKGBUILD: $current, latest release: $latest ($tag)"
if [ "$latest" = "$current" ]; then
  echo "::notice::The PKGBUILD is already at $current"
  exit 0
fi
if [ "$(printf '%s\n%s\n' "$current" "$latest" | sort -V | tail -n 1)" != "$latest" ]; then
  echo "::notice::$latest is older than the PKGBUILD's $current, nothing to do"
  exit 0
fi
asset="anyps5-desktop_${latest}_amd64.deb"
for name in "$asset" SHA256SUMS; do
  if [ "$(jq -r --arg a "$name" '[.assets[] | select(.name == $a)] | length' <<<"$release")" != "1" ]; then
    echo "::notice::$tag has no $name yet, trying again on the next run"
    exit 0
  fi
done

scratch="$(mktemp -d)"
base="https://github.com/$SOURCE/releases/download/$tag"
curl -fsSL -o "$scratch/SHA256SUMS" "$base/SHA256SUMS"
curl -fsSL -o "$scratch/$asset" "$base/$asset"
sha="$(sha256sum "$scratch/$asset" | cut -d' ' -f1)"
listed="$(awk -v a="$asset" '$2 == a || $2 == "*" a { print $1 }' "$scratch/SHA256SUMS")"
if [ "$listed" != "$sha" ]; then
  echo "::error::$asset does not match the release's SHA256SUMS"
  exit 1
fi

sed -i -E "s/^pkgver=.*/pkgver=$latest/; s/^pkgrel=.*/pkgrel=1/; s/^sha256sums=\('[0-9a-f]+'\)$/sha256sums=('$sha')/" "$dir/PKGBUILD"
grep -q "^sha256sums=('$sha')$" "$dir/PKGBUILD"

id builder >/dev/null 2>&1 || useradd -m builder
work="$(mktemp -d)"
cp "$dir/PKGBUILD" "$work/"
chown -R builder "$work"
su builder -c "cd '$work' && makepkg --printsrcinfo" > "$dir/.SRCINFO"
git diff --stat
echo "version=$latest" >> "${GITHUB_OUTPUT:-/dev/null}"
