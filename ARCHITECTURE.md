# Architecture

The widget uses a thin `src/widget.ps1` composition root and responsibility-based modules under `src/modules`.

## Module groups

- `Application`: configuration, startup and lifecycle services.
- `Board`: profiles, geometry, placement, cache, editing and rendering.
- `Calendar`: authorization, synchronization and the complete summons sequence.
- `Core`: shared infrastructure such as the named timer registry.
- `Tasks`: persistence, badges, icon selection, creation and animations.
- `Windows`: reusable controls, settings, task details and window actions.

## Calendar summons sequence

The calendar animation owns four independent timers:

- `Summons.Arrival`
- `Summons.Queue`
- `Summons.Pin`
- `Summons.Departure`

Each stage stops only its own timer. The departure stage removes the resting craw, creates a dedicated flying craw at the same coordinates and removes it after it leaves the board.

## Composition

`src/widget.ps1` loads modules in dependency order, creates the WPF controls and wires UI events. Business rules and reusable actions remain outside the composition root.
