class_name Songs
extends RefCounted
## Built-in song catalogue (= story chapters). Every song shares the same 40-bar arrangement
## (intro / verse / build / drop / final / outro) but differs in tempo, key, style, rival and look.
## Custom (uploaded) songs are described by the same "info" dictionary, see make_info().

## quality -> chord intervals
const CHORDS := {
	"min": [0, 3, 7], "maj": [0, 4, 7], "dom": [0, 4, 7, 10], "min7": [0, 3, 7, 10], "pow": [0, 7, 12],
}

const LIST := [
	{
		"id": "gum_drop", "title": "GUM DROP GROOVE", "artist": "Mika vs. Gum Grin", "bpm": 100.0,
		"style": "funk", "theme": "alley", "rival": "gum", "root": 40, "stars": 1, "seed": 11,
		"prog": [[0, "min7"], [5, "dom"], [0, "min7"], [5, "dom"], [3, "maj"], [7, "dom"], [0, "min7"], [7, "dom"]],
		# hook: [step16, semitones above root+24, length in steps] over 2 bars, repeated
		"hook": [[0, 0, 2], [3, 3, 1], [4, 5, 2], [8, 7, 2], [11, 5, 1], [12, 3, 2], [16, 0, 2], [19, 3, 1], [20, 7, 2], [24, 10, 2], [27, 7, 1], [28, 5, 3]],
		"chapter": "CHAPTER 1 - THE ALLEY",
		"intro": [["NARRATOR", "The Rift. A crack in the city's sound barrier. Every dropped beat widens it."],
			["MIKA", "Fine. Nobody else is gonna patch it with a soldering iron and a dream."],
			["GUM GRIN", "Hehehe! A kid with a boombox? I'll chew you up and blow a bubble!"]],
		"outro": [["GUM GRIN", "Ow! My gum! It lost its flavor!"],
			["MIKA", "One crack down. Feels like a lot more to go..."]],
	},
	{
		"id": "static_bloom", "title": "STATIC BLOOM", "artist": "Mika vs. Kuro Static", "bpm": 128.0,
		"style": "house", "theme": "roof", "rival": "kuro", "root": 45, "stars": 2, "seed": 42,
		"prog": [[0, "min"], [8, "maj"], [3, "maj"], [10, "maj"], [0, "min"], [8, "maj"], [10, "maj"], [7, "maj"]],
		"hook": [],
		"chapter": "CHAPTER 2 - THE ROOFTOP",
		"intro": [["KURO STATIC", "You fixed a crack. I grew a garden of static inside it."],
			["MIKA", "Weeds. You grew weeds, Kuro."],
			["KURO STATIC", "Calm down. Let's hear who the rift listens to."]],
		"outro": [["KURO STATIC", "...Hm. Louder than I expected."],
			["MIKA", "Who's running the crews, Kuro?"],
			["KURO STATIC", "Ask Mr. Null. Bring earplugs."]],
	},
	{
		"id": "null_pointer", "title": "NULL POINTER", "artist": "Mika vs. Mr. Null", "bpm": 140.0,
		"style": "punk", "theme": "club", "rival": "null", "root": 38, "stars": 3, "seed": 77,
		"prog": [[0, "pow"], [0, "pow"], [10, "pow"], [10, "pow"], [5, "pow"], [5, "pow"], [7, "pow"], [7, "pow"]],
		"hook": [[0, 0, 2], [2, 0, 1], [3, 3, 1], [4, 5, 2], [8, 7, 2], [10, 5, 1], [11, 3, 1], [12, 0, 4],
			[16, 0, 2], [18, 0, 1], [19, 3, 1], [20, 5, 2], [24, 10, 2], [26, 7, 1], [27, 5, 1], [28, 3, 4]],
		"chapter": "CHAPTER 3 - THE BASEMENT",
		"intro": [["MR. NULL", "NULL. VOID. NOTHING. That is what your beats will become."],
			["MIKA", "Cool mask. Does it come with a personality?"],
			["MR. NULL", "..."]],
		"outro": [["MR. NULL", "Segmentation fault."],
			["MIKA", "The core is under the old server farm. One more fight."]],
	},
	{
		"id": "overclock", "title": "OVERCLOCK", "artist": "Mika vs. Overclock", "bpm": 160.0,
		"style": "dnb", "theme": "server", "rival": "clock", "root": 43, "stars": 4, "seed": 99,
		"prog": [[0, "min"], [8, "maj"], [3, "maj"], [10, "maj"], [0, "min"], [8, "maj"], [3, "maj"], [7, "dom"]],
		"hook": [],
		"chapter": "CHAPTER 4 - THE CORE",
		"intro": [["OVERCLOCK", "BZZT. RIFT CORE ONLINE. ALL FREQUENCIES BELONG TO ME."],
			["MIKA", "Then I'll just have to turn you down."],
			["OVERCLOCK", "CALCULATING... YOUR CHANCE: ONE IN A BEAT."]],
		"outro": [["OVERCLOCK", "SYSTEM... SHUTTING DOWN... NICE... BEAT..."],
			["MIKA", "The Rift is quiet. For now. Let's keep the boombox warm."],
			["NARRATOR", "THE END - thanks for playing! Replay any song from CLASSIC."]],
	},
]

## Stage accent colours per theme: intro, verse, build, drop, final, outro
const THEMES := {
	"alley": [Color("ff4fa3"), Color("b6ff4a"), Color("ffb03b"), Color("ff4fa3"), Color("35e6ff"), Color("b388ff")],
	"roof": [Color("35e6ff"), Color("35e6ff"), Color("ff4fa3"), Color("ffb03b"), Color("b6ff4a"), Color("8f7bff")],
	"club": [Color("ff3b3b"), Color("ffb03b"), Color("ff4fa3"), Color("ff3b3b"), Color("fff36b"), Color("8f7bff")],
	"server": [Color("b6ff4a"), Color("35e6ff"), Color("fff36b"), Color("b6ff4a"), Color("ff4fa3"), Color("35e6ff")],
}
const SECTION_BARS := [0, 4, 12, 20, 28, 36]
const SECTION_NAMES := ["INTRO", "VERSE", "BUILD-UP", "DROP", "FINAL RIFT", "OUTRO"]


static func by_id(id: String) -> Dictionary:
	for s in LIST:
		if s.id == id:
			return s
	return {}


static func index_of(id: String) -> int:
	for i in LIST.size():
		if LIST[i].id == id:
			return i
	return -1


## Normalised "song info" used by SongScene / Synth / Chart for both built-in and custom songs.
static func make_info(def: Dictionary) -> Dictionary:
	if def.get("custom", false):
		return def.duplicate() # already info-shaped, see CustomSongs
	var info := def.duplicate(true)
	info["custom"] = false
	info["offset"] = 0.0
	info["bars"] = 40
	var accents: Array = THEMES[def.theme]
	var secs: Array = []
	for i in SECTION_BARS.size():
		secs.append({"bar": SECTION_BARS[i], "name": SECTION_NAMES[i], "accent": accents[i]})
	info["sections"] = secs
	return info
