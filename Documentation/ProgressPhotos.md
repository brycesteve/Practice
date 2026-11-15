# Progress photography

Open Dashboard → Progress, then unlock using Face ID, Touch ID or your device passcode. The entire photo area relocks when the app backgrounds or you close it. App-switcher previews are covered while inactive. Authentication cancellation leaves photos locked.

Open Dashboard → Progress. Take any combination of front, side and back views, review each photograph, then save the session. Originals stay within Practice; the camera does not access or write to Apple Photos. Tap a photograph in a session to inspect and zoom. Select two sessions to compare matching views. Guide and timer settings are local capture preferences.

Settings contains opt-in weekly waist and monthly photo reminders. Their day/time settings are local to each device, like the existing weigh-in reminder. Monthly reminders use days 1–28 and calendar-based local times. They respect Enable Reminders and system notification permission. Disabling reminders does not affect saved photographs or measurements.

## Storage and migration

V4 adds `ProgressPhotoSession` and `ProgressPhotoRecord` to the existing V3 schema using a lightweight migration. No existing model identity, schema definition, store URL, CloudKit container configuration or workout record changes. Photo files are iOS-only; they do not enter WatchConnectivity payloads or widgets. Existing phone-folder membership includes the new files automatically. Shared notification additions compile for phone, Watch and both widgets.

Each photograph has an immutable capture UUID, session UUID, view, capture date, orientation-aware dimensions, SHA-256 digest and original encoded bytes. The optional `@Attribute(.externalStorage)` image data lets SwiftData manage adjacent binary storage. Thumbnails are separate bounded previews. Original EXIF orientation and aspect ratio are preserved; downsampled display images apply orientation without rewriting originals. Future alignment/cropping can use derived display transforms while retaining these originals.

Replaying a saved draft is idempotent. Replacing a view creates a new capture and soft-deletes the previous one in the same save. Concurrent captures from different devices are retained, with a deterministic current view; additional captures remain selectable in session details. Recoverable deletion has no automatic expiry. Permanent deletion requires confirmation and propagates through the existing sync stack. A photo imported before its session metadata remains accessible through a reconstructed timeline entry.

## CloudKit release preparation — required before distribution

The existing private container is `iCloud.net.stevebryce.practice`. Automatic SwiftData mirroring remains the sole writer. Read-only verification uses Apple's documented Core Data → CloudKit field mapping and the existing custom zones. It does not create a separate zone, write CloudKit records, or replace the persistence stack.

1. Using an isolated development store and development iCloud account, allow SwiftData to create the additive `CD_ProgressPhotoSession` and `CD_ProgressPhotoRecord` types. Use actual camera photographs only in that development store. Do not seed, reset or delete the user's store, and do not invoke the disabled live-store schema promotion engine.
2. Inspect the generated schema in CloudKit Console. Confirm the new record fields, including `CD_id`, `CD_sessionID`, `CD_contentHash`, `CD_imageData` and `CD_imageData_ckAsset`. Binary values can be inline or CKAsset-backed; verification supports both.
3. Deploy the additive schema to production without removing existing types/fields. Verification no longer needs a QUERYABLE index: it enumerates private custom zones and paginates their metadata using CloudKit zone changes, then fetches only matching photo originals by record ID. It never writes records, zones or change tokens into the mirroring store.
4. Validate a production/TestFlight build against the production environment after deployment. This repository change does not deploy the server schema or claim that deployment has occurred.

A local SwiftData save is not proof of cloud backup. The timeline distinguishes local saves from iCloud availability. Session details only show per-photo confirmation after fetching the matching UUID/session/digest and checking the actual server image bytes against the local digest. General Core Data export success is never used to mark individual photographs verified. Uploads can lag a local save; absence or failure remains unverified. Confirmation is timestamped, kept only in memory and invalidated on app reactivation/account changes. CloudKit scheduling remains controlled by the system.

## Independent export

Export creates a ZIP containing original encoded photographs and `manifest.json`, including capture/session UUIDs, session and capture dates, views, deletion dates and SHA-256 checksums. It includes Recently Deleted and concurrent captures. The archive creation fails explicitly if a requested original is missing or corrupted; it never reports a partial archive as a complete backup. Exported copies are independently readable without Practice. Archive and staging files use complete file protection and are removed after sharing/dismissal. Save the ZIP to Files or another user-chosen destination. No automatic Photos export is performed.

## Validation

Hosted tests require `PracticeIsolatedTests=1`; the shared schemes already provide it. Tests use memory containers and disposable temporary disk stores with CloudKit disabled. Migration coverage preserves existing workout IDs, loaded sets and heart-rate fields, settings and waist data while adding photos. Disk reopening covers a JPEG larger than 1 MB to exercise external storage. Further tests cover retries, replacement, recovery, permanent-delete guards, malformed image batches, orientation, concurrent capture selection, inline/asset server-byte verification, export failure and calendar reminders. SwiftUI previews use a separate memory container and synthetic silhouettes; they never populate the user's store.

Before release, validate on physical devices: both cameras, permission denial/recovery, 5/10-second timers and interruption cancellation, retakes and matching preview orientation; offline save/relaunch followed by reconnection; cross-device import including large assets; unavailable iCloud and full quota; verification after sync; Recently Deleted and replacement on another device; independent ZIP extraction; notification delivery across a week/month and permission/master-switch changes. Device replacement restoration must be checked against a separate signed-in device, without deleting the user's only copy.

## Privacy and presentation regression checks

The timeline is created only after device-owner authentication. Its navigation stack is recreated on lock so pushed details and presented sheets cannot survive a background lock. Individual photos and exports use item-driven presentation: the bytes or archive URL exist before presentation starts. The inspector keeps a visible Done action even while decoding or when bytes are unavailable; its zoom canvas only refits when the viewport size changes.

Tests exercise authentication success/cancellation and an in-flight authentication invalidated by background lock, photo canvas sizing/rotation/zoom, immediate dashboard scrolling in an isolated hosted window, metadata candidate matching in a custom CloudKit zone, partial-error explanations, and export-file cleanup. The inspector preview uses a synthetic silhouette. Physical-device Face ID, existing-data cold launch, the system share extensions and production iCloud reads still need validation on a signed-in device; hosted tests never access the user's photo store or iCloud account.
