#!/usr/bin/env python3
"""Apply camera/gallery permissions and minimum platform versions to generated Flutter projects."""
from pathlib import Path
import plistlib
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]

manifest = root / "android/app/src/main/AndroidManifest.xml"
if manifest.exists():
    ET.register_namespace("android", "http://schemas.android.com/apk/res/android")
    tree = ET.parse(manifest)
    app = tree.getroot()
    ns = "{http://schemas.android.com/apk/res/android}"
    existing = {node.get(ns + "name") for node in app.findall("uses-permission")}
    if "android.permission.CAMERA" not in existing:
        node = ET.Element("uses-permission")
        node.set(ns + "name", "android.permission.CAMERA")
        app.insert(0, node)
    tree.write(manifest, encoding="utf-8", xml_declaration=True)

# camera 0.12.2 and gal 3.x require Android API 24 or newer.
for build_file in (
    root / "android/app/build.gradle.kts",
    root / "android/app/build.gradle",
):
    if build_file.exists():
        source = build_file.read_text()
        source = source.replace("minSdk = flutter.minSdkVersion", "minSdk = 24")
        source = source.replace("minSdkVersion flutter.minSdkVersion", "minSdkVersion 24")
        build_file.write_text(source)

info = root / "ios/Runner/Info.plist"
if info.exists():
    with info.open("rb") as stream:
        data = plistlib.load(stream)
    data["NSCameraUsageDescription"] = "Dou expo Beta needs camera access for live multi-exposure capture."
    data["NSPhotoLibraryAddUsageDescription"] = "Save rendered multi-exposure photos to your library."
    data["NSPhotoLibraryUsageDescription"] = "Choose photos to create multi-exposure images."
    # Audio capture is disabled (enableAudio: false), so microphone permission is not requested.
    with info.open("wb") as stream:
        plistlib.dump(data, stream)

podfile = root / "ios/Podfile"
if podfile.exists():
    source = podfile.read_text()
    source = source.replace("# platform :ios, '13.0'", "platform :ios, '13.0'")
    if "platform :ios," not in source:
        source = "platform :ios, '13.0'\n" + source
    podfile.write_text(source)
