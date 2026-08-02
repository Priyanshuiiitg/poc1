# EuroOffice 32-bit ARM Compilation and Execution Log

This document provides a factual, step-by-step record of the actions taken to compile the EuroOffice core components for a 32-bit ARM Tizen edge device, the errors encountered, and the fixes applied.

## 1. Environment Setup

*   **Environment**: An emulated 32-bit ARM environment using Docker (`eurooffice_builder` container) and `qemu-arm-static`.
*   **Source Code Location**: The EuroOffice core source code was mounted or cloned into `/workspace/eurooffice-core-arm32/`.

## 2. Initial Compilation and Hardening Adjustments

### Action
We compiled the source code using the provided build scripts. 

### Error Encountered
During initial tests on the Tizen device, we encountered linker errors indicating missing symbols, specifically:
*   Undefined reference to `__stack_chk_guard`.
*   Issues loading `ld-linux-armhf.so.3` (Tizen uses `ld-linux.so.3` or `ld-2.30.so` instead).

### Fix Applied
To prevent the compiler from generating stack-smashing protection code that relied on the missing `__stack_chk_guard` symbol, we modified the project's CMake configuration.

**Modified Files:**
*   `/workspace/eurooffice-core-arm32/CMakeLists.txt`
*   `/workspace/eurooffice-core-arm32/DesktopEditor/doctrenderer/CMakeLists.txt`

**Added Flags:**
```cmake
add_compile_options(-fno-stack-protector)
add_link_options(-Wl,--allow-shlib-undefined)
```
After making these changes, the project was recompiled from scratch. The output binaries were generated in `/workspace/eurooffice-core-arm32/build/package/`.

## 3. Post-Compilation Binary Patching (First Attempt)

### Action
Because the compiled binaries still referenced `ld-linux-armhf.so.3` (the default linker name in our Ubuntu/Debian-based ARM cross-compilation environment), we attempted to modify the ELF headers of the shared objects (`.so`) and the main executable (`x2t`) using the `patchelf` utility.

**Command Example:**
```bash
patchelf --remove-needed ld-linux-armhf.so.3 <binary_name>
patchelf --set-rpath '$ORIGIN' <binary_name>
```

### Error Encountered
When executing the modified binaries on the Tizen device, the linker crashed with `internal error` or "cannot open shared object file". 

Upon inspecting the ELF dynamic sections (`readelf -d`), we discovered that the `RUNPATH`/`RPATH` variables in the binaries (such as `libicuuc.so.74.2`) were corrupted. Specifically, the intended path `$ORIGIN` had been written as `RIGIN:`.

**Reason for Error:** 
When the `patchelf` command was executed via a bash shell script, bash eagerly evaluated the `$ORIGIN` string as an environment variable (which was empty), effectively stripping it from the string and shifting the bytes, corrupting the ELF string tables. Furthermore, `patchelf` shifted offsets in the dynamic table which the Tizen linker could not process correctly.

## 4. Recovering Pristine Binaries and Custom Patching

### Action
To resolve the binary corruption, we discarded the `patchelf`-modified binaries and retrieved the pristine, untouched binaries from the compilation work directory (`/workspace/eurooffice-core-arm32/third_party/work/`).

Instead of using `patchelf`, we developed a custom Python script (`fix_runpath.py`) to perform direct byte-level manipulation of the ELF files.

**Script Logic:**
1.  Parse the ELF headers to locate the `.dynamic` section.
2.  Identify the `DT_RUNPATH` and `DT_RPATH` tags.
3.  Locate the corresponding string in the `.dynstr` (dynamic string table).
4.  Directly overwrite the corrupted string (e.g., `RIGIN:$ORIGIN:...` or `$ORIGIN:$ORIGIN/system`) with `$ORIGIN` and pad the remainder of the original string length with null bytes (`\x00`).
5.  This ensured that the file size and all internal offsets remained mathematically identical, avoiding the structural corruption caused by `patchelf`.

### Execution
We ran the script against all `.so` files and the `x2t` binary in the `/workspace/eurooffice-core-arm32/build/package/` directory.

```bash
docker exec eurooffice_builder python3 /workspace/fix_runpath.py /workspace/eurooffice-core-arm32/build/package/
```

### Verification in QEMU
We tested the patched `x2t` binary directly inside the emulated ARM environment:
```bash
docker exec -e QEMU_LD_PREFIX=/usr/arm-linux-gnueabihf eurooffice_builder sh -c "export LD_LIBRARY_PATH=/workspace/eurooffice-core-arm32/build/package && /workspace/eurooffice-core-arm32/build/package/x2t"
```
**Result:** The command successfully printed the `x2t` usage banner (`Empty sFileFrom or sFileTo`), confirming that all shared libraries loaded flawlessly in the emulated environment.

## 5. Deployment and Testing on Tizen Device

### Action
We compressed the fixed package directory into a tarball (`x2t_fixed_v2.tar.gz`) and transferred it to the Tizen edge device.

On the Tizen device, the user extracted the files, applied security labels using `chsmack -a "_" *`, and executed the binary.

### Error Encountered
Despite the binary working in QEMU, executing it on the physical Tizen device yielded the following results:

1.  **Test Executable:** Running a simple compiled test executable (`./test_hard`) succeeded and printed "Hello from HARD float!".
2.  **`x2t` Execution:** Running `./x2t --help` resulted in:
    ```
    ./x2t: error while loading shared libraries: /usr/lib/x2t-engine/server/FileConverter/bin/libx2tlib.so: internal error
    ```
3.  **Direct Shared Library Execution:** Running `./libx2tlib.so` resulted in:
    ```
    Illegal instruction (core dumped)
    ```
4.  **`ldd` Check:** Running `ldd x2t` resulted in:
    ```
    not a dynamic executable
    ```

This is the current state of the compilation and execution process.
