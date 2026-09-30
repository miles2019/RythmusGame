# NEON BEAT//RIFT

4-lane rhythm duel in Godot 4.7 with a Newgrounds / FNF cartoon look. All art is procedural and all
built-in music is synthesized at runtime (placeholders, marked in code).

**Run:** open the project in Godot 4.7 and press F5 (main scene `scenes/Main.tscn`).
**Controls:** arrows + WASD (rebindable in Options), gamepad d-pad / face buttons, Esc = pause, R on results = retry.

## Modes
- **Story Mode** - 8 chapters (alley, rooftop, basement, data core, arena, ballroom, junkyard, the Rift), each with its
  own song style (funk, house, punk, drum'n'bass, trap, synthwave, rave, finale), rival, stage and cutscene.
  A chapter unlocks the next one when cleared (rank C or better).
- **Freeplay** - every cleared song, optional no-fail practice, plus your uploaded songs.
- **Upload Music** - mp3/ogg/wav: tempo + first beat are detected, you fine-tune against a metronome, the chart is built
  from the real onsets. Saved songs live in `user://songs`; Del on a song removes it.
- **Difficulty** Easy / Normal / Hard: note density, hit windows (40/80/115 ms x scale), scroll speed, stability
  loss and start value all change. **Stray taps (pressing with no note near) cost stability and the combo**, and
  pressing far too early burns the note, so button mashing fails on every difficulty.

## Sync
- Built-in charts are generated from the events the synth records while rendering the song (kick, snare, bass,
  melody ...), so notes follow the music exactly. Melody contour maps to lane position.
- Options -> **Calibrate audio sync**: tap along to a click track; the median offset becomes the latency offset.

## Performance
Static backdrop layers (`stage.gd` Back, lane strips) are cached draw commands; characters redraw at ~45 fps;
particles skip all work when idle; halftone is one tiled texture. Options has "Screen effects (shader)" and "Show FPS".

## Layout
| Area | Files |
|---|---|
| Flow | `main.gd`, `main_menu.gd`, `slant_menu.gd`, `song_select.gd`, `dialogue_screen.gd`, `loading_screen.gd`, `import_screen.gd`, `calibration_screen.gd`, `song_scene.gd`, `result_screen.gd`, `pause_menu.gd`, `options_menu.gd` |
| Data | `songs.gd` (catalogue + story text), `difficulty.gd`, `progress.gd` (autoload: unlocks, bests, uploads) |
| Timing | `beat_clock.gd`, `note_lane.gd` (judging), `chart.gd` (event charts, custom charts) |
| Audio | `synth.gd` (8 styles, event recording, disk cache), `custom_songs.gd` (decode + tempo detection) |
| Feel | `gamefeel_manager.gd`, `fx_layer.gd`, `post_fx.gd` (shader), `camera_rig.gd`, `stage.gd` |
| Characters | `character.gd` (springs, line boil, damage), `player_character.gd`, `rival_character.gd` (8 variants) |
| UI | `ui_kit.gd`, `comic_bg.gd`, `hud.gd` |

## Tests
```
godot --headless --path . res://tests/smoke.tscn -- perfect 1 1   # bot: mode(perfect|jitter|miss|spam|reduced) song(0-7) difficulty(0-2)
godot --headless --path . res://tests/audio_stats.tscn            # render all songs, note counts + peak density per difficulty
godot --headless --path . res://tests/analyze.tscn                # tempo detection on generated tracks
godot --headless --path . res://tests/import_flow.tscn            # upload -> tune -> save -> play
godot --path . res://tests/flow.tscn                              # menu -> story -> dialogue -> song -> pause -> result -> unlock
godot --path . res://tests/ui_shots.tscn -- <dir>                 # screenshots of menu screens
```
Tests redirect saves to `user://test_progress.cfg`; they never touch your real progress.
