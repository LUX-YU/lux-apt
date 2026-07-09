#!/usr/bin/env bash
# Build arch:all .debs for the header-only third-party libraries that
# lux-communication needs but Ubuntu does not package:
#   - moodycamel concurrentqueue  (node: PUBLIC/transitive dep)
#   - mariusbancila stduuid       (node: PRIVATE/build-only dep)
#
# Both are header-only and ship a CMake config package, so we install them to
# /usr in a staging dir and wrap that with a hand-written control file. The
# package name matches the find_package() name the LUX projects use, so
# `find_package(concurrentqueue CONFIG)` / `find_package(stduuid CONFIG)` resolve.
#
# Usage: build-thirdparty-debs.sh <output-pool-dir>
set -euo pipefail

POOL="${1:?output pool dir required}"
mkdir -p "$POOL"
WORK="$(mktemp -d)"
MAINT="LUX-YU <chenhui.lux.yu@outlook.com>"

# build_deb <name> <version> <srcdir> <extra-cmake-args>
build_deb() {
  local name="$1" ver="$2" src="$3" extra="$4"
  local stage="$WORK/${name}-stage"
  rm -rf "$stage"
  # shellcheck disable=SC2086
  cmake -S "$src" -B "$WORK/${name}-build" -DCMAKE_INSTALL_PREFIX=/usr $extra >/dev/null
  DESTDIR="$stage" cmake --install "$WORK/${name}-build" >/dev/null
  mkdir -p "$stage/DEBIAN"
  cat > "$stage/DEBIAN/control" <<EOF
Package: ${name}
Version: ${ver}
Architecture: all
Maintainer: ${MAINT}
Section: libdevel
Priority: optional
Description: ${name} (header-only third-party lib, repackaged for the LUX apt repo)
EOF
  # -Zxz: Ubuntu 22.04's dpkg-deb defaults to zstd (control.tar.zst), which the
  # aptly shipped in 22.04 cannot read. xz is understood by every aptly version.
  dpkg-deb --root-owner-group -Zxz --build "$stage" "$POOL/${name}_${ver}_all.deb"
}

# --- concurrentqueue (moodycamel) ---
git clone --depth 1 --branch v1.0.4 https://github.com/cameron314/concurrentqueue "$WORK/concurrentqueue"
build_deb concurrentqueue 1.0.4 "$WORK/concurrentqueue" ""

# --- stduuid ---
# C++20 std::span avoids the optional gsl dependency; system generator off so we
# don't need libuuid on the build host.
git clone --depth 1 --branch v1.2.3 https://github.com/mariusbancila/stduuid "$WORK/stduuid"
build_deb stduuid 1.2.3 "$WORK/stduuid" "-DUUID_BUILD_TESTS=OFF -DUUID_USING_CXX20_SPAN=ON -DUUID_SYSTEM_GENERATOR=OFF"

echo "Built third-party .debs:"
ls -1 "$POOL"
