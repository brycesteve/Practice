# Bluetooth body measurements

## Architecture and entry points

- Watch: **Body measurement** on the existing session picker. CoreBluetooth runs only in the Watch controller. Discovery accepts the advertised name AAA002 plus a valid decoded packet; an explicitly selected scale is matched by manufacturer company ID and MAC.
- iOS: **Dashboard → Body Stats → metric history → measurement detail**. Body Stats also opens the full measurement history. **Settings → Body profile & scale** contains configuration; the overlapping statistics destination has been removed from Settings. Profile fallbacks and the phone's default scale live in the existing SwiftData store.
- Shared Foundation code contains the manufacturer decoder, clock-driven session state, raw transfer types, profile snapshot, versioned calculation interface and reference tables. It has no UIKit dependency.
- The reference files in `CodexReference/ScaleExperiment` were read only. They were not modified or added to targets.

## Measurements and persistence

SwiftData V3 adds `BodyMeasurementRecord`, `WaistMeasurementRecord` and `BodyProfileSettings`. V1 and V2 model definitions remain unchanged. V3 reuses all V2 models and adds a lightweight V2→V3 migration, tested against an on-disk V2 store.

Canonical body records contain UUID, final-weight timestamp, fresh weight in kg, optional impedance in inferred whole ohms, the uninterpreted 16-bit impedance metadata, scale identity, and a snapshot of calculation inputs and their sources. Calculated body-fat percentage is not persisted as source data. UI calculations are reproduced from raw observations and the snapshot, with method/version carried in each result.

The Watch app did not have an active SwiftData container before this change. It keeps that architecture: completed body readings enter a small atomic-file outbox before they are sent through the existing WatchConnectivity manager. The phone deduplicates by UUID and acknowledges only after a successful SwiftData save. The Watch removes its outbox entry only upon that acknowledgement. Activation, reachability changes, incoming full sync, and the measurement screen retry outstanding transfers. HealthKit failures never prevent acknowledgement of a successfully saved Practice record.

iOS continues using the existing CloudKit-backed container. Deploy the additive CloudKit schema through the project's existing development-to-production process before shipping. Production CloudKit propagation is not covered by simulator tests.

## Watch session policy

1. Load authorised HealthKit profile inputs, using explicitly entered phone fallbacks when necessary.
2. Scan in the foreground, with duplicate advertisements enabled and no service filter; this is broadcast reception, not pairing or a GATT connection.
3. Display live weight. Freeze the first final weight and its timestamp.
4. Complete once final weight and impedance are both present, including impedance received earlier in the same attempt.
5. After 12 seconds from the first final frame, save weight-only if impedance is absent. Repeated final advertisements do not extend this deadline. If no final weight arrives within 60 seconds, fail without recording a live value.
6. Freeze the completed session and stop scanning. Repeated advertisements cannot create another measurement.

Leaving the screen or making the app inactive cancels unfinished scanning. Start a new attempt after stepping off the scale. The protocol has no verified measurement sequence identifier, so a deliberately restarted attempt cannot prove that a continuing final advertisement belongs to a new physical weighing.

An explicit on-Watch selection persists and takes precedence over the phone default. Use **Choose another scale** on Watch to discover/select a replacement. The test MAC is only populated through the explicit **Use development scale** settings action.

## Profile and waist

HealthKit height, date of birth and biological sex take precedence where available. Age is calculated at the measurement date, including whether the birthday has occurred. Other/not-set/unknown biological sex does not select coefficients: the user can explicitly choose a male or female calculation model. Nothing substitutes a latest HealthKit body mass for the fresh scale weight.

Missing profile inputs can be supplemented after sync or explicitly from a measurement's detail screen; existing inputs are retained. Input snapshots keep subsequent calculations reproducible. Waist is optional and separately timestamped. Manual waist entries are stored independently; the latest eligible manual or HealthKit waist can supply waist-to-height ratio. Previously read HealthKit waist values are not copied back as newly measured samples.

## Algorithms, units and source verification

Independent implementation; no StandardImpedanceLib or openScale/GPL source was used.

