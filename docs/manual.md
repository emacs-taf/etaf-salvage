# Salvage Station

Salvage Station is a standalone GameKit application with a headless Godot
simulation and a native ETAF interface. The application owns its rules, theme,
components and launch command; it uses only public GameKit, ETAF and catalog
APIs.

Install GameKit, ETAF, etaf-ui and GameKit's Godot runtime, then add the
application directory to `load-path`:

```elisp
(add-to-list 'load-path "/path/to/emacs-taf/etaf-salvage")
(require 'etaf-salvage)
(etaf-salvage-open)
```

`etaf-salvage-game` is a game definition. `etaf-salvage-open` starts an independent
instance, displays its buffer and fits the view to its window. Its Godot project lives in `native/godot/` and is resolved relative to this
application's own entry file, independently of GameKit's checkout. The application's
[entry Commentary](../etaf-salvage.el) describes its public API.

Recover three power cores from the station and return to the extraction dock.
The game starts in tactical pause. Godot owns movement, collision, pathfinding,
drones, energy, damage, score and victory/defeat. ETAF owns selection, tabs,
dialogs and all presentation.

| Input | Action |
| --- | --- |
| P / Launch / Pause | Start or pause simulation |
| W A S D | Extend the navigation destination by one cardinal tile |
| Click deck | Plot a route around bulkheads |
| Click an object | Inspect it; use Plot route to target to navigate there |
| 1 / EMP | Disable drones within five tiles; costs 20 energy, four-second cooldown |
| 2 / Shield | Protect the hull for five seconds; costs 25 energy |
| Cargo → Repair | Use one of two kits to restore up to 40 hull |
| ? / F1 / Help | Open searchable controls and flight notes in the current buffer |
| T / Light–Dark | Switch between the light daylight and dark deep-space palettes |
| Save / Load | Choose an explicit local snapshot path |

Help is a read-only modal in the expedition buffer; it neither splits the
window nor opens a second application. It shows the effective bindings and
flight notes, with two columns in wide windows and a scrolling column in narrow
ones. `/` starts search; Escape first leaves search editing, then closes help.
Clicking the shade also closes it and restores focus without activating the
covered game. Opening or closing help does not pause or resume the simulation:
use tactical pause before reading when needed. The compact **Panels** dialog
also closes when its shade is clicked.

`etaf-salvage-appearance` selects the initial palette: `auto` (the default)
follows the frame's background mode, or set `light`/`dark` before calling
`etaf-salvage-open`. Switching the palette at runtime repaints the interface
and never restarts or reconnects the Godot simulation.

Loading validates a snapshot before changing the world, resumes paused and
clears navigation routes. Snapshots retain position, cargo, enemies, resources,
cooldowns, score, elapsed time and events. Closing makes no implicit save.

The expedition interface is horizontally centered and sits slightly above the
vertical center, sharing surplus height 2:3 above and below. Short windows
remove this outer space before clipping; panels do not stretch to fill it.

The map stays 32×18 cells, each two character columns by one text row. Resizing
reflows surrounding panels without stretching the world. Narrow tall windows
put panels below the map; narrow short windows expose them through **Panels**.
The minimum canvas is 76 character columns by 30 rows. Smaller windows clip or
scroll that canvas with soft wrapping disabled.

For GUI acceptance, load ETAF's `scripts/emacs-gui-verifier.el` and this application's
`scripts/etaf-salvage-gui-scenarios.el` into a dedicated graphical Emacs using
these checkouts. Schedule `etaf-salvage-gui-run` with a fresh evidence directory.
It checks the complete expedition, native keys, fixed map dimensions, panels,
width/height adaptation and restart, then restores frame geometry. Inspect its
screenshots; functional assertions alone do not certify appearance.

