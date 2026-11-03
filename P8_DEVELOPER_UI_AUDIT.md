# P8 — Developer UI Audit and Stability Handoff

## Scope and baseline

- Stable pre-P8 developer baseline: `769cade5ddd05db8d562733ed035acaddeb08d3c`.
- Branch: `ZonoePatch-V3`; never rewrite the P7/P6 history.
- **Developer only**: no edits to `Tweak.mm` (shared with customer), `V3Customer*.mm/h`, `V3StaticBinaryBuilder.mm`, `V3StaticBinaryExport.mm`, `V3StaticDispatchRuntime.mm`, patch execution core or file serialization schema.
- User reported that P7 customer app starts, static Patch ON works and OFF restores Original. P8 does not supersede that observed baseline. Independent logs/device captures are unavailable.

## Confirmed source risks fixed

1. **Horizontal row compression on narrow screens** — `V3HookPage.mm` had fixed-width controls competing for a narrow content width (104-point sidebar plus scroll margins). Now feature rows use an adaptive compact two-line layout on menus narrower than 430 points; elsewhere they remain single-line. Feature names truncate safely rather than overlap controls. Layout mode follows view-width changes.
2. **Invalid editor scrolling coordinate** — `V3FeatureEditor.mm` passed `self.editor.frame` (in body-stack coordinates) directly to `scrollRectToVisible:` (scroll coordinates); now converts `nameField.bounds` to the scroll view and scrolls to it.
3. **Scene lifetime** — `V3MenuHost.mm` only hid its overlay on app background or full Scene disconnect. It now hides on `UISceneWillDeactivateNotification` and sizes overlay to the Scene coordinate space; destroys the retained overlay only on Scene disconnect.
4. **Async build/edit race** — `generateStaticBinary` exports an immutable plan on a background queue, but the developer UI previously allowed concurrent Runtime Patch mutations, deletion and save. During an export the editor/list disables changes and rejects concurrent state writes; build completion restores controls. The build result names the immutable selected feature.
5. **P7 selection / save / delete consistency** — stable feature UUID selection remains distinct from row indices, editor changes gate generation, and deleting the actively edited feature closes its draft.

## Verification standards

- GitHub CI macOS host tests: codec, address/config, runtime-executor fault injection, static plan, synthetic ARM64 full Mach-O generation and signing, static Slot fault injection.
- Theos iOS arm64 build and ad-hoc signing of both existing targets.
- Compare Git delta since pre-P8 and assert **no `V3Customer*` or shared `Tweak.mm` changes**.
- No screenshot-based UI layout simulation or real-device rotation can be claimed from these tests.
- P8 **device acceptance remains open** until the developer version is launched on a real target: test 320/375/430+ widths, keyboard appearance, orientation, app background/foreground, Scene transitions, row selection, save/cancel, Runtime ON/OFF, rejected concurrent build, and exported file compatibility with existing P7 customer runtime.

## P8 follow-up audit — feature index shift regression

- Found: deleting a feature preceding an open draft left `editingIndex` stale. A later save could replace the wrong feature or append a duplicate.
- Fixed in `V3FeatureModels.mm`: decrement the edit index only after successful deletion persistence; rollback leaves it unchanged.
- Added a regression to `tests/v3_config_and_address_test.mm` that edits feature B, deletes A, then saves and asserts B identity and name.
- CI and device validation are required before marking the fix verified.

## Deferred technical debt (not silently addressed)

- `Tweak.mm` is shared by Developer and Customer. It installs a 0.5-second polling `NSTimer` for floating-icon reattachment; the icon callback strongly captures the singleton host. Changing it risks the known-good customer path, so it is deferred to an independently verified shared-runtime change.
- `V3Menu.mm` exposes sidebar sections other than Hook as UI placeholders. Converting them to real navigation is a separate feature, not a P8 stability fix.
- The developer editor still offers the historical `应用 Patch` button as well as list-row `启用/恢复`. They call the same `ZNV3PatchSession`, but one canonical interaction could be chosen in a later UX iteration.
- No direct iPhone UIKit screenshot testing or programmatic actual game load/run tests exist in CI.
