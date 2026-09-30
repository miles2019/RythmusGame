class_name Difficulty
extends RefCounted
## Difficulty changes: how many notes the chart has, how tight the hit windows are, how fast the
## notes scroll, how much a mistake (miss, stray tap, dropped hold) costs, and the score multiplier.
## Stray taps (pressing with no note nearby) are punished, so button mashing no longer works.

const EASY := 0
const NORMAL := 1
const HARD := 2
const NAMES := ["EASY", "NORMAL", "HARD"]
const SHORT_NAMES := ["EASY", "NORM", "HARD"]
const COLORS := [Color("b6ff4a"), Color("35e6ff"), Color("ff4fa3")]
const DESCRIPTIONS := [
	"Follows the beat. Forgiving timing. Stray taps cost a little.",
	"Follows the music note by note. Stray taps hurt. Mashing gets you killed.",
	"Every drum hit and melody note. Tight timing. Fast scroll. No mercy.",
]

const WINDOW_SCALE := [1.15, 0.92, 0.72]  ## multiplies the base hit windows (40/80/115 ms)
const LOSS_SCALE := [0.7, 1.0, 1.4]       ## multiplies stability lost on a miss / dropped hold
const GAIN_SCALE := [1.2, 1.0, 0.85]      ## multiplies stability gained on hits
const SCORE_SCALE := [0.8, 1.0, 1.35]     ## score multiplier, so harder runs rank higher
const SCROLL_SPEED := [470.0, 590.0, 720.0]  ## note speed in px/s
const STRAY_LOSS := [1.2, 2.6, 4.0]       ## stability lost for a tap with no note near it
const START_STABILITY := [60.0, 50.0, 45.0]
