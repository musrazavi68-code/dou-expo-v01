# Dou Expo — Current Architecture, Risks and Delivery Plan

## 1. Current implementation

The Flutter app is in `dou_expo_beta/`; the legacy React Native app in `beta-app/` is preserved.

- `lib/main.dart`: app bootstrap, three-tab shell, editor UI/state, camera lifecycle, rendering/export and settings.
- `lib/studio_modes.dart`: Ordinary Camera and Darkroom screens.
- `lib/exposure_composer.dart`: composition painter, blend/render primitives and stencil geometry.
- `lib/core/project_document.dart`: version-1 JSON project/layer model with recursive freezing of nested JSON maps/lists and validation.
- `lib/core/project_session.dart`: shared project state, snapshot history, undo/redo, guarded restore/open and serialized save loop.
- `lib/core/project_store.dart`: app-private project manifests and source assets, identifier/path validation, temporary-file writes and backup-manifest recovery.
- `lib/core/autosave_coordinator.dart`: revision-observed debounced autosave and explicit lifecycle flush.
- `test/`: project model/store/session, autosave, color pipeline, composer, pattern bank and shell navigation coverage.

`DouExpoShell` creates one `ProjectSession` and one `AutosaveCoordinator`, then injects the session into Ordinary Camera, Double Exposure and Darkroom. The session survives tab changes. Captured/imported source bytes are copied into project-private assets before the project manifest refers to them.

## 2. Verified CI state

Latest successful run: https://github.com/musrazavi68-code/dou-expo-v01/actions/runs/45890652374

- Flutter analyze: passed.
- Automated tests: passed (31 total, including the shell navigation widget test).
- Android release APK build, alignment, signature and metadata checks: passed.
- Android API 35 emulator install and process launch: passed in this run.
- iOS release compilation without code signing: passed.
- APK artifact uploaded.

The APK used a one-run ephemeral test signing key because the four persistent signing secrets were absent. This is not a durable release identity and cannot update an installation signed by another key. A real-device camera/gallery test has not been performed by CI.

## 3. Ownership and data flow

- The shell owns the single project session; all studio screens receive the same session.
- Project documents store canvas settings, ordered layers, stable relative asset paths, layer visibility/opacity/blend/transform/exposure, masks and feature settings.
- Source image bytes are copied to app-private storage; temporary picker/camera paths are not persisted as source references.
- Features publish project snapshots through the session. The session owns history and persistence; autosave observes revision changes.
- Autosave is debounced, save requests join a shared writer, and writes repeat if the project revision changes while persistence is in progress.
- The shell flushes pending changes when the app becomes inactive/paused and exposes an explicit save action.
- Project history is in-memory and scoped to the open app session; project documents/assets persist separately.

## 4. Remaining risks and product gaps

1. **Persistent release signing is blocked on owner-provided secrets.** The original private keystore and credentials are not present in the repository/CI environment. A public certificate fingerprint cannot recreate the private key. Until configured, CI artifacts remain test-only.
2. **Physical-device validation remains outstanding.** Emulator success does not validate a particular phone's camera stack, gallery provider, permission behavior, storage behavior, or OEM-specific installation constraints.
3. **Project schema is still version 1.** Canvas and feature settings are represented partly as JSON maps rather than fully typed feature-specific models; migration policy is not implemented beyond rejecting unsupported versions.
4. **Editor state migration is incomplete.** Shared project/session and autosave are wired, but transient camera/editor UI state and every possible editing control should be audited for complete round-trip persistence and semantic undo behavior.
5. **Renderer/export parity needs dedicated golden/integration tests.** The exported image is a canvas render, not a sensor-resolution, full-original-pixel compositor.
6. **Camera controls are limited by the current plugin abstraction.** ISO and shutter speed are not exposed.
7. **Launcher icon asset is missing.** `assets/icon/app_icon.png` must be supplied before generating final launcher icons.

## 5. Next delivery plan

### P0 — Release identity and install path
- Owner configures the original persistent keystore secrets.
- Verify the resulting APK certificate fingerprint against the known release certificate.
- Confirm update installation over the existing app without uninstalling or losing local data.

### P1 — Physical-device QA
- Test install/update on the target Android device and capture the exact Package Installer/ADB error if installation fails.
- Test camera permission grant/deny, front/rear switching, gallery import, export, share, background/foreground and low-storage behavior.
- Test iOS camera/gallery permissions and export on a physical iPhone.

### P2 — Project integrity
- Add typed canvas/export/capture/adjustment models and schema migrations.
- Add integration tests for project round-trip across all tabs and app restart.
- Audit each edit operation for one meaningful history entry and verify undo/redo restores all related settings.
- Add interrupted-write, asset corruption and restore-recovery tests.

### P3 — Rendering and product finish
- Add deterministic renderer golden tests and large-image memory/performance tests.
- Decide whether full-original-resolution compositing is a product requirement.
- Supply launcher icon artwork and verify generated Android/iOS icons.

## 6. Definition of done

A phase is complete only when its code, automated tests and corresponding CI checks pass. A successful CI APK proves the tested build and emulator path, not physical-device compatibility or persistent update signing. No incomplete feature should be described as finished.
