#!/usr/bin/env bash
# Download and build libevent with musl libc.
set -euo pipefail

LIBEVENT_VERSION="2.1.12-stable"
LIBEVENT_URL="https://github.com/libevent/libevent/releases/download/release-${LIBEVENT_VERSION}/libevent-${LIBEVENT_VERSION}.tar.gz"
PREFIX="${LIBEVENT_INSTALL_PREFIX:-$PWD/install}"
JOBS="${JOBS:-$(nproc)}"

echo "==> Installing build dependencies"
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends gcc musl-tools make wget ca-certificates

echo "==> Downloading libevent ${LIBEVENT_VERSION}"
mkdir -p download
cd download
if [ ! -f "libevent-${LIBEVENT_VERSION}.tar.gz" ]; then
    wget -q "${LIBEVENT_URL}"
fi
tar xf "libevent-${LIBEVENT_VERSION}.tar.gz"
cd "libevent-${LIBEVENT_VERSION}"

echo "==> Configuring libevent with musl-gcc"
CC=musl-gcc ./configure \
    --prefix="${PREFIX}" \
    --disable-shared \
    --enable-static \
    --disable-openssl \
    --disable-libevent-regress

echo "==> Building (${JOBS} jobs)"
make -j"${JOBS}"

echo "==> Installing to ${PREFIX}"
make install

echo "==> Verifying static library and musl linkage"
ls -l "${PREFIX}/lib"
cat > /tmp/linktest.c <<'EOF'
#include <event2/event.h>
#include <stdio.h>
int main(void) {
    printf("libevent %s\n", event_get_version());
    return 0;
}
EOF
musl-gcc /tmp/linktest.c -I"${PREFIX}/include" -L"${PREFIX}/lib" \
    -levent -levent_core -o "${PREFIX}/linktest" -static
"${PREFIX}/linktest"
file "${PREFIX}/linktest" | grep -q "statically linked" \
    && echo "==> OK: statically linked with musl"

echo "==> libevent built successfully with musl"
