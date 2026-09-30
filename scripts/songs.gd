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
		"chapter": "CHAPTER 4 - THE DATA CORE",
		"intro": [["OVERCLOCK", "BZZT. DATA CORE ONLINE. ALL FREQUENCIES BELONG TO ME."],
			["MIKA", "Then I'll just have to turn you down."],
			["OVERCLOCK", "CALCULATING... YOUR CHANCE: ONE IN A BEAT."]],
		"outro": [["OVERCLOCK", "SYSTEM... SHUTTING DOWN... NICE... BEAT..."],
			["MIKA", "The servers are quiet. But something bigger is still humming."],
			["NARRATOR", "But the hum does not stop. It comes from far, far below the city..."]],
	},
	{
		"id": "thunder_trap", "title": "THUNDER TRAP", "artist": "Mika vs. Bolt", "bpm": 140.0,
		"style": "trap", "theme": "arena", "rival": "bolt", "root": 41, "stars": 3, "seed": 123,
		"prog": [[0, "min"], [0, "min"], [8, "maj"], [8, "maj"], [3, "maj"], [3, "maj"], [10, "maj"], [7, "dom"]],
		"hook": [[0, 0, 3], [4, 3, 2], [8, 5, 2], [12, 7, 3], [16, 7, 2], [20, 5, 2], [24, 3, 4], [28, 0, 2]],
		"chapter": "CHAPTER 5 - THE ARENA",
		"intro": [["NARRATOR", "Past the core, the city's old arena hums with stolen sound."],
			["BOLT", "Yo! Fastest fingers in the Rift, that's me! Try to keep up, headphones!"],
			["MIKA", "You're fast. But are you on beat?"],
			["BOLT", "Beat? I AM the beat! ...Wait, what's a beat?"]],
		"outro": [["BOLT", "Okay okay, you're faster at the rhythm part. Rude."],
			["MIKA", "Who's behind the noise crews, Bolt?"],
			["BOLT", "The Queen. She hums from the old ballroom. Don't curtsy wrong."]],
	},
	{
		"id": "velvet_drive", "title": "VELVET DRIVE", "artist": "Mika vs. Queen Vex", "bpm": 110.0,
		"style": "wave", "theme": "ballroom", "rival": "queen", "root": 47, "stars": 3, "seed": 222,
		"prog": [[0, "min"], [8, "maj"], [3, "maj"], [5, "min"], [0, "min"], [8, "maj"], [3, "maj"], [10, "maj"]],
		"hook": [[0, 7, 2], [2, 5, 2], [4, 3, 2], [6, 5, 2], [8, 7, 4], [16, 10, 2], [18, 7, 2], [20, 5, 2], [22, 3, 2], [24, 5, 6]],
		"chapter": "CHAPTER 6 - THE BALLROOM",
		"intro": [["QUEEN VEX", "A street rat with a boombox. How delightfully unhygienic."],
			["MIKA", "I patch cracks. You hoard the noise. Let's dance, Your Majesty."],
			["QUEEN VEX", "Darling, I've been dancing since before your speakers were soldered."]],
		"outro": [["QUEEN VEX", "Impossible! My crown... it's off-key!"],
			["MIKA", "Keep the crown. Give the noise back."],
			["QUEEN VEX", "Fine. But the one who taught me to hoard it... he lives in the junkyard. Beware."]],
	},
	{
		"id": "scrap_rave", "title": "SCRAP RAVE", "artist": "Mika vs. Brute", "bpm": 150.0,
		"style": "rave", "theme": "junkyard", "rival": "brute", "root": 36, "stars": 4, "seed": 333,
		"prog": [[0, "min"], [0, "min"], [8, "maj"], [8, "maj"], [5, "min"], [5, "min"], [7, "maj"], [7, "maj"]],
		"hook": [[0, 0, 2], [3, 0, 1], [4, 7, 2], [7, 7, 1], [8, 5, 2], [11, 3, 1], [12, 5, 4], [16, 0, 2], [19, 0, 1], [20, 10, 2], [23, 10, 1], [24, 8, 2], [27, 7, 1], [28, 5, 4]],
		"chapter": "CHAPTER 7 - THE JUNKYARD",
		"intro": [["BRUTE", "GRAAAH. BRUTE CRUSH SMALL MUSIC."],
			["MIKA", "Big guy. Bigger speakers. I like it."],
			["BRUTE", "BRUTE LIKE BASS. BRUTE LIKE... YOUR HEADPHONES."],
			["MIKA", "Nope. Not those."]],
		"outro": [["BRUTE", "...Brute liked that. Brute wants a boombox now."],
			["MIKA", "Later. The source of the Rift is right behind you, isn't it?"],
			["BRUTE", "Yes. It is looking at you."]],
	},
	{
		"id": "rift_core", "title": "RIFT CORE", "artist": "Mika vs. The Rift", "bpm": 172.0,
		"style": "finale", "theme": "void", "rival": "core", "root": 40, "stars": 5, "seed": 444,
		"prog": [[0, "min"], [8, "maj"], [3, "maj"], [10, "maj"], [0, "min"], [8, "maj"], [5, "min"], [7, "dom"]],
		"hook": [[0, 0, 1], [1, 7, 1], [2, 12, 2], [4, 10, 2], [8, 7, 2], [10, 5, 1], [11, 3, 1], [12, 7, 4], [16, 0, 1], [17, 7, 1], [18, 12, 2], [20, 14, 2], [24, 12, 3], [27, 10, 1], [28, 7, 4]],
		"chapter": "FINAL CHAPTER - THE RIFT",
		"intro": [["NARRATOR", "At the bottom of the city, the Rift itself opens its eyes."],
			["THE RIFT", "SO MUCH NOISE. YOU FEED ME WITH EVERY BEAT YOU DROP."],
			["MIKA", "Then I'll stop dropping them. One perfect beat at a time."],
			["THE RIFT", "THEN LET US SEE HOW LONG YOUR HANDS CAN HOLD THE RHYTHM."],
			["NARRATOR", "This is the last song. Everything you learned, in one track."]],
		"outro": [["THE RIFT", "...quiet. Finally... quiet."],
			["MIKA", "Sleep well. I'll keep the beat for you."],
			["NARRATOR", "The Rift closes. The city hums in tune again."],
			["NARRATOR", "THE END - thanks for playing! Every song is free to replay in CLASSIC."]],
	},
]

