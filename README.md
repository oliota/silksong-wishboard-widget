# Desktop Wish Board Widget

A lightweight Windows 11 desktop widget that turns everyday tasks into a visual wish board inspired by *Hollow Knight: Silksong*.

## Origin

I am a software developer, programming teacher, technology enthusiast, maker, and someone who enjoys turning ideas from games into physical and digital projects.

While playing *Silksong*, I liked the idea of the wish boards found throughout the game: instead of treating objectives as a conventional checklist, wishes are represented as things placed on a physical board.

That led to this project.

The goal was to gamify my own tasks by transforming the Windows desktop into a personal wish board. Tasks are represented by visual icons placed directly over a themed background. They can be moved, inspected, edited, completed externally, reorganized, or deleted while the widget remains available on the desktop without replacing the normal Windows desktop.

The project gradually evolved from a simple HTML wallpaper experiment into a configurable PowerShell/WPF desktop application with persistent positioning, custom backgrounds, editable task areas, task collision handling, icon management, transparency controls, and a system tray mode.

---

## Requirements

- Windows 11
- Windows PowerShell 5.1
- No third-party application installation required

The widget uses native Windows technologies:

- PowerShell
- WPF
- Windows Forms components where required
- JSON configuration files
- PNG/ICO assets

---

## Starting the Widget

The project root intentionally contains only one file:

`Desktop Wish Board.vbs`

Double-click it to start the widget visually.

All implementation files, configuration, documentation and assets are stored inside `src/`.

This keeps the project root clean and makes normal use straightforward: open the project folder and double-click the VBS launcher.

---

## Main Widget

The main window is the visual wish board.

It contains:

- background image;
- task icons;
- permitted task area;
- Add Task button;
- transparency control;
- Edit Mode button;
- resize control;
- minimize button;
- close button.

The widget itself can be moved around the desktop.

Its size and position are persisted.

### Moving the Widget

Click and hold an unused part of the widget and drag it to another position on the desktop.

Task icons and interactive controls have their own behaviors and do not intentionally initiate widget movement.

### Resizing the Widget

Use the resize control in the main toolbar.

The background and internal design scale with the widget.

The selected size is persisted and restored on the next launch.

---

## Transparency

The transparency slider controls the opacity of the entire widget.

This is useful when the wish board needs to remain visible over other desktop content without becoming distracting.

The minimum opacity is intentionally limited so the widget never becomes effectively invisible.

The selected opacity is persisted.

---

## Tasks / Wishes

Each task represents a wish on the board.

A task contains:

- icon;
- title;
- description;
- position.

Only the icon is permanently visible on the board.

The title appears as a tooltip when the mouse is placed over the task.

### Opening a Task

Click a task without dragging it.

The detail window opens separately and shows:

- icon;
- title;
- description;
- Edit control;
- Delete control;
- resize control;
- close control.

### Moving a Task

Click and drag the task.

Tasks must remain inside the permitted area.

The complete task icon is kept inside the boundary rather than validating only its center.

Tasks also cannot overlap each other.

A small collision margin keeps neighboring tasks visually separated.

When a dragged task reaches another task, the movement system attempts to slide around it instead of allowing the two tasks to occupy the same space.

Task positions are persisted after dragging.

---

## Adding a Task

Use the `+` button on the main widget.

The Add Task interface allows you to define:

- icon;
- title;
- description.

### Choosing an Icon

Select one of the available icons from the icon grid.

The grid layout can be configured from Edit Mode.

After creating the task, the widget searches for an available position inside the permitted area while avoiding existing tasks.

---

## Task Detail Window

Clicking a task opens its detail window.

In normal mode, the content is read-only.

### Editing a Task

Click the Edit icon.

The detail switches to editing mode.

You can change:

- icon;
- title;
- description.

The Edit button becomes a Save button.

Click Save to persist the changes.

### Canceling an Edit

Use Cancel while editing.

The window returns to read mode without applying the pending changes.

### Deleting a Task

In read mode, use the trash button.

The task is removed from the board and from persistent task storage.

### Resizing the Detail Window

Use its own resize control.

The detail window resize behavior is independent from the main widget resize behavior.

Its dimensions are persisted.

---

## Widget Edit Mode

Edit Mode configures the board itself rather than individual tasks.

Use the Edit button in the main toolbar.

While Edit Mode is active, task dragging is disabled so board configuration can be changed safely.

The editor provides controls for:

- permitted area;
- polygon nodes;
- background;
- background placement and size;
- Add Task button placement and size;
- icon grid configuration;
- boundary visibility.

Use Done to apply the edited board configuration.

Use Cancel to discard the current editing session.

---

## Permitted Task Area

The permitted area defines exactly where tasks are allowed to exist.

It is represented by a polygon instead of being limited to a rectangle, circle, or ellipse.

This allows the usable region to follow the actual visual shape of the selected wish-board artwork.

### Editing Nodes

In Edit Mode, each numbered point represents a polygon node.

Drag a node to reshape the permitted area.

The polygon updates visually as the nodes move.

### Adding Nodes

Each existing node has small `+` controls.

Hovering over one displays a red preview showing where the new node will be inserted.

The two controls around a node are assigned to different neighboring polygon segments so they do not produce the same insertion point.

