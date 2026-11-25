# Dou Expo — Figma UI Blueprint

Figma workspace: https://www.figma.com/design/yEmDPPzkN6hZCxNWaV5BgF

This specification is the implementation-aligned brief for the editable Figma screens. The Figma document has been created; its screen construction is pending the Figma Starter tool-call quota reset.

## Product direction
- Dark, minimal photographic workspace; graphite/navy surfaces, warm gold actions, restrained cyan status accents.
- Product identity: DOU EXPO / MULTI EXPOSURE STUDIO.
- Avoid decorative clutter. Prioritize the live composite preview and direct access to blend controls.
- Keep all controls thumb-friendly (minimum 40–44 dp touch targets).

## Screens to build
1. **Capture** — live camera preview, exposure 1/2 indicator, first exposure ghost overlay, shutter, gallery, front/back camera, torch, mask selector.
2. **Blend Studio** — large canvas preview, exposure count, blend mode selector, opacity, eight gradient directions, brightness transparency (off/bright-transparent/dark-transparent), mask selection and mask treatment.
3. **Color & Light** — one-tap looks (original/warm/mono/cinema), exposure, contrast, highlights, shadows, temperature, tint, saturation, vibrance; visible reset affordance.
4. **Layers** — image thumbnail, layer name/dimensions, reorder, remove, add images; design for many layers with a scrollable list.
5. **Export** — save/share feedback, output resolution/quality choice when implemented, and clear progress/error states.

## Responsive layouts
- **Phone portrait (390 × 844 reference):** stacked preview and compact bottom control panel; tabbed Blend / Color / Layers controls.
- **Phone landscape:** preview and controls side-by-side when width allows; preserve camera aspect ratio and avoid cramped sliders.
- **Tablet (800+ dp):** two-column studio with preview on the left and scrollable controls on the right.
- **Foldable:** reflow at live window-size changes; support narrow cover display and expanded inner display without resetting the active composition.

## Design tokens
- Background: #080B12
- Surface: #111723
- Elevated surface: #182232
- Border: #263448
- Primary text: #F4F7FB
- Secondary text: #91A0B5
- Gold action: #D9B56D
- Cyan accent: #6ED9D0
- Error: #F28B82
- Radius: 12 dp controls, 18–20 dp panels
- Spacing rhythm: 4 / 8 / 12 / 16 / 24 dp

## Reusable components
- Primary / secondary / icon buttons
- Selected / unselected pills and segmented tabs
- Slider row with numeric value and step controls
- Exposure layer row
- Mask thumbnail tile
- Camera shutter and preview status badge
- Empty, loading, permission-denied, export-success and export-failure states

## Interaction requirements
- Selected controls animate subtly; avoid large motion or layout jumps.
- Reorder and remove layer actions provide immediate visual feedback.
- Switching tabs preserves all current adjustment values.
- Every preview-affecting control updates the composite without requiring an extra apply action.
- Persian RTL and English LTR layouts must both be represented and checked.

## Engineering truth / scope guard
The current app source has multi-image layer storage, blend modes, opacity, gradient and brightness-based transparency, color adjustments, vector masks, camera capture, gallery import, and export/share flows. Independent per-layer transform handles (move/scale/rotate), segmentation-based smart masks, and signed production release are not yet verified. Do not depict these as shipped controls until implemented and tested.
