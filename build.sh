#!/usr/bin/env bash
# Builds the watch app (.prg) for sideloading.
#   SERVER   address of your Chorus server, e.g. https://chorus.example.org (baked into the app)
#   KEY      Connect IQ developer key (DER), create once:
#            openssl genrsa -out key.pem 4096 && openssl pkcs8 -topk8 -inform PEM -outform DER -in key.pem -out developer_key.der -nocrypt
#   DEVICE   default venu3 (device files must be installed with the Connect IQ SDK Manager)
#   MONKEYC  path to monkeyc from the Connect IQ SDK (default: monkeyc in PATH)
set -euo pipefail
cd "$(dirname "$0")"
: "${SERVER:?set SERVER=https://your-chorus-server}"
: "${KEY:?set KEY=/path/to/developer_key.der}"
DEVICE=${DEVICE:-venu3}
OUT=${OUT:-bin/chorus-$DEVICE.prg}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp -r manifest.xml monkey.jungle resources resources-deu source "$tmp"/
sed -i.bak "s#https://chorus.example.org#${SERVER%/}#" "$tmp/resources/properties/properties.xml" && rm -f "$tmp/resources/properties/properties.xml.bak"
mkdir -p "$(dirname "$OUT")"
"${MONKEYC:-monkeyc}" -d "$DEVICE" -f "$tmp/monkey.jungle" -o "$OUT" -y "$KEY" -r -w
echo "built $OUT"
