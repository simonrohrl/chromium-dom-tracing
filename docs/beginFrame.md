## Complete chain from `OnBeginFrameDerivedImpl` to Blink

### 1. **Scheduler::OnBeginFrameDerivedImpl()** (Entry point from BeginFrameSource)
**File:** `chromium/src/cc/scheduler/scheduler.cc:388-460`
```cpp
LOG(INFO) << "[VSync->BeginFrameSource] OnBeginFrameDerivedImpl called";
```
- Receives BeginFrame from BeginFrameSource (VSync signal)
- **BLOCKING CONDITIONS:**
  - `if (!state_machine_.BeginFrameNeeded())` → drops frame, logs `[BeginFrame BLOCKED] BeginFrameNeeded() returned false`
  - `if (settings_.using_synchronous_renderer_compositor)` → takes synchronous path (Android WebView)
  - `if (inside_process_scheduled_actions_ || inside_previous_begin_frame || pending_begin_frame_args_.IsValid())` → defers frame
- If not blocked, calls `BeginImplFrameWithDeadline(args)` at line 458

### 2. **Scheduler::BeginImplFrame()**
**File:** `chromium/src/cc/scheduler/scheduler.cc:705-729`
```cpp
LOG(INFO) << "BeginImplFrame called";
```
- Starts a compositor frame that waits until deadline for BeginMainFrame+activation
- Calls `state_machine_.OnBeginImplFrame(args)` at line 718
- Calls `ProcessScheduledActions()` at line 728

### 3. **SchedulerStateMachine::OnBeginImplFrame()**
**File:** `chromium/src/cc/scheduler/scheduler_state_machine.cc:1378-1407`
```cpp
LOG(INFO) << "BeginFrame Impl";
```
- Sets `begin_impl_frame_state_ = BeginImplFrameState::INSIDE_BEGIN_FRAME` (line 1379)
- Resets `did_send_begin_main_frame_for_current_frame_ = false` (line 1400)
- Sets `needs_begin_main_frame_ = true` (line 1405)

### 4. **Scheduler::ProcessScheduledActions()**
**File:** `chromium/src/cc/scheduler/scheduler.cc:913-1020`
- **BLOCKING CONDITIONS:**
  - `if (stopped_)` → returns (scheduler shutdown)
  - `if (inside_process_scheduled_actions_ || inside_scheduled_action_)` → returns (recursion guard)
- Calls `state_machine_.NextAction()` in a loop (line 927)
- If action is `SEND_BEGIN_MAIN_FRAME`:
```cpp
LOG(INFO) << "Scheduler processing SEND_BEGIN_MAIN_FRAME action";
```
- Calls `client_->ScheduledActionSendBeginMainFrame(begin_main_frame_args_)` at line 946

### 4a. **SchedulerStateMachine::NextAction()**
**File:** `chromium/src/cc/scheduler/scheduler_state_machine.cc:815-848`
```cpp
if (ShouldSendBeginMainFrame()) {
  LOG(INFO) << "Impl Sends BeginMainFrame";
  return Action::SEND_BEGIN_MAIN_FRAME;
}
```
- `ShouldSendBeginMainFrame()` is checked FIRST

### 4b. **SchedulerStateMachine::ShouldSendBeginMainFrame()**
**File:** `chromium/src/cc/scheduler/scheduler_state_machine.cc:609-704`
- First calls `CouldSendBeginMainFrame()` - see conditions below
- **BLOCKING CONDITIONS:**
  - `if (did_send_begin_main_frame_for_current_frame_)` → already sent one this frame
  - `if (begin_main_frame_state_ == SENT)` → logs `[ShouldSendBeginMainFrame BLOCKED] begin_main_frame_state_=SENT`
  - `if (begin_main_frame_state_ == READY_TO_COMMIT)` → logs `[ShouldSendBeginMainFrame BLOCKED] begin_main_frame_state_=READY_TO_COMMIT`
  - `if (has_pending_tree_ && !can_send_main_frame_with_pending_tree)` → MFBA disabled
  - `if (settings_.commit_to_active_tree && waiting_for_draw)` → waiting for draw
  - `if (ImplLatencyTakesPriority() && ...)` → impl latency priority
  - `if (begin_impl_frame_state_ == IDLE)` → not inside begin frame
  - `if (!HasInitializedLayerTreeFrameSink())` → no frame sink
  - `if (IsDrawThrottled() && !just_submitted_in_deadline)` → draw throttled
  - `if (ShouldWaitForScrollEvent())` → waiting for scroll
  - `if (ShouldThrottleSendBeginMainFrame())` → throttled