## Stage accent colours per theme: intro, verse, build, drop, final, outro
const THEMES := {
	"alley": [Color("ff4fa3"), Color("b6ff4a"), Color("ffb03b"), Color("ff4fa3"), Color("35e6ff"), Color("b388ff")],
	"roof": [Color("35e6ff"), Color("35e6ff"), Color("ff4fa3"), Color("ffb03b"), Color("b6ff4a"), Color("8f7bff")],
	"club": [Color("ff3b3b"), Color("ffb03b"), Color("ff4fa3"), Color("ff3b3b"), Color("fff36b"), Color("8f7bff")],
	"server": [Color("b6ff4a"), Color("35e6ff"), Color("fff36b"), Color("b6ff4a"), Color("ff4fa3"), Color("35e6ff")],
	"arena": [Color("fff36b"), Color("35e6ff"), Color("ff4fa3"), Color("fff36b"), Color("b6ff4a"), Color("ffb03b")],
	"ballroom": [Color("ff4fa3"), Color("b388ff"), Color("ffb03b"), Color("ff4fa3"), Color("fff36b"), Color("b388ff")],
	"junkyard": [Color("ffb03b"), Color("ff6b3b"), Color("fff36b"), Color("ff3b3b"), Color("b6ff4a"), Color("ffb03b")],
	"void": [Color("b388ff"), Color("ff4fa3"), Color("35e6ff"), Color("ff3b3b"), Color("fff36b"), Color("b388ff")],
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
