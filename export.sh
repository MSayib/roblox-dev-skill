#!/bin/bash
# Export roblox-dev skill as a clean zip for GitHub publishing
# Usage: ./export.sh [output_dir]

set -e

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_NAME="roblox-dev-skill"
OUTPUT_DIR="${1:-$HOME/Desktop}"
TIMESTAMP=$(date +"%Y%m%d")
ZIP_NAME="${SKILL_NAME}-${TIMESTAMP}.zip"

echo "📦 Exporting ${SKILL_NAME}..."
echo "   Source: ${SKILL_DIR}"
echo "   Output: ${OUTPUT_DIR}/${ZIP_NAME}"

# Create temp directory for clean export
TEMP_DIR=$(mktemp -d)
EXPORT_DIR="${TEMP_DIR}/${SKILL_NAME}"
mkdir -p "${EXPORT_DIR}"

# Copy files (exclude hidden files, temp files)
cp "${SKILL_DIR}/SKILL.md" "${EXPORT_DIR}/"
cp "${SKILL_DIR}/README.md" "${EXPORT_DIR}/"
cp "${SKILL_DIR}/LICENSE" "${EXPORT_DIR}/"
cp "${SKILL_DIR}/metadata.json" "${EXPORT_DIR}/"
cp -r "${SKILL_DIR}/references" "${EXPORT_DIR}/"
cp -r "${SKILL_DIR}/evals" "${EXPORT_DIR}/"

# Create zip
cd "${TEMP_DIR}"
zip -r "${OUTPUT_DIR}/${ZIP_NAME}" "${SKILL_NAME}/" -x "*.DS_Store"

# Cleanup
rm -rf "${TEMP_DIR}"

echo ""
echo "✅ Exported successfully!"
echo "   📁 ${OUTPUT_DIR}/${ZIP_NAME}"
echo ""
echo "   Files included:"
find "${SKILL_DIR}" -type f \
  ! -name ".*" \
  ! -name "export.sh" \
  ! -path "*/\.*" \
  -exec basename {} \; | sort | sed 's/^/      /'
echo ""
echo "   Next steps:"
echo "   1. Extract and push to GitHub"
echo "   2. Update README.md with your GitHub username"
echo "   3. Add topics: roblox, luau, ai-skills, claude-code, roblox-studio"
