#!/bin/bash
# Builds aur/anyps5-desktop-bin in an Arch Linux container as an unprivileged user, checks it
# with namcap, checks that .SRCINFO is what makepkg prints for the PKGBUILD, installs the
# package and checks that every library of the launcher resolves and that the desktop entry is
# valid, then removes it. The launcher itself is never started. Run as root in archlinux:latest.
set -euo pipefail

dir="${1:-aur/anyps5-desktop-bin}"
name="$(basename "$dir")"

pacman -Syu --noconfirm --needed base-devel namcap desktop-file-utils >/dev/null
id builder >/dev/null 2>&1 || useradd -m builder
echo 'builder ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/builder
work="$(mktemp -d)"
cp -a "$dir/." "$work/"
chown -R builder "$work"
as_builder() { su builder -c "cd '$work' && $*"; }

echo "::group::.SRCINFO"
as_builder makepkg --printsrcinfo > "$work/.SRCINFO.expected"
diff -u "$dir/.SRCINFO" "$work/.SRCINFO.expected"
echo ".SRCINFO matches the PKGBUILD"
echo "::endgroup::"

echo "::group::namcap PKGBUILD"
namcap "$work/PKGBUILD"
echo "::endgroup::"

echo "::group::makepkg"
as_builder makepkg --syncdeps --noconfirm --cleanbuild
echo "::endgroup::"
package="$(ls "$work"/"$name"-*.pkg.tar.zst)"

echo "::group::namcap package"
namcap "$package"
echo "::endgroup::"

echo "::group::Install"
pacman -U --noconfirm "$package"
test -x /opt/anyps5-desktop/anyps5_desktop
test "$(readlink -f /usr/bin/anyps5-desktop)" = /opt/anyps5-desktop/anyps5_desktop
desktop-file-validate /usr/share/applications/anyps5-desktop.desktop
test -f /usr/share/icons/hicolor/512x512/apps/anyps5-desktop.png
test -f /usr/share/mime/packages/anyps5-desktop.xml
# Every library the launcher and its bundled libraries link resolves. libdartjni.so (package:jni,
# pulled in by a dependency) needs a JVM only when Java is called, which the launcher never does.
missing="$(find /opt/anyps5-desktop -type f \( -name anyps5_desktop -o -name '*.so' -o -name '*.so.*' \) \
  -exec ldd {} + 2>&1 | grep 'not found' | grep -v 'libjvm\.so' || true)"
if [ -n "$missing" ]; then
  echo "::error::Libraries that do not resolve:"
  echo "$missing"
  exit 1
fi
echo "Every library resolves"
pacman -Qi "$name" | sed -n '1,3p'
echo "::endgroup::"

pacman -R --noconfirm "$name" >/dev/null
test ! -e /opt/anyps5-desktop/anyps5_desktop
echo "Built, installed and removed $(basename "$package")"
