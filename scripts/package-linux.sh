#!/usr/bin/env bash
set -euo pipefail

tag=${1:?release tag}
arch=${2:?x64 or arm64}
[[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-(alpha|beta|rc)\.[0-9]+)?$ ]]
case "$arch" in x64) deb_arch=amd64 ;; arm64) deb_arch=arm64 ;; *) exit 1 ;; esac
root=$(pwd)
out="$root/release-assets"
stage="$root/linux/target/package"
mkdir -p "$out" "$stage/gui/usr/bin" "$stage/gui/usr/share/applications" \
  "$stage/gui/usr/share/icons" "$stage/gui/usr/share/doc/meshdrop" "$stage/tui"
install -m755 linux/target/release/meshdrop "$stage/gui/usr/bin/meshdrop"
install -m644 linux/data/meshdrop.desktop "$stage/gui/usr/share/applications/meshdrop.desktop"
cp -R linux/data/icons/. "$stage/gui/usr/share/icons/"
cp LICENSE "$stage/gui/usr/share/doc/meshdrop/copyright"
cp linux/Cargo.lock "$stage/gui/usr/share/doc/meshdrop/Cargo.lock"
cp linux/target/release/meshdrop-tui "$stage/tui/"
cp LICENSE linux/Cargo.lock "$stage/tui/"
cat > "$stage/tui/README.txt" <<'EOF'
Run ./meshdrop-tui for the interactive terminal, or ./meshdrop-tui --help for CLI commands.
Linux x64 / ARM64; Ubuntu 24.04 or newer (glibc 2.39+). GTK is not required.
This is the experimental 0.1.0 plaintext client; it cannot connect directly to Apple/Windows TLS clients.
EOF
tar -czf "$out/MeshDrop-$tag-linux-gui-$arch.tar.gz" -C "$stage/gui" usr
tar -czf "$out/MeshDrop-$tag-linux-tui-$arch.tar.gz" -C "$stage/tui" .

mkdir -p "$stage/gui/DEBIAN"
# dpkg-shlibdeps records the actual GTK, libadwaita and glibc requirements.
mkdir -p "$stage/debian"
printf 'Source: meshdrop\n\nPackage: meshdrop\nArchitecture: any\n' > "$stage/debian/control"
dependencies=$(cd "$stage" && dpkg-shlibdeps --ignore-missing-info -O "gui/usr/bin/meshdrop" | sed -n 's/^shlibs:Depends=//p')
test -n "$dependencies"
version=${tag#v}
version=${version/-/~}
cat > "$stage/gui/DEBIAN/control" <<EOF
Package: meshdrop
Version: $version
Architecture: $deb_arch
Maintainer: MeshDrop maintainers
Section: net
Priority: optional
Depends: $dependencies
Description: Native LAN sharing with a GTK4 desktop interface
 Experimental plaintext protocol client; Apple/Windows TLS clients are not yet compatible.
EOF
dpkg-deb --root-owner-group --build "$stage/gui" "$out/MeshDrop-$tag-linux-gui-$arch.deb"
dpkg-deb --info "$out/MeshDrop-$tag-linux-gui-$arch.deb"
