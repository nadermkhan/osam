#!/bin/bash
set -e

# Install a pinned version of xcodegen compatible with Xcode 15.4
if ! command -v xcodegen &> /dev/null; then
    echo "Installing xcodegen 2.38.0..."
    brew install xcodegen@2.38.0 || brew install xcodegen
fi

cat << 'EOF' > project.yml
name: Osam
options:
  bundleIdPrefix: com.osam
  xcodeVersion: "1540"
  deploymentTarget:
    iOS: "16.0"
targets:
  Osam:
    type: application
    platform: iOS
    deploymentTarget: "16.0"
    sources: [Osam]
    info:
      path: Osam/Info.plist
    settings:
      base:
        INFOPLIST_FILE: Osam/Info.plist
        PRODUCT_BUNDLE_IDENTIFIER: com.osam.editor
        TARGETED_DEVICE_FAMILY: "1,2"
        SWIFT_VERSION: "5.0"
EOF

echo "Generating Xcode project with xcodegen..."
xcodegen generate
echo "Done!"
