#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"

BIN_DIR="$DIR/x2t-engine/server/FileConverter/bin"
TOOLS_DIR="$DIR/x2t-engine/server/tools"
CORE_FONTS="$DIR/x2t-engine/core-fonts"
SDKJS_COMMON="$DIR/x2t-engine/sdkjs/common"
FONTS_WEB="$DIR/x2t-engine/fonts"

chmod +x "$TOOLS_DIR/allfontsgen" 2>/dev/null || true
touch "$BIN_DIR/AllFonts.js" "$BIN_DIR/font_selection.bin" 2>/dev/null || true
chmod 777 "$BIN_DIR/AllFonts.js" "$BIN_DIR/font_selection.bin" 2>/dev/null || true

export LD_LIBRARY_PATH="$BIN_DIR:$LD_LIBRARY_PATH"

"$TOOLS_DIR/allfontsgen" \
  --input="$CORE_FONTS" \
  --allfonts-web="$SDKJS_COMMON/AllFonts.js" \
  --allfonts="$BIN_DIR/AllFonts.js" \
  --images="$SDKJS_COMMON/Images" \
  --selection="$BIN_DIR/font_selection.bin" \
  --output-web="$FONTS_WEB" \
  --use-system="false" \
  --use-system-user-fonts="false"
