#!/bin/bash
set -e

# Install xcodegen if not present (GitHub Actions macos-14 runner usually has brew)
if ! command -v xcodegen &> /dev/null; then
    echo "Installing xcodegen..."
    brew install xcodegen
fi

cat << 'EOF' > project.yml
name: Osam
options:
  bundleIdPrefix: com.osam
targets:
  Osam:
    type: application
    platform: iOS
    deploymentTarget: "16.0"
    sources: [Osam]
    info:
      path: Osam/Info.plist
EOF

echo "Generating Xcode project with xcodegen..."
xcodegen generate
echo "Done!"
