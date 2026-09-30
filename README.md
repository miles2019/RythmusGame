# NEON BEAT//RIFT

4-lane rhythm duel in Godot 4.7, "Neon Ink Pop" with a Newgrounds / FNF cartoon look. All art is procedural
and all built-in music is synthesized at runtime (placeholders, marked in code).

**Run:** open the project in Godot 4.7 and press F5 (main scene `scenes/Main.tscn`).

**Controls:** arrows + WASD (rebindable in Options), gamepad d-pad / face buttons, Esc = pause, R on results = retry.

## Modes
- **Story Mode** - 4 chapters (alley, rooftop, basement, server core), each with its own song, rival and cutscene.
  A chapter unlocks the next one when cleared (rank C or better).
- **Classic / Replay** - every cleared song, free play, optional no-fail practice, plus your uploaded songs.
- **Upload Music** - pick an mp3/ogg/wav. The game decodes it (faster than real time), detects tempo and first
  beat, lets you fine-tune BPM/offset against a metronome, and builds a chart from the real onsets.
  Uploaded songs are copied to `user://songs`; press Del on a card in Classic to remove one.
- **Difficulty** Easy / Normal / Hard changes note count, hit windows and how much a mistake costs.

## Layout
| Area | Files |
|---|---|
| Flow | `main.gd`, `main_menu.gd`, `song_select.gd`, `dialogue_screen.gd`, `loading_screen.gd`, `import_screen.gd`, `song_scene.gd`, `result_screen.gd`, `pause_menu.gd`, `options_menu.gd` |
| Data | `songs.gd` (catalogue + story text), `difficulty.gd`, `progress.gd` (autoload: unlocks, bests, uploads) |
| Timing | `beat_clock.gd`, `note_lane.gd` (judging), `chart.gd` (built-in + custom charts) |
| Audio | `synth.gd` (styles: funk / house / punk / dnb, cached on disk), `custom_songs.gd` (decode + tempo detection) |
| Feel | `gamefeel_manager.gd` (autoload), `fx_layer.gd`, `post_fx.gd` (shader), `camera_rig.gd`, `stage.gd` |
| Characters | `character.gd` (springs, line boil, damage system), `player_character.gd`, `rival_character.gd` (4 variants) |
| UI | `ui_kit.gd`, `comic_bg.gd`, `song_card.gd`, `hud.gd` |

## Tests
```
godot --headless --path . res://tests/smoke.tscn -- perfect 1 1   # bot plays a song: mode song(0-3) difficulty(0-2)
godot --headless --path . res://tests/analyze.tscn                # tempo detection on generated tracks
godot --headless --path . res://tests/import_flow.tscn            # upload -> tune -> save -> play
godot --path . res://tests/flow.tscn                              # menu -> story -> dialogue -> song -> pause -> result -> unlock
godot --path . res://tests/ui_shots.tscn -- <dir>                 # screenshots of all menu screens
```
Tests redirect saves to `user://test_progress.cfg`; they never touch your real progress.
