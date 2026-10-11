# Salvage Station

A real-time exploration and extraction game with a native ETAF interface and a
headless Godot simulation. Recover three power cores and return to the dock;
avoid or disable security drones, manage hull and energy, and use repair kits.

This is an independent application. Its rules, Godot project, theme, interface,
tests and workloads live here. GameKit supplies only the shared game instance
and backend connection; it does not contain or launch Salvage Station.

## Install and play

Requires Emacs 29.1+, GameKit, ETAF and etaf-ui on `load-path`, and GameKit's
Godot runtime installed. Add this repository root to `load-path`:

```elisp
(require 'etaf-salvage)
(etaf-salvage-open)
```

The game starts paused. `P` launches/pauses, `W A S D` steer, `1` fires an EMP
and `2` activates a shield. Press `T` or the Light/Dark control to switch
between the light daylight and dark deep-space palettes. Light and dark are
both supported appearances; the expedition keeps running across a switch.
Select objects for information and routes, or use the map to choose a
destination. Save and load explicit local snapshots.

The [manual](docs/manual.md) describes gameplay, window adaptation and recovery.
The [entry Commentary](etaf-salvage.el) owns the public API. `make check` runs
compilation, API and real-backend behavior checks. GUI scenarios and interaction
latency measurements are separate acceptance surfaces.
