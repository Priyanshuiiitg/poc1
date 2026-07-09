const fs = require('fs');
const { execSync } = require('child_process');

async function downloadARM64() {
    try {
        console.log("Getting token...");
        let res = await fetch("https://ghcr.io/token?scope=repository:euro-office/documentserver:pull");
        let json = await res.json();
        let token = json.token;

        let manifestStr = fs.readFileSync("arm64_manifest.json", "utf8");
        let manifest = JSON.parse(manifestStr);

        console.log("Preparing extraction directory in WSL...");
        execSync('wsl bash -c "mkdir -p /tmp/arm64-ext"');

        // We only care about layers that might have our binaries.
        // Usually, the binaries are in the largest layers.
        // Let's iterate and extract specific directories.
        let dirsToExtract = [
            "var/www/euro-office/documentserver/server/FileConverter/bin",
            "var/www/euro-office/documentserver/server/tools",
            "var/www/euro-office/documentserver/core-fonts",
            "var/www/euro-office/documentserver/sdkjs"
        ].join(' ');

        for (let i = 0; i < manifest.layers.length; i++) {
            let layer = manifest.layers[i];
            console.log(`Downloading and extracting layer ${i + 1}/${manifest.layers.length} (${layer.digest}) ...`);
            
            // We use curl to stream the layer directly into tar. We use --wildcards to avoid failing if the dir doesn't exist.
            let cmd = `wsl bash -c "curl -sL -H 'Authorization: Bearer ${token}' https://ghcr.io/v2/euro-office/documentserver/blobs/${layer.digest} | tar -xz -C /tmp/arm64-ext --wildcards '*var/www/euro-office/documentserver/server/FileConverter/bin*' '*var/www/euro-office/documentserver/server/tools*' 2>/dev/null || true"`;
            
            console.log(`Executing layer extraction...`);
            execSync(cmd, { stdio: 'inherit' });
        }

        console.log("Extraction complete!");

    } catch(e) {
        console.error(e);
    }
}

downloadARM64();
