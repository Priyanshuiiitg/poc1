const fs = require('fs');
const { execSync } = require('child_process');

async function checkArchitectures() {
    try {
        console.log("Getting token...");
        let res = await fetch("https://ghcr.io/token?scope=repository:euro-office/documentserver:pull");
        let json = await res.json();
        let token = json.token;

        console.log("Fetching index manifest...");
        let manifestRes = await fetch("https://ghcr.io/v2/euro-office/documentserver/manifests/latest", {
            headers: {
                "Authorization": `Bearer ${token}`,
                "Accept": "application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.oci.image.index.v1+json"
            }
        });
        
        let manifest = await manifestRes.json();
        console.log(JSON.stringify(manifest, null, 2));
    } catch(e) {
        console.error(e);
    }
}

checkArchitectures();
