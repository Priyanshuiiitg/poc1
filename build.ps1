$ErrorActionPreference = "Stop"

Write-Host "Starting temporary Docker container..."
$ErrorActionPreference = "Continue"
docker rm -f temp-edge-eo 2>$null
$ErrorActionPreference = "Stop"
docker run -d --name temp-edge-eo ghcr.io/euro-office/documentserver:latest

Write-Host "Waiting 35 seconds for AllFonts.js to compile..."
Start-Sleep -Seconds 35

Write-Host "Archiving bin and core-fonts inside the container..."
docker exec temp-edge-eo tar -cf /tmp/bin.tar -C /var/www/euro-office/documentserver/server/FileConverter bin
docker exec temp-edge-eo tar -cf /tmp/fonts.tar -C /var/www/euro-office/documentserver core-fonts

Write-Host "Copying tar archives to Windows host..."
docker cp temp-edge-eo:/tmp/bin.tar D:\eurooffice-blackbox\bin.tar
docker cp temp-edge-eo:/tmp/fonts.tar D:\eurooffice-blackbox\fonts.tar

docker rm -f temp-edge-eo

Write-Host "Preparing WSL native filesystem..."
wsl rm -rf /tmp/edge-release
wsl mkdir -p /tmp/edge-release/x2t-engine/fonts

Write-Host "Extracting tar archives natively in WSL (symlinks preserved!)..."
wsl tar -xf /mnt/d/eurooffice-blackbox/bin.tar -C /tmp/edge-release/x2t-engine/
wsl tar -xf /mnt/d/eurooffice-blackbox/fonts.tar -C /tmp/edge-release/x2t-engine/fonts/

Write-Host "Copying Node.js backend files..."
wsl cp -r /mnt/d/eurooffice-blackbox/server.js /tmp/edge-release/
wsl cp -r /mnt/d/eurooffice-blackbox/package.json /tmp/edge-release/
wsl cp -r /mnt/d/eurooffice-blackbox/public /tmp/edge-release/

Write-Host "Checking for zip in WSL..."
wsl bash -c "if ! command -v zip &> /dev/null; then sudo apt-get update && sudo apt-get install -y zip; fi"

Write-Host "Zipping the final release package..."
wsl bash -c "cd /tmp/edge-release && zip -ry /mnt/d/eurooffice-blackbox/eurooffice-edge.zip ."

Write-Host "Cleaning up temporary files..."
$ErrorActionPreference = "Continue"
Remove-Item D:\eurooffice-blackbox\bin.tar
Remove-Item D:\eurooffice-blackbox\fonts.tar
$ErrorActionPreference = "Stop"
wsl rm -rf /tmp/edge-release

Write-Host "Done! D:\eurooffice-blackbox\eurooffice-edge.zip successfully created."