### 4c. **SchedulerStateMachine::CouldSendBeginMainFrame()**
**File:** `chromium/src/cc/scheduler/scheduler_state_machine.cc:579-607`
- **BLOCKING CONDITIONS:**
  - `if (!needs_begin_main_frame_)` → not needed
  - `if (!visible_)` → logs `[CouldSendBeginMainFrame BLOCKED] visible_=false`
  - `if (begin_frame_source_paused_)` → logs `[CouldSendBeginMainFrame BLOCKED] begin_frame_source_paused_=true`
  - `if (defer_begin_main_frame_)` → logs `[CouldSendBeginMainFrame BLOCKED] defer_begin_main_frame_=true`
  - `if (pause_rendering_)` → logs `[CouldSendBeginMainFrame BLOCKED] pause_rendering_=true`

### 5. **ProxyImpl::ScheduledActionSendBeginMainFrame()** (Impl thread)
**File:** `chromium/src/cc/trees/proxy_impl.cc:742-786`
```cpp
LOG(INFO) << "ScheduledActionSendBeginMainFrame received in ProxyImpl";
```
- Prepares `BeginMainFrameAndCommitState` with compositor deltas
- Posts task to main thread at line 781-784:
```cpp
MainThreadTaskRunner()->PostTask(
    FROM_HERE,
    base::BindOnce(&ProxyMain::BeginMainFrame, proxy_main_weak_ptr_,
                   std::move(begin_main_frame_state)));
```

### 6. **ProxyMain::BeginMainFrame()** (Main thread)
**File:** `chromium/src/cc/trees/proxy_main.cc:140-336`
```cpp
LOG(INFO) << "BeginMainFrame received in ProxyMain";
```
- **BLOCKING CONDITIONS (early returns):**
  - `if (!layer_tree_host_->IsVisible())` (line 208) → aborts with `kAbortedNotVisible`
  - `if (defer_main_frame_update_ || pause_rendering_)` (line 243) → aborts with `kAbortedDeferredMainFrameUpdate`
- Calls `layer_tree_host_->WillBeginMainFrame()` at line 315
- Calls `layer_tree_host_->BeginMainFrame(frame_args)` at line 319

### 7. **LayerTreeHost::BeginMainFrame()**
**File:** `chromium/src/cc/trees/layer_tree_host.cc:392-396`
```cpp
LOG(INFO) << "BeginMainFrame received in LayerTreeHost";
client_->BeginMainFrame(args);
```
- Simple wrapper, forwards to client (LayerTreeView)

### 8. **LayerTreeView::BeginMainFrame()**
**File:** `chromium/src/third_party/blink/renderer/platform/widget/compositing/layer_tree_view.cc:272-278`
```cpp
LOG(INFO) << "BeginMainFrame received in LayerTreeView";
delegate_->BeginMainFrame(args);
```
- **BLOCKING CONDITION:**
  - `if (!delegate_)` → returns early (line 273-274)
- Forwards to delegate (WebFrameWidgetImpl)

### 9. **WebFrameWidgetImpl::BeginMainFrame()** (Blink)
**File:** `chromium/src/third_party/blink/renderer/core/frame/web_frame_widget_impl.cc:2635-2668`
```cpp
LOG(INFO) << "BeginMainFrame received in Blink";
```
- Final destination in Blink
- **BLOCKING CONDITION:**
  - `if (!LocalRootImpl())` (line 2664) → returns if frame detached during Animate
- Calls `GetPage()->Animate(last_frame_time)` at line 2662

---

## Complete flow diagram

```
[1] Scheduler::OnBeginFrameDerivedImpl()
    ↓ (if BeginFrameNeeded)
[2] Scheduler::BeginImplFrame()
    ↓
[3] SchedulerStateMachine::OnBeginImplFrame()
    - Sets begin_impl_frame_state_ = INSIDE_BEGIN_FRAME
    - Sets needs_begin_main_frame_ = true
    ↓
[4] Scheduler::ProcessScheduledActions()
    ↓
[4a] SchedulerStateMachine::NextAction()
    ↓ (if ShouldSendBeginMainFrame)
[4b] SchedulerStateMachine::ShouldSendBeginMainFrame()
    ↓ (checks CouldSendBeginMainFrame + many other conditions)
[4c] SchedulerStateMachine::CouldSendBeginMainFrame()
    ↓
[5] ProxyImpl::ScheduledActionSendBeginMainFrame() [impl thread]
    ↓ (posts to main thread)
[6] ProxyMain::BeginMainFrame() [main thread]
    ↓ (if visible && !deferred)
[7] LayerTreeHost::BeginMainFrame()
    ↓
[8] LayerTreeView::BeginMainFrame()
    ↓ (if delegate exists)
[9] WebFrameWidgetImpl::BeginMainFrame() [BLINK]
```

---

## Summary of all blocking conditions with logging

