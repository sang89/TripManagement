# Sport Analysis — Plan

> **Status:** Planning only — no implementation started.
> **Target:** Standalone Flutter app (working name: SportCoach / SportLens).
> This doc lives in TripManagement temporarily; move it when the new repo is created.

---

## Vision

A mobile (iOS + Android) app that lets users record or upload a sport video clip, then
receive AI-powered coaching feedback — what went wrong, what was good, and how to improve —
without requiring a human coach to be present.

Initial sport: **badminton**. Architecture must be sport-agnostic from day one so adding
tennis, basketball, golf, etc. is additive rather than structural.

---

## Guiding constraints

1. **Free where possible** — every component must have a zero-cost path; paid tiers are
   opt-in upgrades, never required for core functionality.
2. **On-device first** — pose detection and frame extraction run locally; no user video
   is uploaded to a server unless the user opts in to AI coaching.
3. **Sport-agnostic architecture** — models, rule engines, and prompts are injected per
   sport; shared infrastructure is sport-blind.
4. **Separate app** — this is not a feature of TripManagement or PropertyManagement;
   it ships as its own Flutter project with its own Firebase / Supabase project.
5. **No training from scratch** — use pretrained models and free APIs; fine-tuning is a
   future milestone, not a prerequisite for launch.

---

## Free tech stack

### Always free (on-device, no quota)

| Tool | Flutter package | Purpose |
|---|---|---|
| ML Kit Pose Detection (BlazePose) | `google_mlkit_pose_detection ^0.11` | 33 body landmarks per frame; iOS + Android |
| FFmpeg | `ffmpeg_kit_flutter_min ^6` | Extract frames from video at configurable FPS |
| Dart math | — (stdlib) | Joint angle, velocity, symmetry calculations |

These three together are unconditionally free forever — no quota, no network call, no
third-party dependency at runtime.

### Conditionally free (Gemini free tier)

| Tool | Flutter package | Limits |
|---|---|---|
| Gemini 2.0 Flash | `google_generative_ai` | 1,500 req/day · 15 RPM · 1M TPM |

Caveats:
- Data submitted on the free tier **may be used by Google for model training**.
- **Not available in the EU** (GDPR exclusion).
- Google can change or withdraw the free tier at any time.
- Gemini is an *optional enhancement layer* — the rule-based pipeline must work without it.

### Not used (and why)

| Tool | Reason skipped |
|---|---|
| Shuttlecock / ball tracking (YOLO fine-tune) | Requires labeled dataset + GPU; deferred to v2 |
| Web platform | ML Kit has no web support; deferred |
| On-device LLM (e.g. Gemma via `flutter_gemma`) | Model size too large for mobile v1; deferred |
| Video upload to cloud for processing | Privacy concern + cost; opt-in only |

---

## Analysis pipeline

```
┌─────────────────────────────────────────────────────────┐
│                      User input                         │
│   Record new clip  │  Pick from gallery (≤ 60 sec)      │
└─────────────────────────────┬───────────────────────────┘
                              │
                    ┌─────────▼──────────┐
                    │  Frame extraction  │
                    │  ffmpeg_kit        │
                    │  1 frame / 250 ms  │
                    │  (configurable)    │
                    └─────────┬──────────┘
                              │  List<Uint8List> frames
                    ┌─────────▼──────────┐
                    │  Pose detection    │
                    │  ML Kit            │
                    │  33 landmarks/frame│
                    │  (x, y, z, conf)  │
                    └─────────┬──────────┘
                              │  List<PoseFrame>
                    ┌─────────▼──────────┐
                    │  Joint analysis    │
                    │  Pure Dart         │
                    │  angles, velocity, │
                    │  symmetry, timing  │
                    └─────────┬──────────┘
                              │  AnalysisResult
              ┌───────────────┴───────────────┐
              │                               │
    ┌─────────▼──────────┐       ┌────────────▼────────────┐
    │  Rule-based flags  │       │  Gemini coaching tip    │
    │  Always runs       │       │  Optional / Pro gate    │
    │  Zero API cost     │       │  Free tier: 1,500/day   │
    │  Instant result    │       │  Sends: keypoints +     │
    └─────────┬──────────┘       │  2 representative frames│
              │                  └────────────┬────────────┘
              └───────────────┬───────────────┘
                              │
                    ┌─────────▼──────────┐
                    │  Coaching report   │
                    │  Flags + severity  │
                    │  Natural language  │
                    │  tips (if Gemini)  │
                    │  Frame highlights  │
                    └────────────────────┘
```

### Frame extraction strategy

- Extract at **4 FPS** (1 frame per 250 ms) for a 30-second clip → 120 frames.
- Optionally extract at higher rate only around flagged moments (motion peaks).
- Drop frames where ML Kit confidence < 0.5 on key landmarks.

### Pose landmarks used (ML Kit indices)

