#!/usr/bin/env python3
"""
Script to create Xcode project for MathQuizGame
"""

import os
import uuid
import plistlib
from pathlib import Path

PROJECT_NAME = "MathQuizGame"
CURRENT_DIR = Path(__file__).parent

# Generate UUIDs for project structure
def generate_uuid():
    return str(uuid.uuid4()).upper().replace('-', '')

# Create project structure
project_dir = CURRENT_DIR / f"{PROJECT_NAME}.xcodeproj"
project_dir.mkdir(exist_ok=True)

workspace_dir = project_dir / "project.xcworkspace"
workspace_dir.mkdir(exist_ok=True)

schemes_dir = project_dir / "xcshareddata" / "xcschemes"
schemes_dir.mkdir(parents=True, exist_ok=True)

# Create workspace file
workspace_content = '''<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
'''
(workspace_dir / "contents.xcworkspacedata").write_text(workspace_content)

# Create scheme file
scheme_content = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1500"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "MAIN_TARGET_ID"
               BuildableName = "{PROJECT_NAME}.app"
               BlueprintName = "{PROJECT_NAME}"
               ReferencedContainer = "container:{PROJECT_NAME}.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "MAIN_TARGET_ID"
            BuildableName = "{PROJECT_NAME}.app"
            BlueprintName = "{PROJECT_NAME}"
            ReferencedContainer = "container:{PROJECT_NAME}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "MAIN_TARGET_ID"
            BuildableName = "{PROJECT_NAME}.app"
            BlueprintName = "{PROJECT_NAME}"
            ReferencedContainer = "container:{PROJECT_NAME}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
'''
(schemes_dir / f"{PROJECT_NAME}.xcscheme").write_text(scheme_content)

print(f"Created Xcode project structure for {PROJECT_NAME}")
print(f"Project directory: {project_dir}")
print("\nNote: You still need to:")
print("1. Open Xcode")
print("2. Create a new iOS App project with the same name")
print("3. Replace the generated files with the existing Swift files")
print("4. Or manually create the project.pbxproj file")
print("\nAlternatively, install xcodegen: brew install xcodegen")
print("Then run: xcodegen generate")

