# AnyTogether Linux packages

Package recipes for [AnyPS5 Desktop](https://github.com/AnyTogether/AnyPS5-Desktop), the PS5 game launcher for Linux, for distributions whose packages live outside its releases.

| Folder | What it is |
| --- | --- |
| [`aur/anyps5-desktop-bin`](aur/anyps5-desktop-bin) | The [AUR](https://aur.archlinux.org) package for Arch Linux and its derivatives: the release's `.deb` repacked, so the launcher lands in `/opt/anyps5-desktop` with `anyps5-desktop` on the PATH, the desktop entry, the icons and the `.anyps5theme` file type. |

## Arch Linux (AUR)

Once the package is on the AUR, with an AUR helper:

```sh
yay -S anyps5-desktop-bin
```

Or by hand, from this repository:

```sh
git clone https://github.com/AnyTogether/linux-packages
cd linux-packages/aur/anyps5-desktop-bin
makepkg -si
```

The launcher still looks for new releases itself. Releases after 0.1.20 see that pacman owns them: they say when a new version is out and leave the update to pacman or your AUR helper, without downloading anything. On 0.1.20 its update only downloads the release archive and shows it, so there turn off **Settings → Behaviour → Check for updates**. Settings, logs, caches and downloaded engines live in `~/.config/AnyPS5`, `~/.local/state/AnyPS5`, `~/.cache/AnyPS5` and `~/.local/share/AnyPS5` and stay when the package is removed.

## How the packages stay current

They follow the latest stable release, never a nightly pre-release. A scheduled workflow (`.github/workflows/update.yml`) checks every 6 hours. When a new release is out it moves `pkgver`, resets `pkgrel` and takes the `.deb`'s SHA-256 after checking it against the release's `SHA256SUMS`, writes `.SRCINFO` with `makepkg --printsrcinfo`, then builds the package in an Arch Linux container, checks it with namcap, installs it, checks that every library of the launcher resolves and that the desktop entry is valid, and only then pushes. `.github/workflows/test.yml` runs the same build and install test for every change.

## Publishing to the AUR

The AUR is a separate git host: each package is its own repository at `ssh://aur@aur.archlinux.org/<name>.git`, pushed over SSH by its maintainer. The first push of a name creates the package.

1. Create an account at <https://aur.archlinux.org/register> and add an SSH public key under **My Account → SSH Public Key** (a key just for the AUR is usual).
2. Tell SSH to use it, in `~/.ssh/config`:

   ```
   Host aur.archlinux.org
     IdentityFile ~/.ssh/aur
     User aur
   ```

3. Clone the empty package repository, copy the two files in and push to `master`:

   ```sh
   git clone ssh://aur@aur.archlinux.org/anyps5-desktop-bin.git aur-anyps5-desktop-bin
   cp aur/anyps5-desktop-bin/PKGBUILD aur/anyps5-desktop-bin/.SRCINFO aur-anyps5-desktop-bin/
   cd aur-anyps5-desktop-bin
   git add PKGBUILD .SRCINFO
   git commit -m "anyps5-desktop-bin 0.1.20-1"
   git push origin master
   ```

4. For each new release, after the workflow here moved the files, copy them over again, commit and push the same way. Pushing to the AUR from this repository's workflow would need the AUR SSH private key as a repository secret, which is not set up.
