# Android Camera2 native integration status

## Implemented in this branch
- Local Expo module registration under `modules/dou-expo-camera`.
- Runtime camera discovery by requested lens facing.
- Capability metadata from CameraCharacteristics: manual sensor capability, ISO range, exposure-time range, manual post-processing capability, AF modes, minimum focus distance, AWB modes, AE compensation range, focal lengths, zoom ratio range (API 30+), flash availability and hardware level.
- Native zoom tick and shutter haptic feedback.
- JavaScript currently reads and displays camera capability ranges; camera preview and still capture are still owned by `expo-camera`.

## Not implemented yet — do not expose as working controls
The module does **not** own a CameraDevice, CameraCaptureSession, ImageReader, Surface or CaptureRequest. Therefore it cannot currently apply manual ISO, exposure time, lens focus distance or AWB to the live preview or captured image. Capability discovery is not equivalent to manual camera control.

## Required next engineering step
Implement a native Android view (Expo View/React Native view manager) that owns one Camera2 pipeline:
1. Open the selected camera on a dedicated HandlerThread after CAMERA permission is granted.
2. Create a preview Surface and an ImageReader JPEG/YUV output surface.
3. Configure one CameraCaptureSession with preview and still-capture outputs.
4. Apply validated CONTROL_MODE, AE_MODE, SENSOR_SENSITIVITY, SENSOR_EXPOSURE_TIME, LENS_FOCUS_DISTANCE, CONTROL_AF_MODE, CONTROL_AWB_MODE and CONTROL_AWB_LOCK keys according to camera capabilities.
5. Rebuild requests when controls change; keep auto modes as safe fallbacks.
6. Capture a still from the same session and return an app-readable URI; do not open a second camera from expo-camera.
7. Handle lifecycle, rotation, camera switching, device disconnect, permission revocation, session failure and release of every Surface/Image/CameraDevice.
8. Only then add live focus peaking from YUV frames, with throttling and a switch to avoid unnecessary GPU/CPU load.

## Compatibility and validation
- Camera2 manual controls are device-specific. Check REQUEST_AVAILABLE_CAPABILITIES_MANUAL_SENSOR and per-key ranges before enabling controls.
- Focus distance is measured in diopters; zero means infinity. A positive minimum-focus-distance is required for manual lens positioning.
- AWB modes must be selected from CONTROL_AWB_AVAILABLE_MODES, not assumed.
- Zoom ratio is API 30+; older devices need crop-region zoom.
- Validate on at least one API 26-29 phone and one API 30+ phone, front/back cameras, denied permission, camera contention, rotation, background/foreground and thermal throttling.
- Measure 1-, 2-, 5- and 9-layer editor memory separately from camera preview memory.
- Export tests should verify actual pixel dimensions and decode the exported file; a UI label alone is not proof of 2K/3K/4K output.

## Release gate
Do not create a production release until Android CI builds, APK identity/ABI checks pass, APK installs and launches, camera capture works, editor regression tests pass, and real-device camera/memory/export tests are recorded. A GitHub Actions build does not prove physical-device behavior.