| Step | Condition | Log Message |
|------|-----------|-------------|
| 1 | `!BeginFrameNeeded()` | `[BeginFrame BLOCKED] BeginFrameNeeded() returned false` |
| 4c | `!visible_` | `[CouldSendBeginMainFrame BLOCKED] visible_=false` |
| 4c | `begin_frame_source_paused_` | `[CouldSendBeginMainFrame BLOCKED] begin_frame_source_paused_=true` |
| 4c | `defer_begin_main_frame_` | `[CouldSendBeginMainFrame BLOCKED] defer_begin_main_frame_=true` |
| 4c | `pause_rendering_` | `[CouldSendBeginMainFrame BLOCKED] pause_rendering_=true` |
| 4b | `begin_main_frame_state_ == SENT` | `[ShouldSendBeginMainFrame BLOCKED] begin_main_frame_state_=SENT` |
| 4b | `begin_main_frame_state_ == READY_TO_COMMIT` | `[ShouldSendBeginMainFrame BLOCKED] begin_main_frame_state_=READY_TO_COMMIT` |

---

## Key Finding: `needs_begin_main_frame_ = true` is NOT sufficient

Even with `needs_begin_main_frame_ = true` hardcoded in `OnBeginImplFrame()`, there are **many other conditions** that can block BeginMainFrame from being sent.

### Conditions that can cause "impl frame but no main frame"

These are the conditions that could block BeginMainFrame even when an impl frame runs:

| # | Condition | Logged? | Problem? | Notes |
|---|-----------|---------|----------|-------|
| 1 | `!needs_begin_main_frame_` | No | No | Hardcoded to true |
| 2 | `!visible_` | **Yes** | **Yes** | Tab not visible / minimized |
| 3 | `begin_frame_source_paused_` | **Yes** | **Yes** | BeginFrame source paused |
| 4 | `defer_begin_main_frame_` | **Yes** | **Yes** | Main frame deferred |
| 5 | `pause_rendering_` | **Yes** | **Yes** | Rendering paused |
| 6 | `did_send_begin_main_frame_for_current_frame_` | No | No | Reset each impl frame, only prevents 2nd BMF |
| 7 | `begin_main_frame_state_ == SENT` | **Yes** | **Yes** | Previous BMF not yet committed |
| 8 | `begin_main_frame_state_ == READY_TO_COMMIT` | **Yes** | **Yes** | Previous BMF ready but not committed |
| 9 | `has_pending_tree_ && !MFBA_enabled` | No | **Yes** | Waiting for activation |
| 10 | `commit_to_active_tree && waiting_for_draw` | No | **Yes** | Waiting for draw |
| 11 | `ImplLatencyTakesPriority() && ...` | No | **Yes** | Impl latency priority |
| 12 | `begin_impl_frame_state_ == IDLE` | No | No | Set to INSIDE_BEGIN_FRAME by OnBeginImplFrame |
| 13 | `!HasInitializedLayerTreeFrameSink()` | No | **Yes** | No frame sink |
| 14 | `IsDrawThrottled()` | No | **Yes** | Draw throttled |
| 15 | `ShouldWaitForScrollEvent()` | No | **Yes** | Waiting for scroll |
| 16 | `ShouldThrottleSendBeginMainFrame()` | No | **Yes** | Main frame throttled |

**Summary:** 12 conditions can actually block, 4 are not problems (1, 6, 12 won't block in normal flow)

### Most likely blockers:

1. **First frame not reaching Blink:**
   - `visible_ = false` (tab not visible)
   - `begin_frame_source_paused_ = true`
   - `!HasInitializedLayerTreeFrameSink()` (no frame sink yet)

2. **Subsequent frames blocked:**
   - `begin_main_frame_state_ = SENT` ← **Most common!**
   - This happens because `WillSendBeginMainFrame()` sets state to `SENT` and `needs_begin_main_frame_ = false`
   - State only returns to `IDLE` after main thread **commits**
   - If main thread never commits, all subsequent frames are blocked

---

## Important notes

1. **`needs_begin_main_frame_ = true` is set in OnBeginImplFrame** but many other conditions in `ShouldSendBeginMainFrame()` can still block the frame.

2. **`begin_main_frame_state_`** is the most common blocker after the first frame:
   - Set to `SENT` when `WillSendBeginMainFrame()` is called
   - Returns to `IDLE` only after the **main thread commits**
   - If main thread doesn't commit, subsequent frames will be blocked with `begin_main_frame_state_=SENT`

3. **Visibility** is checked at two levels:
   - `visible_` in `CouldSendBeginMainFrame()` (impl thread state)
   - `layer_tree_host_->IsVisible()` in `ProxyMain::BeginMainFrame()` (main thread check)

4. **The commit cycle must complete** for subsequent BeginMainFrames to be sent:
   ```
   BeginMainFrame sent → begin_main_frame_state_ = SENT
                       ↓
   Main thread processes → begin_main_frame_state_ = READY_TO_COMMIT
                       ↓
   Impl thread commits  → begin_main_frame_state_ = IDLE
                       ↓
   Next BeginMainFrame can now be sent
   ```
