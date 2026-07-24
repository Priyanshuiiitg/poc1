
adb shell 'echo "Model: $(getprop ro.product.model)"; echo "ABI: $(getprop ro.product.cpu.abi)"; echo "Supported ABIs: $(getprop ro.product.cpu.abilist)"; echo "Kernel: $(uname -m)"; echo "Android: $(getprop ro.build.version.release)"'


# EuroOffice ARM64 Binary Extraction Process

This document outlines the exact procedure we used to obtain the natively compiled 64-bit ARM (`aarch64`) binaries and shared libraries for the EuroOffice `x2t` engine. 

To ensure maximum stability and avoid the complexities of cross-compiling the C++ core (and its massive dependencies like Google V8 and Qt) for ARM architectures, we bypassed compilation entirely. Instead, we programmatically extracted the official, production-ready `aarch64` binaries directly from the EuroOffice multi-architecture Docker image.

## 1. Authentication with GitHub Container Registry
We first generated a bearer token from the GitHub Container Registry (ghcr.io) to authenticate our requests for the EuroOffice image.

```bash
curl -s "https://ghcr.io/token?scope=repository:euro-office/documentserver:pull"
```

## 2. Locating the ARM64 Image Digest
The EuroOffice `documentserver:latest` tag points to an OCI Image Index containing multiple architectures. We queried this index to find the specific SHA256 digest for the `linux/arm64` image.

```bash
curl -s -H "Authorization: Bearer <TOKEN>" \
     -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.oci.image.index.v1+json" \
     https://ghcr.io/v2/euro-office/documentserver/manifests/latest
```
*This returned the `arm64` image digest (e.g., `sha256:cc052f723d...`).*

## 3. Fetching the ARM64 Layer Manifest
Using the `arm64` digest, we fetched the specific image manifest. A Docker image is composed of compressed tarball layers. We needed to identify which layers contained the actual EuroOffice installation (`/var/www/euro-office/documentserver`).

```bash
curl -s -H "Authorization: Bearer <TOKEN>" \
     -H "Accept: application/vnd.oci.image.manifest.v1+json" \
     https://ghcr.io/v2/euro-office/documentserver/manifests/sha256:cc052f723d...
```

## 4. Streaming and Extracting the Binaries (Without Docker)
Because our host machine was `x86_64`, a standard `docker pull` would fail or pull the wrong architecture. We also wanted to avoid downloading the entire 2GB image. 

Instead, we wrote a Node.js script to download *only* the specific layers we needed via `curl` and pipe them directly into `tar` for extraction on the host filesystem.

```bash
# We ran this for the specific layers containing the engine
curl -sL -H "Authorization: Bearer <TOKEN>" \
     https://ghcr.io/v2/euro-office/documentserver/blobs/<LAYER_DIGEST> | \
tar -xz -C /tmp/arm64-ext \
    --wildcards '*var/www/euro-office/documentserver/server/FileConverter/bin*' \
    --wildcards '*var/www/euro-office/documentserver/server/tools*' \
    --wildcards '*var/www/euro-office/documentserver/core-fonts*' \
    --wildcards '*var/www/euro-office/documentserver/sdkjs*'
```

## 5. Resulting Binaries
This process yielded the complete suite of official EuroOffice `aarch64` binaries and their dynamic libraries natively on our disk:

* `x2t` (The core Document Conversion Engine)
* `allfontsgen` (The Font Generator)
* `libx2tlib.so`, `libicuuc.so.74`, `libgraphics.so`, `libkernel.so`, etc.

## 6. The Userspace Injection (64-bit runtime)
Finally, because our target device had a 64-bit kernel but a 32-bit userspace, we also bundled the 64-bit Ubuntu GNU C Library (`libc.so.6`) and the 64-bit dynamic loader (`ld-linux-aarch64.so.1`). This allows the C# application to invoke the 64-bit loader directly, passing the `x2t` binary as a target, effectively running a 64-bit application seamlessly on top of the 64-bit kernel.
