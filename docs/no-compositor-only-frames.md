# Ensuring Every Drawn Frame Goes Through Blink Main Frame

This patch modifies Chromium's compositor scheduler to guarantee that every frame drawn to screen has been processed by Blink's main thread.

## Changes

### 1. Force BeginMainFrame request every impl frame
**File:** `cc/scheduler/scheduler_state_machine.cc` (in `OnBeginImplFrame()`)
```cpp
needs_begin_main_frame_ = true;
```
Every compositor impl frame will request a BeginMainFrame from the main thread.

### 2. Wait for all pipeline stages before drawing
**File:** `third_party/blink/.../layer_tree_settings.cc`
```cpp
settings.wait_for_all_pipeline_stages_before_draw = true;
```
The compositor waits for the full pipeline (including main thread processing) before drawing.

### 3. Require commit before drawing
**File:** `cc/scheduler/scheduler_state_machine.cc` (in `ShouldDraw()`)
```cpp
if (!did_commit_during_frame_)
  return false;
```
Drawing is blocked unless the main thread committed during this frame.

## Why This Works

In normal operation, the compositor can draw "compositor-only" frames without main thread involvement (e.g., during scrolling or CSS animations). These three changes together prevent that:

1. **Request guarantee:** Every impl frame requests main thread work
2. **Pipeline sync:** Compositor waits for main thread to complete
3. **Commit requirement:** No drawing without a commit from main thread

The `did_commit_during_frame_` variable is:
- Reset to `false` at the start of each impl frame
- Set to `true` when the main thread commits

This ensures a 1:1 correspondence between drawn frames and Blink main frame processing.