Click the appropriate `+` to create the previewed node.

### Undo

Undo restores previous changes made during the current editing session.

The editor maintains temporary history while Edit Mode is active.

### Clear

Clear restores the default polygon definition.

The default area uses a predefined multi-node circular shape.

### Boundary Line

The editor always displays the polygon while editing.

The Line setting controls whether that boundary remains visible after leaving Edit Mode.

The editing color indicates the selected behavior:

- green: boundary remains visible;
- red: boundary is hidden in normal mode.

The permitted area continues to work even when its line is hidden.

---


### Default Area

The geometry currently stored in `default-area.json` is the official default permitted area for the protected `default` background.

Using `Clear` in Widget Edit Mode restores both the default background and this exact predefined area, including its node count and node positions.

`area.json` remains the user's current working area, while `default-area.json` is the immutable reset reference shipped with the project.

---

## Backgrounds

The board background is independent from the polygon that defines the permitted task area.

A background can therefore be rectangular or any normal PNG image while the usable task region follows a completely different shape.

### Choosing a Background

Enter Edit Mode and open the background selector.

Existing backgrounds are displayed as options.

Selecting one immediately closes the selector and uses that background for the editing session.

### Adding a Background

Choose:

`Browse in PC...`

Select a PNG file and give it a name.

The image is copied into the project and becomes a reusable background option.

### Removing a Background

User-added backgrounds can be removed from the background list.

Removing one also removes its stored project asset.

The default background cannot be deleted.

### Adjusting the Background

While in Edit Mode, the background can be repositioned and resized independently so the artwork can be aligned with the widget and permitted task area.

---

## Add Task Button Configuration

The `+` button can be repositioned while editing the widget.

It must remain outside the permitted task area so it cannot be confused with a task placed on the wish board.

A size slider controls its dimensions.

The slider follows the button while it is repositioned.

Its position and size are persisted.

---

## Icon Grid

The icon selector uses a configurable grid.

In Edit Mode, open the Grid configuration and choose the number of icons displayed per row.

The preview updates to show the resulting layout.

The same grid configuration is used when:

- creating a task;
- changing the icon of an existing task.

---

## System Tray

Minimizing the widget hides the main window and keeps the application available from the Windows notification area.

The tray icon provides quick access without leaving a terminal window visible.

### Left Click

A normal left click restores the widget.

### Right Click

Right click opens the tray context menu with additional actions.

---

## Persistence

The widget stores its state locally in the project.

Persistent information includes, depending on the feature:

- widget size;
- widget position;
- opacity;
- selected background;
- background transformation;
- permitted-area polygon;
- boundary visibility;
- task positions;
- task titles;
- task descriptions;
- task icons;
- Add Task button position;
- Add Task button size;
- icon-grid configuration;
- detail-window dimensions.

Configuration is reloaded periodically where appropriate and restored when the widget starts again.

---

## Project Structure

```text
Desktop_Wish_Board_1.0.0/
├── Desktop Wish Board.vbs
└── src/
    ├── widget.ps1
    ├── package.json
    ├── README.md
    ├── config.json
    ├── area.json
    ├── tasks.json
    ├── icons.json
    ├── backgrounds.json
    ├── background.png
    ├── item-background.png
    ├── icons/
    └── backgrounds/
```

### Project root

Contains only `Desktop Wish Board.vbs`, the visual double-click entry point.

### `src/widget.ps1`

Main PowerShell/WPF application.

### `src/config.json`

General widget configuration.

### `src/area.json`

Permitted-area polygon and related area configuration.

### `src/tasks.json`

Task data, including positions and details.

### `src/icons.json`

Available task icon catalog.

### `src/backgrounds.json`

Available background definitions.

### `src/icons/`

Task icon assets.

### `src/backgrounds/`

Stored background assets.

---

## Configuration Philosophy

The project intentionally separates different responsibilities:

- widget configuration controls the application;
- area configuration controls where wishes can exist;
- task storage controls individual wishes;
- icon configuration controls visual choices;
- background configuration controls board artwork.

This separation makes it possible to change the appearance of the board without rewriting tasks and to reshape the usable area without modifying the background image itself.

---

## Current Concept

The widget is effectively a personal desktop quest board.

Instead of:

> Open a task manager → inspect a list → find a task.

The interaction becomes:

> Look at the board → recognize the wish visually → interact with it.

The objective is not to replace a full project-management application. It is to make personal tasks more visible, spatial, playful, and connected to the visual language that inspired the project.

---

## Planned Direction

A future version can associate predefined backgrounds with predefined polygon layouts.

That will allow official/project-provided boards to automatically load:

- the correct number of nodes;
- exact node positions;
- the correct permitted area.

Predefined backgrounds will be protected from deletion.

User-imported backgrounds will continue to support manual naming, deletion, and custom area editing.

---

## Version

Current stable release: `1.0.0`

Version 1.0.0 is the first release considered ready for practical daily use.


## Multi-monitor behavior

The widget validates its saved position against the monitors currently connected to Windows. If a monitor is disconnected, the primary monitor changes, or the desktop layout changes, an off-screen widget is moved automatically to a visible working area while preserving its approximate relative position. Normal positions remain unchanged when they are still accessible. Display changes are detected while the widget is running and also validated when it starts or is restored from the tray.
