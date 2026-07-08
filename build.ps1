$ErrorActionPreference = "Stop"

Write-Host "Starting temporary Docker container..."
$ErrorActionPreference = "Continue"
docker rm -f temp-edge-eo 2>$null
$ErrorActionPreference = "Stop"
docker run -d --name temp-edge-eo ghcr.io/euro-office/documentserver:latest

Write-Host "Waiting 35 seconds for AllFonts.js to compile..."
Start-Sleep -Seconds 35

Write-Host "Archiving full x2t engine tree inside the container..."
# We package all directories relative to documentserver to preserve the exact tree
docker exec temp-edge-eo tar -cf /tmp/engine.tar -C /var/www/euro-office/documentserver server/FileConverter/bin server/tools sdkjs dictionaries core-fonts web-apps/vendor

Write-Host "Copying tar archive to Windows host..."
docker cp temp-edge-eo:/tmp/engine.tar D:\eurooffice-blackbox\engine.tar

$ErrorActionPreference = "Continue"
docker rm -f temp-edge-eo 2>$null
$ErrorActionPreference = "Stop"

Write-Host "Preparing WSL native filesystem..."
$ErrorActionPreference = "Continue"
wsl -u root rm -rf /tmp/edge-release
$ErrorActionPreference = "Stop"
wsl mkdir -p /tmp/edge-release/x2t-engine

Write-Host "Extracting full engine natively in WSL (symlinks preserved!)..."
wsl tar -xf /mnt/d/eurooffice-blackbox/engine.tar -C /tmp/edge-release/x2t-engine/

Write-Host "Copying Node.js backend files..."
wsl cp -r /mnt/d/eurooffice-blackbox/server.js /tmp/edge-release/
wsl cp -r /mnt/d/eurooffice-blackbox/package.json /tmp/edge-release/
wsl cp -r /mnt/d/eurooffice-blackbox/public /tmp/edge-release/
wsl cp -r /mnt/d/eurooffice-blackbox/setup-fonts.js /tmp/edge-release/
wsl cp -r /mnt/d/eurooffice-blackbox/run-fonts.sh /tmp/edge-release/
wsl cp -r /mnt/d/eurooffice-blackbox/test-native.sh /tmp/edge-release/

Write-Host "Checking for zip in WSL..."
wsl bash -c "if ! command -v zip &> /dev/null; then sudo apt-get update && sudo apt-get install -y zip; fi"

Write-Host "Zipping the final full-stack release package..."
wsl bash -c "cd /tmp/edge-release && zip -ry /mnt/d/eurooffice-blackbox/eurooffice-edge.zip ."

Write-Host "Cleaning up temporary files..."
$ErrorActionPreference = "Continue"
Remove-Item D:\eurooffice-blackbox\engine.tar
wsl -u root rm -rf /tmp/edge-release
$ErrorActionPreference = "Stop"

Write-Host "Done! D:\eurooffice-blackbox\eurooffice-edge.zip successfully created."
