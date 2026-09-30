class_name Difficulty
extends RefCounted
## Difficulty only changes three things: how many notes the chart has, how wide the hit
## windows are, and how much a mistake costs the rift's stability.

const EASY := 0
const NORMAL := 1
const HARD := 2
const NAMES := ["EASY", "NORMAL", "HARD"]
const COLORS := [Color("b6ff4a"), Color("35e6ff"), Color("ff4fa3")]
const DESCRIPTIONS := [
	"Beats only. Wide timing. Forgiving rift.",
	"The intended groove.",
	"Extra notes, tight timing, the rift bites back.",
]

const WINDOW_SCALE := [1.3, 1.0, 0.82]   ## multiplies the hit windows
const LOSS_SCALE := [0.6, 1.0, 1.35]     ## multiplies stability lost on a miss / dropped hold
const GAIN_SCALE := [1.25, 1.0, 0.85]    ## multiplies stability gained on hits
const SCORE_SCALE := [0.8, 1.0, 1.25]    ## score multiplier, so harder runs rank higher
