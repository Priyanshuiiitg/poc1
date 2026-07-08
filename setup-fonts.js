const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const isWindows = process.platform === 'win32';

if (isWindows) {
    console.log("Skipping native font generation on Windows (using Docker Wrapper).");
    process.exit(0);
}

console.log("Generating native Linux font cache for the Edge environment...");

const appRoot = path.resolve(__dirname);
const engineRoot = path.resolve(appRoot, 'x2t-engine');
const binDir = path.resolve(engineRoot, 'server/FileConverter/bin');
const toolsDir = path.resolve(engineRoot, 'server/tools');
const coreFontsDir = path.resolve(engineRoot, 'core-fonts');
const sdkjsCommonDir = path.resolve(engineRoot, 'sdkjs/common');
const fontsWebDir = path.resolve(engineRoot, 'fonts');

// Ensure fonts web directory exists
if (!fs.existsSync(fontsWebDir)) {
    fs.mkdirSync(fontsWebDir, { recursive: true });
}

// Find the correct casing for allfontsgen
let allfontsgen = path.resolve(toolsDir, 'allfontsgen');
if (!fs.existsSync(allfontsgen)) {
    allfontsgen = path.resolve(toolsDir, 'AllFontsGen');
}
if (!fs.existsSync(allfontsgen)) {
    console.warn("WARNING: allfontsgen binary not found! Skipping font generation.");
    process.exit(0);
}

// Make it executable
execSync(`chmod +x "${allfontsgen}"`);

const cmd = `"${allfontsgen}" ` +
    `--input="${coreFontsDir}" ` +
    `--allfonts-web="${path.resolve(sdkjsCommonDir, 'AllFonts.js')}" ` +
    `--allfonts="${path.resolve(binDir, 'AllFonts.js')}" ` +
    `--images="${path.resolve(sdkjsCommonDir, 'Images')}" ` +
    `--selection="${path.resolve(binDir, 'font_selection.bin')}" ` +
    `--output-web="${fontsWebDir}" ` +
    `--use-system="false" ` +
    `--use-system-user-fonts="false"`;

try {
    console.log(`Running: ${cmd}`);
    execSync(`export LD_LIBRARY_PATH="${binDir}:$LD_LIBRARY_PATH" && ${cmd}`, { stdio: 'inherit' });
    console.log("Font generation completely successfully!");
} catch (e) {
    console.error("Failed to generate native fonts.");
    process.exit(1);
}