- **Kushner–Schoeller, version 1:** male TBW = 0.396 × heightCm² / resistanceOhms + 0.143 × weightKg + 8.399; female TBW = 0.382 × heightCm² / resistanceOhms + 0.105 × weightKg + 8.315. Outputs litres. [Original paper, AJCN 1986;44:417–424](https://doi.org/10.1093/ajcn/44.3.417).
- **Hydration conversion:** FFMkg = TBWlitres / 0.732; fat mass = fresh weight − FFM; fat percentage = 100 × fat mass / fresh weight. Version 1 uses the published D2O-TBW predictions directly, with no separate isotope-space correction and water approximated as 1 kg/L. Those assumptions are part of the version.
- **Janssen, version 1:** estimated skeletal muscle kg = 0.401 × heightCm² / resistanceOhms + 3.825 × maleIndicator − 0.071 × ageYears + 5.102. [Original study, J Appl Physiol 2000;89:465–471](https://pubmed.ncbi.nlm.nih.gov/10926627/).
- **Katch–McArdle:** BMR kcal/day = 370 + 21.6 × FFMkg, the relationship specified for this feature and documented in McArdle, Katch and Katch's *Exercise Physiology*. BMI = weightKg / heightMetres². Waist/height uses matching units.
- **References:** general adult [NICE NG246](https://www.nice.org.uk/guidance/ng246/chapter/Identifying-and-assessing-overweight-obesity-and-central-adiposity) BMI and waist/height thresholds; [Gallagher 2000, original Table 4](https://zakboekdietetiek.nl/wp-content/uploads/2015/11/Am-J-Clin-Nutr-2000-Gallagher-694-701.pdf) for provisional body-fat reference bands. Table 4 uses African American/white 4-compartment estimates and ages 20–79; its numbers differ from some commercial charts. No extrapolation outside its age bands.

**Source verification limitation:** the original Kushner–Schoeller abstract/publication record was accessible, but attempts to obtain its original PDF were blocked by the publisher. The coefficients above were corroborated in [NASA's 1993 experimental comparison, Table 2](https://ntrs.nasa.gov/api/citations/19930014545/downloads/19930014545.pdf) and [published experimental methods in PLOS ONE](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0226767). Direct comparison with the original printed equation table remains outstanding; this implementation must not be described as having completed that specific verification.

The original BIA methods use whole-body resistance at 50 kHz. The scale's frequency and equivalence of its foot-to-foot inferred impedance to that resistance are unknown. Estimates are not validated clinical measurements. BIA results require an adult profile, positive finite inputs and physically consistent outputs; invalid results are omitted rather than clamped. Weight, impedance, FFM, skeletal muscle and BMR receive no traffic-light classifications.

## HealthKit

The existing HealthKit manager requests profile reads and authorisation to write measured body mass, estimated body-fat percentage, estimated lean body mass, and manually measured waist. iOS is the sole body-measurement writer. It uses a stable per-UUID/per-type HealthKit sync identifier and sync version 1, plus method/version metadata on estimates. Body-fat percentages are converted to HealthKit's fractional representation.

Only authorised types are saved, and completed export types are tracked in SwiftData. Failed/denied exports remain retryable at launch or from the body UI. Impedance, BMR and skeletal muscle are not placed into unrelated HealthKit types. BMI is displayed locally; no BMI HealthKit write was added.

Changing the calculation model does not require changing raw records. If a future release should replace historical HealthKit estimates, it must explicitly migrate the export bookkeeping and increment the HealthKit sync version, preserving the original input snapshot.

## Regression fixtures and validation

These are deterministic formula fixtures, not reference body-fat truth or FitDays targets:

| Fixture | TBW L | FFM kg | Body fat % | Skeletal muscle kg | BMR kcal/day |
| --- | ---: | ---: | ---: | ---: | ---: |
| Male, 47, 172 cm, 67.8 kg, 529 Ω, waist 85 cm | 40.24045671 | 54.97330152 | 18.91843434 | 28.01567864 | 1557.42331278 |
| Female, 35, 154.94 cm, 50.6 kg, 532 Ω | 30.86568078 | 42.16623057 | 16.66752851 | 20.71205234 | 1280.79058041 |

Tests cover representative packets following the experiment's verified layout, checksum masking/rejection, XOR key, reversed MAC, live/final bits, impedance metadata, unknown frame retention, frame ordering, duplicate freezing, timeout, cancellation, invalid values, formulas, age calculation, reference boundaries, durable outbox reload/ack/corruption, older sync payloads, SwiftData deduplication and V2→V3 migration. The experiment contains source but no archived physical packet log; tests label the packets as representative.

At implementation validation: **47 iOS tests and 33 watchOS tests passed**, including existing tests. Both app targets and their embedded widget dependencies build with Xcode.

The iOS simulator UI check verified navigation from Settings to body profile/scale and history, readable missing-input guidance and empty states, and opening/cancelling the waist form. No fabricated measurements or settings were saved. Populated charts/gauges and physical Bluetooth reception were not exercised by this check.

The Watch simulator check verified the Body measurement entry, Ready screen, Start action, the expected “Bluetooth is unavailable” state, and returning to the session picker. Simulator device sessions were closed after verification.

Physical checks still required: direct Watch discovery/repeated advertisements, Bluetooth permission/off-state transitions, barefoot completion timing, socks/weight-only timeout, screen-inactive cancellation, disconnected phone delivery and relaunch, HealthKit partial permissions/retries, and production CloudKit schema deployment. Confirm impedance units, metadata meaning, excitation frequency and model suitability separately.

## Files

Added shared files: `BodyMeasurements.swift`, `ScaleProtocol.swift`, `BodyCompositionCalculator.swift`, `BodyMeasurementOutbox.swift`, `HealthKitBodyMeasurements.swift`.

Added iOS files: `TrainingSchemaV3.swift`, `BodyMeasurementStore.swift`, `BodyProfileSettingsView.swift`, `BodyCompositionHistoryView.swift`.

Added Watch files: `ScaleMeasurementController.swift`, `ScaleMeasurementView.swift`.

Added tests: `BodyMeasurementTests.swift` in each existing test target, and iOS `BodyPersistenceTests.swift`.

Updated integration files: `Schema.swift`, `HealthKitManager.swift`, `WatchConnectivityManager.swift`, `iOSWatchConnectivityDelegate.swift`, `TrainingApp.swift`, `BodyStatsView.swift`, `SettingsView.swift`, `SessionPickerView.swift`, the project target memberships/privacy descriptions, and the Practice scheme's registration of its existing test target.

## Body Stats UI refinement

Body Stats now combines Practice scale readings and Apple Health weight / VO₂ max in the existing material-card visual language. Weight, rounded estimated body fat and VO₂ max lead with current values and three-month trends. Available fat-free mass, estimated skeletal muscle, waist/height and BMI use a quieter summary section. Technical values stay in measurement detail.

Metric history offers 1/3/6/12-month and all-available ranges, individual readings and applicable reference bands. Health history is fetched for the past year; Practice history can extend further back. Weight display removes matching Health export copies by timestamp and value. Seven-day means use calendar days with equal weight per observed day, not seven consecutive samples. Long gaps remain disconnected. Change summaries require at least a week; adequately sampled histories spanning four weeks compare the first and latest observed weeks. These display transformations do not alter canonical observations or calculation versions.

Reference bars show a highlighted reference interval and a position marker, with an explicit text classification. They do not present increasing values as progress. Cards and detail screens use semantic colours, Dynamic Type text styles and accessibility labels; measurement lists provide the precise values behind charts.

New UI files: `BodyStatsPresentation.swift`, `BodyStatsSamples.swift`; new display-behaviour tests: `BodyStatsPresentationTests.swift`. Refined `BodyStatsView.swift`, `BodyCompositionHistoryView.swift` and `SettingsView.swift`. `TrainingApp.swift` has a DEBUG/simulator-only inspection entry point: launch with `--body-stats-sample` (optionally `--body-stats-dark`, `--body-stats-large`, `--body-stats-single` or `--body-stats-empty`). It uses a separate in-memory container, bypasses normal startup/synchronisation, and disables export/configuration actions. No sample records enter the real Practice store or Apple Health. Normal launches and device/release builds retain the existing startup path.

UI-refinement validation: the iOS app builds and all **56 iOS tests pass**, including nine new presentation tests. Existing protocol, calculation, synchronisation and persistence tests are retained unchanged.

The refinement was visually exercised on iPhone 17 simulator with populated light/dark data, metric-range switching, body-fat/BMI/waist reference gauges, technical disclosures, Accessibility 3 text size, single-point histories and empty states. Chart height increases at accessibility sizes after inspection identified cramped axis labels. No remaining visual issues were observed. Normal startup reached the simulator's first-run Health access sheet; permissions were left unchanged, so ordinary Dashboard/Settings navigation was not reverified in that run. The sample-mode body navigation was verified. Device interaction sessions were closed.

## Data-integrity follow-up

The former in-app CloudKit schema-promotion action has been disabled: it wrote diagnostic seed records to the live store, including the V3 zero-waist seed. Do not use that approach to initialise a schema. See [DataIntegrityInvestigation.md](DataIntegrityInvestigation.md) for the cause, non-destructive handling of existing invalid records, workout/rotation safeguards and focused regression validation.
