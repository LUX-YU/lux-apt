# lux-apt

Signed APT repository for the [LUX project](https://github.com/LUX-YU) family,
served from GitHub Pages and built by CI. amd64 + arm64 (arm64 targets NVIDIA
Jetson / JetPack 6 = Ubuntu 22.04 "jammy").

## Use it (consumers, incl. Jetson)

```bash
sudo install -d /etc/apt/keyrings
curl -fsSL https://lux-yu.github.io/lux-apt/lux-archive-keyring.asc \
  | sudo tee /etc/apt/keyrings/lux.asc >/dev/null
echo "deb [signed-by=/etc/apt/keyrings/lux.asc] https://lux-yu.github.io/lux-apt jammy main" \
  | sudo tee /etc/apt/sources.list.d/lux.list
sudo apt-get update
sudo apt-get install lux-cxx lux-communication lux-dataset
```

Dependencies resolve automatically (e.g. `lux-communication` pulls in `lux-cxx`
and `concurrentqueue`). No compiling on the target.

## How it works

`.github/workflows/publish.yml` rebuilds the whole repo from scratch each run:

1. `scripts/build-thirdparty-debs.sh` builds arch:all `.deb`s for the header-only
   deps Ubuntu doesn't ship (`concurrentqueue`, `stduuid`).
2. It downloads the latest GitHub **Release** `.deb` assets from each LUX package
   repo listed in `LUX_REPOS`.
3. `aptly` assembles + GPG-signs the `jammy/main` repo (amd64, arm64).
4. The result deploys to GitHub Pages.

State-free: the Release assets are the source of truth, so re-running the
workflow always reproduces the current repo.

## One-time setup

- **Pages**: Settings → Pages → Source = **GitHub Actions**.
- **Signing key**: create a *passphrase-less* GPG key (simplest for CI):
  ```bash
  gpg --batch --quick-generate-key "LUX apt <chenhui.lux.yu@outlook.com>" default sign never
  gpg --armor --export-secret-keys <KEYID>   # paste into the GPG_PRIVATE_KEY secret
  ```
  Add repo secret `GPG_PRIVATE_KEY` (the armored private key). If your key has a
  passphrase, also add `GPG_PASSPHRASE`.

## Maintainer runbook

The repo is bootstrapped bottom-up; re-run **publish** after each new package release:

1. Tag `lux-cmake-toolset` and `lux-cxx` (`git tag vX.Y.Z && git push --tags`) — their
   CI attaches `.deb`s to a GitHub Release.
2. Run **publish** → repo now has toolset, cxx, concurrentqueue, stduuid.
3. Tag `lux-communication` (its CI installs cxx/concurrentqueue/stduuid from this
   repo) → run **publish** again.
4. Tag `lux-dataset` → run **publish** again.

Adding a new package: append its repo name to `LUX_REPOS` in `publish.yml`.
