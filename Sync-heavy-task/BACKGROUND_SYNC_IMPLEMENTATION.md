# Background Sync Implementation Guide

## Overview
This guide explains how to make sync operations run in the background instead of blocking the splash screen on app startup.

## Changes Made

### 1. App Wrapper Changes (`app_wrapper.dart`)

#### Removed Blocking Splash Screen Logic
- **Before**: `shouldShowSyncSplash = syncState.isSyncing && syncState.isFirstSync` blocked navigation
- **After**: Removed this check, allowing immediate navigation while sync runs in background

#### Updated Sync Trigger
- Added `runInBackground: true` parameter to `syncStarted` event
- Sync now starts asynchronously without waiting for completion
- Users can navigate the app while sync happens in the background

### 2. Event Definition Update Required

**Note**: The `SyncEvent` class uses Freezed code generation. You need to update the event definition:

**File**: `sync_event.dart` (part file referenced in `sync_bloc.dart`)

Add a new parameter to the `_SyncStarted` event:

```dart
@freezed
class SyncEvent with _$SyncEvent {
  const factory SyncEvent.syncStarted({
    @Default(false) bool isAppStart,
    @Default(false) bool runInBackground,  // NEW PARAMETER
    String? projectId,
    String? workspaceId,
    String? selectedPeriod,
    String? selectedStatus,
    bool? showModal,
    VoidCallback? onCompleted,
  }) = _SyncStarted;
  
  // ... other events
}
```

After updating, run:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. Bloc Logic Update (Optional Enhancement)

In `sync_bloc.dart`, you can optionally use the `runInBackground` parameter to adjust behavior:

```dart
Future<void> _onSyncStarted(
  _SyncStarted event,
  Emitter<SyncState> emit,
) async {
  if (state.isSyncing) {
    return;
  }

  emit(state.copyWith(
    isSyncing: true,
    isCancelled: false,
    progress: 0.0,
    showModal: event.showModal,
    isFirstSync: !event.runInBackground, // Don't block if background sync
  ));
  
  // ... rest of implementation
}
```

## Benefits

### ✅ Improved User Experience
- No more waiting on splash screen for sync to complete
- Users can start using the app immediately
- Sync continues seamlessly in the background

### ✅ Better Performance Perception
- App feels faster and more responsive
- First-time users aren't blocked by long sync operations
- Heavy data sync doesn't impact initial load time

### ✅ Flexible Sync Strategy
- First sync on app start runs in background
- Manual syncs can still show modal/progress if needed
- Different sync behaviors for different scenarios

## UI Recommendations

Consider adding a subtle background sync indicator in your app's UI:

1. **Status Bar Indicator**: Small icon showing sync progress
2. **Toast Notification**: When sync completes successfully
3. **Pull-to-Refresh**: Allow manual sync with visual feedback
4. **Settings Toggle**: Let users control sync behavior

Example implementation:

```dart
// In your home screen or top bar
BlocBuilder<SyncBloc, SyncState>(
  builder: (context, state) {
    if (state.isSyncing && !state.showModal) {
      return Container(
        padding: EdgeInsets.all(8),
        color: Colors.blue.shade100,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('Syncing... ${(state.progress * 100).toInt()}%'),
          ],
        ),
      );
    }
    return SizedBox.shrink();
  },
)
```

## Testing Checklist

- [ ] App starts and navigates to home without waiting for sync
- [ ] Sync runs in background after authentication
- [ ] No internet: App skips sync and allows navigation
- [ ] Manual sync (if implemented) still shows progress
- [ ] Sync state is properly tracked across app lifecycle
- [ ] No race conditions between navigation and sync
- [ ] Data is available after background sync completes

## Implementation Strategy: Use Isolates

### Why Isolates (NOT WorkManager)?

**Use Isolates** for your case because:
- ✅ Sync runs when app is **open** and authenticated
- ✅ Need real-time progress updates to UI
- ✅ Must access existing repositories and DI container
- ✅ Can be cancelled by user
- ✅ Simpler implementation

**WorkManager is for**:
- ❌ Background tasks when app is **closed/killed**
- ❌ Periodic tasks (e.g., every 15 minutes)
- ❌ Doesn't need real-time UI updates
- ❌ Runs in separate process

### Isolate Implementation

Add this to your `sync_bloc.dart`:

```dart
import 'dart:isolate';

Future<void> _onSyncStarted(
  _SyncStarted event,
  Emitter<SyncState> emit,
) async {
  if (state.isSyncing) {
    return;
  }

  emit(state.copyWith(
    isSyncing: true,
    isCancelled: false,
    progress: 0.0,
    showModal: event.showModal,
  ));

  if (event.runInBackground) {
    // Run heavy sync in isolate to prevent UI blocking
    await _runSyncInIsolate(event, emit);
  } else {
    // Run in main isolate for immediate modal sync
    await _performSync(event, emit);
  }
}

Future<void> _runSyncInIsolate(
  _SyncStarted event,
  Emitter<SyncState> emit,
) async {
  final receivePort = ReceivePort();
  
  // Progress listener
  receivePort.listen((message) {
    if (message is double) {
      emit(state.copyWith(progress: message));
    } else if (message is bool && message == true) {
      emit(state.copyWith(
        isSyncing: false,
        isFirstSync: false,
        progress: 1.0,
      ));
      event.onCompleted?.call();
    }
  });

  // Start sync in background isolate
  await Isolate.spawn(
    _syncIsolateEntry,
    _SyncIsolateMessage(
      sendPort: receivePort.sendPort,
      projectId: event.projectId,
      workspaceId: event.workspaceId,
      selectedPeriod: event.selectedPeriod,
      selectedStatus: event.selectedStatus,
    ),
  );
}

// Isolate entry point
static void _syncIsolateEntry(_SyncIsolateMessage message) async {
  // Perform sync operations here
  // Send progress updates: message.sendPort.send(0.5);
  // Send completion: message.sendPort.send(true);
}

class _SyncIsolateMessage {
  final SendPort sendPort;
  final String? projectId;
  final String? workspaceId;
  final String? selectedPeriod;
  final String? selectedStatus;

  _SyncIsolateMessage({
    required this.sendPort,
    this.projectId,
    this.workspaceId,
    this.selectedPeriod,
    this.selectedStatus,
  });
}
```

### Simpler Alternative: Async Without Blocking

Actually, since your sync already uses `async/await` and doesn't do CPU-intensive work (it's mostly network I/O), you might **not even need isolates**. Dart's async operations already don't block the UI!

**Current implementation is already non-blocking** because:
- Network calls are async
- Database operations are async  
- `Future.wait()` for parallel tasks is non-blocking

Just ensure you're not doing:
- Heavy JSON parsing of large files (>1MB)
- Complex data transformations in loops
- Image processing
- Cryptographic operations

If your sync feels smooth, **keep it as-is**. Only add isolates if you notice UI jank.

## Next Steps

1. **Test current implementation first** - It's likely already non-blocking
2. If UI freezes during sync, add isolates for heavy operations only
3. Update the `SyncEvent` definition with `runInBackground` parameter
4. Run code generation to update freezed files
5. Consider adding background sync UI indicator
6. Monitor sync completion and handle errors gracefully

## Rollback Plan

If issues occur, simply revert the changes in `app_wrapper.dart`:

```dart
// Restore blocking behavior
final bool shouldShowSyncSplash = 
    syncState.isSyncing && syncState.isFirstSync;

if (isAuthLoading || shouldShowSyncSplash || shouldShowSpinner) {
  routes = [const SplashRoute()];
}
```
