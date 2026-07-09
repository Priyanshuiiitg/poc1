#!/bin/bash
set -e

echo "Preparing ARM64 Edge Release folder..."
rm -rf /tmp/edge-release-arm64
mkdir -p /tmp/edge-release-arm64/x2t-engine/server/FileConverter

echo "Copying Node wrapper code..."
cp -r /mnt/d/eurooffice-blackbox/package.json /tmp/edge-release-arm64/
cp -r /mnt/d/eurooffice-blackbox/server.js /tmp/edge-release-arm64/
cp -r /mnt/d/eurooffice-blackbox/public /tmp/edge-release-arm64/
cp -r /mnt/d/eurooffice-blackbox/setup-fonts.js /tmp/edge-release-arm64/
cp -r /mnt/d/eurooffice-blackbox/run-fonts.sh /tmp/edge-release-arm64/
cp -r /mnt/d/eurooffice-blackbox/test-native.sh /tmp/edge-release-arm64/

echo "Copying ARM64 Engine binaries..."
cp -r /tmp/arm64-ext/var/www/euro-office/documentserver/server/FileConverter/bin /tmp/edge-release-arm64/x2t-engine/server/FileConverter/
cp -r /tmp/arm64-ext/var/www/euro-office/documentserver/server/tools /tmp/edge-release-arm64/x2t-engine/server/
cp -r /mnt/d/eurooffice-blackbox/extracted_edge_files/x2t-engine/core-fonts /tmp/edge-release-arm64/x2t-engine/
cp -r /mnt/d/eurooffice-blackbox/extracted_edge_files/x2t-engine/sdkjs /tmp/edge-release-arm64/x2t-engine/
cp -r /mnt/d/eurooffice-blackbox/extracted_edge_files/x2t-engine/dictionaries /tmp/edge-release-arm64/x2t-engine/
cp -r /mnt/d/eurooffice-blackbox/extracted_edge_files/x2t-engine/web-apps /tmp/edge-release-arm64/x2t-engine/

echo "Compressing into eurooffice-edge-arm64.zip..."
cd /tmp/edge-release-arm64
zip -rq /mnt/d/eurooffice-blackbox/eurooffice-edge-arm64.zip .

echo "Done!"
