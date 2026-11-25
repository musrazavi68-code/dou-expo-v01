#!/usr/bin/env python3
"""Apply camera and photo-library usage descriptions to generated Flutter platforms."""
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
    for permission in ("android.permission.CAMERA",):
        if permission not in existing:
            node = ET.Element("uses-permission")
            node.set(ns + "name", permission)
            app.insert(0, node)
    tree.write(manifest, encoding="utf-8", xml_declaration=True)

info = root / "ios/Runner/Info.plist"
if info.exists():
    with info.open("rb") as stream:
        data = plistlib.load(stream)
    data["NSCameraUsageDescription"] = "Dou expo Beta needs camera access for live multi-exposure capture."
    data["NSPhotoLibraryAddUsageDescription"] = "Save rendered multi-exposure photos to your library."
    data["NSPhotoLibraryUsageDescription"] = "Choose photos to create multi-exposure images."
    # Audio capture is disabled (enableAudio: false), so microphone permission is intentionally not requested.
    with info.open("wb") as stream:
        plistlib.dump(data, stream)