```
LEFT_SHOULDER  = 11    RIGHT_SHOULDER = 12
LEFT_ELBOW     = 13    RIGHT_ELBOW    = 14
LEFT_WRIST     = 15    RIGHT_WRIST    = 16
LEFT_HIP       = 23    RIGHT_HIP      = 24
LEFT_KNEE      = 25    RIGHT_KNEE     = 26
LEFT_ANKLE     = 27    RIGHT_ANKLE    = 28
NOSE           = 0
```

### Computed metrics (sport-agnostic)

| Metric | Formula | Use |
|---|---|---|
| Joint angle | `acos(dot(BA, BC) / (|BA| * |BC|))` | Elbow, knee, shoulder bend |
| Angular velocity | `Δangle / Δtime` between frames | Swing speed, deceleration |
| Body symmetry | Δ(left vs right landmark Y) | Weight distribution |
| Center of mass | Average of hip midpoints | Footwork stability |
| Wrist velocity | `|Δwrist_pos| / Δtime` | Racket/paddle speed proxy |
| Trunk lean | Angle: shoulder midpoint → hip midpoint vs vertical | Posture |

---

## Rule engine (sport-agnostic)

A rule is a plain Dart function:

```dart
typedef AnalysisRule = List<Flag> Function(List<PoseFrame> frames, SportConfig config);
```

`SportConfig` carries sport-specific thresholds (ideal elbow angle, expected knee bend, etc.).
Rules are registered per sport at startup — adding a new sport = adding a new `SportConfig`
and a list of `AnalysisRule` functions.

### Badminton rules (v1)

| Rule | Flag | Threshold |
|---|---|---|
| Elbow angle at wrist peak velocity | `ELBOW_TOO_LOW` | < 100° |
| Knee bend during split step | `KNEES_NOT_BENT` | < 20° flex |
| Trunk lean > threshold | `LEANING_TOO_FAR` | > 35° from vertical |
| Racket arm below shoulder at contact | `ARM_TOO_LOW` | wrist Y > shoulder Y |
| Weight on heels (ankle vs hip alignment) | `WEIGHT_BACK` | hip behind ankle midpoint |
| No split step detected before shot | `NO_SPLIT_STEP` | knee velocity spike absent |

Thresholds are constants in `SportConfig.badminton` — a coach can adjust them without
changing rule logic.

---

## Gemini integration (optional layer)

### What gets sent

```json
{
  "sport": "badminton",
  "shot_type": "smash",
  "flags": ["ELBOW_TOO_LOW", "NO_SPLIT_STEP"],
  "keypoints_summary": {
    "elbow_angle_at_peak": 87,
    "knee_bend_avg": 12,
    "wrist_peak_velocity": 4.2
  },
  "frames": ["<base64 frame at peak>", "<base64 frame at follow-through>"]
}
```

Two frames max to stay within token budget.

### System prompt (badminton)

```
You are an expert badminton coach. You will receive joint angle data and 1–2 video frames
from a player's shot. Provide concise coaching feedback (3–5 sentences max). Focus on the
flagged issues. Be encouraging but specific. Avoid repeating the raw numbers — translate
them into plain coaching language.
```

The system prompt is stored per sport in `SportConfig` so it is never hardcoded in shared
infrastructure.

### Free tier management

- Count daily Gemini calls in shared preferences; disable the Gemini layer when approaching
  1,400 (buffer below 1,500 hard limit).
- Show the user a message: "Detailed AI coaching unavailable today — basic analysis still
  runs." Basic = rule-based flags only.
- Reset counter at midnight local time.

---

## App structure (planned folder layout)

```
lib/
├── config/
│   └── api_keys.dart            # git-ignored; Gemini key
├── models/
│   ├── pose_frame.dart          # Landmark list + timestamp
│   ├── analysis_result.dart     # Flags + metrics + Gemini tip
│   └── flag.dart                # Enum: flag type, severity, frame index
├── sports/
│   ├── sport_config.dart        # Abstract config class
│   ├── badminton/
│   │   ├── badminton_config.dart
│   │   └── badminton_rules.dart
│   └── (tennis/, golf/, ...)    # Future sports added here
├── services/
│   ├── frame_extractor.dart     # ffmpeg_kit wrapper
│   ├── pose_detector.dart       # ML Kit wrapper
│   ├── rule_engine.dart         # Runs registered rules
│   ├── gemini_coach.dart        # Optional Gemini call
│   └── gemini_quota.dart        # Daily call counter
├── providers/
│   ├── analysis_provider.dart   # Orchestrates pipeline
│   └── sport_provider.dart      # Selected sport
├── screens/
│   ├── home_screen.dart         # Sport picker + recent analyses
│   ├── record_screen.dart       # Camera + gallery pick
│   ├── processing_screen.dart   # Progress while pipeline runs
│   └── report_screen.dart       # Flags + overlays + Gemini tip
└── widgets/
    ├── pose_overlay.dart        # Draw skeleton on video frame
    ├── flag_card.dart           # Individual flag with severity
    └── coaching_tip_card.dart   # Gemini result card
```

---

## Data model

### PoseFrame

