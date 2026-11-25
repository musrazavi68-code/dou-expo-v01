# Dou Expo — Architecture and Refactoring Plan

## 1. Current implementation (verified against this branch)

The Flutter application lives in dou_expo_beta/.

- lib/main.dart: bootstrap, navigation shell, and complete Double Exposure editor state/UI. The editor owns camera, decoded images, blend controls, masks, stencil settings, render/export and share operations.
- lib/studio_modes.dart: Ordinary Camera and Darkroom presentation plus camera/image-processing behavior.
- lib/exposure_composer.dart: low-level image composition, preview painter, stencil paths and rendering primitives.
- lib/core/project_document.dart: JSON project/layer DTOs.
- lib/core/project_store.dart: app-private manifest and asset persistence.
- lib/core/history_stack.dart: bounded generic undo/redo snapshots.
- lib/core/project_session.dart: initial session façade; currently not injected into the three studio environments.
- test/: composer, color, project DTO, session and shell widget tests.

The three tabs are navigated by DouExpoShell, but each tab owns independent in-memory state. ProjectSession is not the source of truth for any of them. The editor's mask undo only removes the last stroke and does not cover other editor operations.

## 2. Target architecture

Use a feature-first structure with a small shared core. UI widgets must not write manifests, manage history directly, or call render internals.

```text
dou_expo_beta/
├── lib/
│   ├── app/
│   │   ├── dou_expo_app.dart              # MaterialApp, theme
│   │   └── studio_shell.dart              # tab navigation + shared session owner
│   ├── core/
│   │   ├── domain/
│   │   │   ├── project_document.dart      # immutable, versioned project/layer state
│   │   │   └── edit_command.dart          # semantic edit operation contracts
│   │   ├── application/
│   │   │   ├── project_session.dart       # single source of truth
│   │   │   ├── history_stack.dart         # bounded project-level history
│   │   │   └── autosave_coordinator.dart  # debounced + lifecycle save orchestration
│   │   └── data/
│   │       ├── project_store.dart         # atomic manifest persistence
│   │       └── project_asset_store.dart   # stable source/derived asset paths
│   ├── features/
│   │   ├── ordinary_camera/
│   │   │   ├── presentation/              # camera screen and controls
│   │   │   └── application/               # capture -> project layer use case
│   │   ├── double_exposure/
│   │   │   ├── presentation/              # editor widgets only
│   │   │   └── application/               # blend, mask, transform, recipe commands
│   │   └── darkroom/
│   │       ├── presentation/              # develop controls
│   │       └── application/               # non-destructive color adjustments
│   ├── rendering/
│   │   ├── exposure_renderer.dart         # deterministic final render entry point
│   │   └── preview_painter.dart           # preview-only painter
│   └── main.dart                          # bootstrap only
└── test/
    ├── core/
    ├── features/
    ├── rendering/
    └── integration/
```

## 3. Ownership and data flow

- StudioShell creates exactly one ProjectSession and injects it into Ordinary Camera, Double Exposure and Darkroom. Switching tabs must not recreate or discard the session.
- A project is the canonical state: canvas/export profile, ordered layers, stable asset references, visibility/opacity/blend/transform/exposure, masks, stencil configuration, film recipe, and Darkroom adjustments.
- Source image bytes are copied into app-private project assets before a manifest references them. Temporary picker/camera paths must never be persisted.
- Features submit immutable project changes through session commands. The session records one semantic history entry per completed user action, not per slider frame or pointer-move event.
- Preview and export use the same renderer/settings. Preview may be lower resolution; export must be deterministic at requested dimensions.
- UI owns transient state only (open sheet, active gesture, camera controller, countdown). Camera resources are disposed/recreated on lifecycle changes; project content is not.
- Autosave is debounced while editing, serialized/coalesced during writes, and flushed when the app becomes inactive/paused. A failed save leaves the session dirty and reports the error.
- Undo/redo restores the complete project snapshot, including all feature settings. It is not a separate mask-only history.

## 4. Current gaps and risks

1. No shared runtime session: the three tabs do not receive ProjectSession; the current project model is effectively unused by the UI.
2. Incomplete project schema: current layer DTOs can store common layer settings and masks, but do not formally model all editor and Darkroom settings, capture metadata, export profile, or schema migrations.
3. Mutable nested JSON: final references in ProjectDocument/LayerDocument do not make nested maps/lists immutable. A snapshot can therefore change after it has entered history.
4. Save coordination: ProjectSession currently rejects overlapping saves and an asynchronous open can replace state after the user has edited during the read.
5. Asset safety/atomicity: project IDs and asset names need strict allow-list validation; asset writes should be atomic; read/list/delete should not create empty project directories.
6. History semantics: editor controls mutate many independent fields directly. They need command boundaries and gesture coalescing before global undo can be correct.
7. Feature coupling: main.dart mixes shell, editor state, camera management, rendering orchestration, export and UI. studio_modes.dart mixes two separate feature domains.
8. Build validation: latest workflow execution has been pending/cancelled in the observed run history; there is no successful compile/test evidence or device verification.

## 5. Ordered implementation plan

### Phase A — Stabilize the core (no UI migration yet)
- Deep immutable project snapshots and strict model validation.
- Serialized/coalesced save, revision-safe open, safe atomic asset/manifest IO.
- Unit tests for immutability, interrupted writes, concurrent edits/saves and asset validation.

### Phase B — Define the complete project schema
- Add typed canvas/export/capture metadata and typed adjustment payloads.
- Add schema migration strategy; never silently discard unknown versions.
- Round-trip tests for every layer and feature setting.

### Phase C — Wire one shared session into the shell
- Shell owns one session and autosave coordinator.
- Ordinary Camera writes captured original assets and creates/replaces the base layer.
- Double Exposure reads/writes layer, mask, stencil, blend and transform state.
- Darkroom reads/writes non-destructive adjustment state and uses the common renderer.
- Integration tests verify state survives tab changes and app restart.

### Phase D — Global history and autosave
- Semantic commands for capture, add/remove/reorder layer, blend, transform, mask stroke, stencil, recipe, Darkroom adjustment and export profile.
- Coalesce continuous sliders/gestures into one history entry.
- Undo/redo tests across all three features.

### Phase E — Renderer and release validation
- One deterministic renderer for preview/export, bounded memory use and error handling.
- Flutter analyze, unit/widget/integration tests, Android release build and APK verification.
- Device smoke test remains a separate required sign-off.

## 6. Definition of done

A phase is complete only when code, tests and the matching CI job pass. A source commit is not evidence of a successful build. A CI APK is not evidence of a real-device camera/gallery test. No incomplete feature may be described as finished.