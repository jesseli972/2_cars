# 2 Cars

A mobile-first take on the classic 2 Cars game, tuned for fast, responsive lane switching.

**Play:** https://jesseli972.github.io/2_cars/

## How to play

Tap the left half of the screen to move the red car and the right half to move the blue car.

- **Hard:** catch every circle and dodge every square. Missing a circle ends the run.
- **Easy:** squares only. You score a point for each one you dodge.

The game speeds up and spawns obstacles closer together as your score climbs. You can feel the speed through streaking speed lines and a road that warms in colour. Dodging a square at the last moment flashes a **Close!** near-miss.

## Music

Each theme has its own original synthwave loop, generated in code with the Web Audio API, so there are no audio files and no licensing to worry about. The menu plays a soft pad and arpeggio. A run adds bass and drums, the hi-hats double up past mid-speed, and the tempo climbs with the game. Music can be turned off on the menu, separately from sound effects. On iPhone, music plays even with the silent switch on while Music is enabled.

## Themes

Themes unlock from your best score in either mode and can be picked on the menu:

| Theme | Unlocks at |
|---|---|
| Night City | Start |
| Ausar #9 | Start (hardwood court, #9 jersey cars, basketballs, arena beat) |
| Synthwave | 50 |
| Snow | 100 |
| Deep Space | 200 |

On a computer: `F` / `←` moves the left car, `J` / `→` moves the right car, and `Space` pauses.

## Lane switching

A lane switch starts on touch-down, not on release. It uses a short ease-out, so most of the movement happens in the first few frames. Tapping again mid-switch reverses the car right away from wherever it is. You can pick the switch speed in the menu: Instant 45 ms, Snappy 85 ms (default), Smooth 140 ms or Classic 230 ms.

## Install on your phone

Open the Play link, then:

- **iPhone (Safari):** Share → Add to Home Screen
- **Android (Chrome):** ⋮ → Add to Home screen / Install app

It runs full screen and works offline after the first load.

## Files

| File | Purpose |
|---|---|
| `index.html` | The whole game: canvas rendering, input, settings |
| `manifest.webmanifest` | App name, icon and full-screen display for installs |
| `sw.js` | Service worker that caches the game for offline play |
| `icon-*.png` | Home-screen icons |

The game has no build step and no dependencies.
