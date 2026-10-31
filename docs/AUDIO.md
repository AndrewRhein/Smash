# Realms Rumble: audio guide (for whoever makes the sounds)

The game already plays audio; it only needs files. `scripts/audio/audio_director.gd` listens to gameplay events and plays sounds **by file name**. To add or replace a sound, drop a file at the right path. There is no code to change and nothing to register.

* **Formats:** `.ogg` (preferred), `.wav` or `.mp3`. Use 44.1 kHz, mono for SFX and voice, stereo for music.
* **Variants:** `name.ogg`, `name_1.ogg` … `name_9.ogg`. If several exist, one is picked at random each time, which keeps repeated lines from sounding robotic.
* **Missing files are skipped silently**, so the game works with any subset.
* **Levels:** peak around −3 dBFS. Aim for roughly −16 LUFS for music, and voice slightly louder than SFX. In-game volumes are controlled per bus (Master / Music / SFX / Voice) in **Settings**.
* **Placeholders:** everything in `audio/` today is a **placeholder** synthesized by `tools/synth_placeholder_audio.py` (chiptune blips and short loops). Replace freely.

```
audio/
  music/   menu.ogg  battle.ogg  victory.ogg            (+ later: battle_<stage>.ogg)
  sfx/     <effect id>.ogg  + jump, dodge, shield_up, shield_hit, shield_break, hit_heavy
  ui/      move.ogg  confirm.ogg  back.ogg
  announcer/ ready.ogg  go.ogg  game.ogg  draw.ogg     (none yet)
  voice/<character id>/<line>.ogg                    (none yet: see the script below)
```

## Music
| File | When | Notes |
|---|---|---|
| `music/menu` | Title, character select, settings | Loops. Calm, heroic |
| `music/battle` | Countdown and fight | Loops (looping is forced on). Energetic, about 140 BPM. Ideally 60–120 s with a clean loop point |
| `music/victory` | Result screen | Plays once. A 3–6 s fanfare |
Pausing ducks the music by 10 dB.

## Sound effects (gameplay)
| File | Plays when |
|---|---|
| `sfx/hit_spark` | Any hit (fallback for everything below) |
| `sfx/hit_heavy` | A hit dealing 12% or more |
| `sfx/shield_hit` | An attack lands on a shield |
| `sfx/shield_break` | A shield breaks (fighter becomes dizzy) |
| `sfx/shield_up` | Shield raised |
| `sfx/dodge` | Spot dodge, roll or air dodge |
| `sfx/jump`, `sfx/double_jump` | Jumps |
| `sfx/blast_ko` | A fighter is KO'd (big boom) |
| `sfx/respawn` | Respawn platform appears |
| `sfx/guard_block` | Force guard or energy shield blocks |
| `sfx/projectile_fizzle` | A fireball expires |
| `sfx/<move effect>` | Move swings and casts: `staff_swing`, `heavy_staff_swing`, `lightning_telegraph`, `lightning_bolt`, `fireball_cast`, `magic_push`, `saber_swing`, `heavy_saber_swing`, `force_push`, `force_choke`, `force_guard`, `choke_release`, `ion_jab`, `rocket_hammer`, `thruster_burst`, `orbital_tractor`, `energy_shield` |
| `ui/move`, `ui/confirm`, `ui/back` | Menu navigation |
| `announcer/ready`, `announcer/go`, `announcer/game`, `announcer/draw` | Countdown start, fight start, match end, draw |

## Voice lines (per character)
Path: `audio/voice/<character id>/<line>.ogg`. Character ids: `gandalf`, `elon`, `leo`, `vader`.

| Line file | When it plays | How often |
|---|---|---|
| `light` | Light attack | 25% of the time |
| `heavy` | Heavy / smash attack | 70% |
| `special_1`, `special_2`, `special_3`, `special_up` | Each special (see the per-character table) | Always |
| `hurt` | Taking a light hit | 60% |
| `hurt_heavy` | Getting launched | 60% |
| `ko` | Losing a stock | Always |
| `dizzy` | Shield break | Always |
| `victory` | Winning the match | Always |

A fighter's new line cuts off their previous one, and lines from the same fighter are at least 0.45 s apart. Keep lines short: 0.3–1.2 s for attacks, up to 2 s for victory.

**Suggested script.** These are short, shouted call-outs. Record 2–3 variants of the frequent ones (`light`, `heavy`, `hurt`).

| Line | Gandalf (wise old wizard) | Elon (fictional tech brawler) | Vader (dark knight) |
|---|---|---|---|
| `light` | "Hah!" / "Away!" | "Hup!" / "Boom." | (mechanical breath) / "Hm." |
| `heavy` | "Begone!" | "Rocket hammer!" | "Feel my power!" |
| `special_1` | "Lightning!" (side B) | "Thruster burst!" (side B) | "Push!" (side B) |
| `special_2` | "Fireball!" (neutral B) | "Tractor beam!" (neutral B) | (choke) "Hrrk." / "Impressive." (neutral B) |
| `special_3` | "You shall not pass!" (down B) | "Shields up!" (down B) | "Futile." (down B) |
| `special_up` | "Wind, lift me!" | "Liftoff!" | "Rise!" |
| `hurt` / `hurt_heavy` | "Ugh!" / "Nooo—!" | "Ow!" / "Whoa—!" | "Grr!" / (breath) |
| `ko` | (fading cry) | "Not like this!" | (deep groan) |
| `dizzy` | "My head…" | "System error…" | "…" |
| `victory` | "A wizard is never late." | "Nailed the landing." | "The circle is complete." |

Elon is a playful fictional parody. Use an original voice actor or a generic synthetic voice. **Do not clone or imitate any real person's actual voice.** The same applies to any character based on a real or trademarked figure.

## Adding audio for a new character
Create `audio/voice/<new id>/` with the line files above. Their move effect IDs (from `scripts/data/game_ids.gd`) can get `sfx/<effect id>.ogg` files. Nothing else is needed.

### Pope Leo (`audio/voice/leo/`)
| Line | Suggested call-out |
|---|---|
| `light` | "Hah!" / "Peace!" |
| `heavy` | "By the crosier!" |
| `special_2` (neutral B, Holy Tome) | "Read this!" |
| `special_1` (side B, Censer Swing) | "Incense!" |
| `special_3` (down B, Benediction) | "Bless you!" |
| `special_up` (Ascension) | "Rise!" |
| `light_up` / `light_down` / `heavy_up` / `air_forward` / `air_up` | "Hup!" / "Key of Peter!" / "Behold!" / "Ha!" / "Heaven!" |
| `hurt` / `ko` / `dizzy` / `victory` | "Oof!" / (fading cry) / "Mamma mia…" / "Pax vobiscum." |

Directional attacks (`light_up`, `light_down`, `heavy_up`, `air_*`) use their move id as the line name, like specials.
