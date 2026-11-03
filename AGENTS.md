# Practice

Personal SwiftUI iPhone/Apple Watch training app. Keep the programme simple and preserve recorded training data.

## Architecture

- `Shared/Data/Exercises.swift` and `WorkoutData.swift` define exercises, templates and the weekly schedule. Keep prescriptions here rather than duplicating them in views.
- `Shared/Data/SharedModels.swift` contains Codable value types shared by the apps and widgets.
- The Watch `SessionPickerView` selects plans; `WorkoutGuideView` executes and logs them. `HealthKitManager` owns the HealthKit workout lifecycle and live metrics.
- `WatchConnectivityManager` transfers completed workouts and settings. `AppGroupDefaults` caches sync state; the phone's SwiftData store is the durable workout authority.
- `Practice/Data/Schema.swift` registers versioned SwiftData schemas and CloudKit storage. Preserve historical model identities, session raw values, exercise names and IDs.
- Evening skills use completion-driven rotation and the separate skill progression engine. Do not apply that engine to ordinary strength work.

## Change discipline

- Inspect the actual implementation before proposing architectural changes. Present a plan and obtain approval before changing training behaviour, unless the current request already authorizes the change.
- Reuse the existing guide, records and screens. Avoid unrelated rewrites, extra dashboards and elaborate progression systems.
- S&S loading remains manually configured. Preserve recovery-based rest with an unrestricted Ready button; heart rate is advisory, never a mandatory threshold or deadline.
- Strength work leaves approximately 2–3 reps in reserve. Do not automatically add volume or infer pressing loads from swing/get-up loads.
- Preserve morning mobility, evening stretching and skill practice unless an approved change says otherwise.
- Keep Codable additions backward compatible. Use versioned migrations for persistent schema changes; never delete or reseed a user's store to make a migration work.
- Never insert diagnostic/sample records into live SwiftData or CloudKit stores. Use memory stores and `PracticeIsolatedTests=1` for hosted tests.
- Respect existing user changes. This project uses `Practice.xcodeproj/project.xcproj`; do not convert it back to `project.pbxproj`. Shared scheme changes are intentional.
- New shared files require checking membership in the phone, Watch and widget targets; prefer extending existing shared files for small changes.

## Verification

- Build the iOS and Watch targets and run the relevant `PracticeTests` and `PracticeWatchTests` suites using Xcode's available simulator destinations.
- For programme changes, test weekday selection, exact prescriptions, circuits/sides, independent strength loading, legacy decoding, and completed-workout persistence including weights and HR/timing fields.
- Verify rest/mobility days, workout resume, and unchanged evening rotation. Report any build, simulator or device-only validation limitations honestly.
