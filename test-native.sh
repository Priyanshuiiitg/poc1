#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: ./test-native.sh <path-to-document.docx>"
    exit 1
fi

INPUT_DOC=$(realpath "$1")
OUTPUT_PDF=$(realpath "${1%.*}.pdf")
XML_FILE="/tmp/test.xml"
DIR="$(cd "$(dirname "$0")" && pwd)"
FONT_DIR="$DIR/x2t-engine/core-fonts"

cat <<EOF > $XML_FILE
<?xml version="1.0" encoding="utf-8"?>
<TaskQueueDataConvert>
    <m_sFileFrom>$INPUT_DOC</m_sFileFrom>
    <m_sFileTo>$OUTPUT_PDF</m_sFileTo>
    <m_nFormatTo>513</m_nFormatTo>
    <m_bIsNoBase64>true</m_bIsNoBase64>
    <m_sFontDir>$FONT_DIR</m_sFontDir>
</TaskQueueDataConvert>
EOF

echo "Testing native Linux execution (NO Docker)..."
cd "$DIR/x2t-engine/server/FileConverter/bin"

export LD_LIBRARY_PATH=.:$LD_LIBRARY_PATH
./x2t $XML_FILE

echo "Done! Check if $OUTPUT_PDF was created."
