#!/bin/bash
set -e
echo "Starting Edge Release Build inside WSL..."

# Check dependencies
if ! command -v zip &> /dev/null; then
    echo "zip command not found. Installing..."
    sudo apt-get update && sudo apt-get install -y zip
fi

rm -rf /tmp/edge-release
mkdir -p /tmp/edge-release/x2t-engine/fonts

# Copy Node files
cp -r /mnt/d/eurooffice-blackbox/server.js /tmp/edge-release/
cp -r /mnt/d/eurooffice-blackbox/package.json /tmp/edge-release/
cp -r /mnt/d/eurooffice-blackbox/public /tmp/edge-release/

echo "Starting Docker extraction..."
docker rm -f temp-edge-eo || true
docker run -d --name temp-edge-eo ghcr.io/euro-office/documentserver:latest

echo "Waiting 35 seconds for AllFonts.js to compile..."
sleep 35

echo "Extracting bins (symlinks will be preserved in ext4!)..."
docker cp temp-edge-eo:/var/www/euro-office/documentserver/server/FileConverter/bin /tmp/edge-release/x2t-engine/
docker cp temp-edge-eo:/var/www/euro-office/documentserver/core-fonts /tmp/edge-release/x2t-engine/fonts/

docker rm -f temp-edge-eo

echo "Zipping the release..."
cd /tmp/edge-release
# The -y flag ensures symbolic links are preserved as links in the zip file
zip -ry /mnt/d/eurooffice-blackbox/eurooffice-edge.zip .

echo "Done! /mnt/d/eurooffice-blackbox/eurooffice-edge.zip created successfully."
