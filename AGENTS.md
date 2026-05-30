# AGENTS.md

Guidance for cloud and automated agents working in this repository.

## Product

**Avalon: Paradise Engine** is a Godot 4 desktop management/simulation prototype. There is no web server, database, or package manager (npm/pip). Development requires the Godot 4.2 engine only.

The playable project lives on branch `cursor/godot-sim-framework-b716` until it is merged to `main`.

## Cursor Cloud specific instructions

### Godot engine

Install once per VM (also handled by the startup update script via `scripts/install-godot.sh`):

```bash
bash scripts/install-godot.sh
export PATH="$HOME/.local/bin:$PATH"
godot --version   # expect 4.2.stable
```

Use **Godot 4.2.x** to match `project.godot` (`config/features=PackedStringArray("4.2")`).

### Running the game

From the repository root on the Godot branch:

```bash
export PATH="$HOME/.local/bin:$PATH"
export DISPLAY=:1   # cloud VM desktop display

# GUI (OpenGL required — Vulkan is unavailable in this VM)
godot --path . --display-driver x11 --rendering-driver opengl3 res://scenes/main.tscn

# Headless smoke check (no display needed)
godot --headless --path . res://scenes/main.tscn --quit-after 1
```

Main scene: `res://scenes/main.tscn` (1280×720 dashboard UI).

### Lint / tests

There is no ESLint, pytest, or CI test suite. Validate changes by:

1. Opening/running the project in Godot 4.2 without GDScript parse errors.
2. Using the dashboard: build a facility, hire staff, assign staff, **Advance Day**, Save/Load.

Audio falls back to the dummy driver in headless/cloud environments; that is expected.

### Branch note

If `main` only contains `README.md`, check out the Godot scaffold branch before running:

```bash
git checkout cursor/godot-sim-framework-b716
```

### Saves

In-game saves write to Godot's user data path (`user://avalon_save.json`), not the repo.
