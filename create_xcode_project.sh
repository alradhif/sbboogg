#!/bin/bash

# Script to create Xcode project for MathQuizGame

PROJECT_NAME="MathQuizGame"
PROJECT_DIR="$(pwd)"
BUILD_DIR="$PROJECT_DIR/build"

# Clean up any existing project
rm -rf "$PROJECT_NAME.xcodeproj"
rm -rf "$PROJECT_NAME.xcworkspace"

# Create project directory structure
mkdir -p "$PROJECT_NAME.xcodeproj/project.xcworkspace/xcshareddata"
mkdir -p "$PROJECT_NAME.xcodeproj/xcshareddata/xcschemes"

# Create workspace settings
cat > "$PROJECT_NAME.xcodeproj/project.xcworkspace/contents.xcworkspacedata" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
EOF

# Note: Creating a full .pbxproj file manually is complex
# Instead, we'll create a script that opens Xcode to create the project
# Or use xcodegen if available

echo "Xcode project structure created."
echo "Please open Xcode and create a new iOS App project named '$PROJECT_NAME'"
echo "Then add all the Swift files to the project."
echo ""
echo "Alternatively, install xcodegen and use the project.yml file."