```dart
class PoseFrame {
  final int frameIndex;
  final Duration timestamp;
  final Map<PoseLandmarkType, PoseLandmark> landmarks; // ML Kit type
}
```

### Flag

```dart
enum FlagSeverity { info, warning, critical }

class Flag {
  final String ruleId;         // e.g. "ELBOW_TOO_LOW"
  final FlagSeverity severity;
  final int frameIndex;        // frame where flag was triggered
  final String description;    // human-readable, sport-specific
  final double? measuredValue; // e.g. 87.0 (degrees)
  final double? idealValue;    // e.g. 110.0
}
```

### AnalysisResult

```dart
class AnalysisResult {
  final String sport;
  final String? detectedShotType;
  final List<Flag> flags;
  final Map<String, double> metrics; // raw computed values
  final String? geminiTip;           // null if Gemini skipped
  final DateTime analyzedAt;
}
```

---

## Platform considerations

| Platform | Pose detection | Frame extraction | Gemini | Notes |
|---|---|---|---|---|
| iOS | ✅ ML Kit | ✅ ffmpeg_kit | ✅ | Full pipeline |
| Android | ✅ ML Kit | ✅ ffmpeg_kit | ✅ | Full pipeline |
| Web | ❌ ML Kit unsupported | ❌ ffmpeg_kit unsupported | ✅ | Web: Gemini-only mode (send frames, skip local pose); deferred |

Web support is a v2 concern. v1 ships iOS + Android only.

---

## Privacy

- Video **never leaves the device** unless the user explicitly requests AI coaching.
- When Gemini is called, only two frames (as base64 PNG) and numeric keypoint data are sent —
  no audio, no metadata, no user identity.
- On the free Gemini tier, Google may use submitted data for model improvement. Add a
  disclosure in the app before the first Gemini call.
- Local analysis results are stored in SQLite (via `drift`) on-device only; no cloud sync in v1.

---

## Build phases

### Phase 1 — On-device pipeline (free, no APIs)

- [ ] New Flutter project scaffold
- [ ] `ffmpeg_kit_flutter_min` integration: pick video, extract frames
- [ ] `google_mlkit_pose_detection` integration: landmarks per frame
- [ ] `PoseOverlay` widget: draw skeleton on a frame
- [ ] Joint angle + velocity calculations (pure Dart)
- [ ] Rule engine with badminton config
- [ ] `ReportScreen`: list flags with severity, highlight frame

**Exit criteria:** user picks a badminton clip, sees pose skeleton and rule-based flags.
No network call made.

### Phase 2 — Gemini coaching layer

- [ ] `GeminiCoach` service: build prompt, send frames, parse response
- [ ] `GeminiQuota` service: daily counter in shared preferences
- [ ] `CoachingTipCard` widget in report screen
- [ ] Disclosure dialog on first Gemini use
- [ ] Graceful degradation when quota hit

**Exit criteria:** user sees natural language coaching tip below the flags.

### Phase 3 — Shot type detection

- [ ] Classify shot type (smash, drop, clear, net) from wrist velocity + arm angle trajectory
- [ ] Use classification to select the right rule subset
- [ ] Show detected shot type in report header

**Exit criteria:** app correctly identifies shot type from pose data alone on ≥ 80% of test clips.

### Phase 4 — UX polish + history

- [ ] `drift` SQLite: persist analysis results locally
- [ ] History screen: past analyses with trend charts
- [ ] Shareable coaching report (screenshot / PDF)
- [ ] Second sport (tennis) to validate sport-agnostic architecture

### Phase 5 — Optional cloud features (future, paid)

- [ ] Cloud video storage (user opt-in, Supabase Storage)
- [ ] Coach review mode: send analysis to a human coach for annotation
- [ ] Fine-tuned shot classifier (if enough labeled data collected)

---

## Key risks and mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| ML Kit pose confidence low for fast motion (shuttle smash) | High | Drop low-confidence frames; flag to user that clip quality affects accuracy |
| Gemini free tier withdrawn or limited further | Medium | Rule engine is always the primary path; Gemini is enhancement only |
| Angle thresholds wrong for all player body types | Medium | Make thresholds configurable; add coach review feedback loop in v2 |
| ffmpeg_kit binary size too large | Low | Use `ffmpeg_kit_flutter_min` (video only, no audio codecs); measure IPA/APK delta |
| Shot type misclassification | High | Show detected shot type + let user correct it; correction feeds future tuning |

---

## Open questions (to resolve before Phase 1)

1. **App name** — SportCoach? SportLens? CoachAI? (no implementation impact)
2. **Supabase project** — share with TripManagement/PropertyManagement or create a new one?
   (Recommendation: new project — different user base, different schema, cleaner billing separation)
3. **Auth** — required in v1? Guest mode (local only) is simpler for early testing.
4. **Minimum clip length** — need at least ~2 seconds to detect a shot; maximum 60 sec to
   keep frame count manageable. Enforce in UI.
5. **Coach involvement** — who defines the rule thresholds for badminton? Need at least one
   domain expert review before publishing.
