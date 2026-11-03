# Practice

This is an Apple ecosystem app for my own personal use.  It tracks Simple and Sinister+ workouts.  The plus refers to the addition of Push/Pull Supersets.

The workouts are tracked using the Apple Watch and then synced with HealthKit.  Basic stats are shown in the iOS app.  

*NOTE: This app is for my own personal use.  You are welcome to copy all or any part of it.  However, as I have no intention of releasing it, there may well be bugs I haven't had the time to fix*

## Motivation

I got fed up of losing track of sets.  I was also curious to see what I could do with the data from HealthKit.  So, this is the end result.

I do fix bugs, as I come across them, but this is a personal/hobby project, so it's not in "active development".


## 6–8 week training trial

The Watch offers today's scheduled session automatically. The iPhone Today card shows its exercises and targets. Session definitions and weekday mapping live in `Shared/Data/WorkoutData.swift`.

| Day | Session |
| --- | --- |
| Monday, Wednesday, Friday | Existing warm-up, 10×10 swings, 10 alternating get-ups |
| Tuesday — Strength A | Ring push-ups 3×6, ring rows 3×6, goblet squats 2×5, hanging bent-knee raises 2×8 |
| Thursday — Mobility | Existing common stretches, supported ankle rocks and seated thoracic rotation |
| Saturday — Strength B | Clean and press 3×5 per side, pull-ups/assisted pull-ups 3×3–5, ring push-ups 2×6, hanging bent-knee raises 2×8 |
| Sunday | Rest; no scheduled strength |

**Joint Stretches** is available every day as one open-ended morning mobility session. Start it on the Watch to record elapsed time, heart rate and calories; Finish saves the duration without an exercise checklist. Evening skills, their completion-driven rotation and their stretches remain available separately.

S&S keeps the current normal/progression weights, progression-set slots and unrestricted recovery Ready button. Installing the trial does not overwrite those settings. To represent the stated six sets/reps at 24 kg and four at 16 kg, the existing settings can use 16 kg normal, 24 kg progression and six progression sets for both swings and get-ups.

Strength sessions use controlled reps, approximately 2–3 reps in reserve, and recovery at the user's pace. Choose goblet-squat and pressing loads independently on the Watch; the Watch remembers each choice locally, and each completed set stores the actual load. The left/right press steps share the pressing preference, alternate for three rounds, and do not feed the S&S milestone system. Use assistance for pull-ups as needed, adjust ring height/body position, keep knee raises controlled and keep squats within a comfortable range.

Increase reps, load or difficulty manually when all sets are consistently comfortable with clean technique. Actual reps are editable while logging; templates keep their prescribed set counts. There is no automatic volume increase, periodisation or trial end date. Review the programme after 6–8 weeks.

Thursday retains all five common stretches. The two additions each have two 30-second sets (one per side): gentle ankle rocks with support and seated upper-back rotations. These fill movement gaps in the existing template without adding strength work or altering evening sessions. Exercise cues follow [NHS ankle movement guidance](https://www.nhsinform.scot/illnesses-and-conditions/muscle-bone-and-joints/leg-and-foot-problems-and-conditions/exercises-for-ankle-pain/) and [NHS upper-back rotation guidance](https://www.uhs.nhs.uk/Media/UHS-website-2019/Patientinformation/Respiratory/Exercises-to-improve-your-posture-562-PIL.pdf); the two-minute allocation is a conservative programme choice, not a prescribed treatment.

Workout history uses the existing SwiftData schema and retains the legacy Morning/Evening raw session identifiers. Strength and mobility session names are additive. The trial also fixes set-to-value conversion so existing stored load and HR/timing fields are retained when reconstructing workouts. No live history is deleted or reseeded.
