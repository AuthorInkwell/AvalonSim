# AGENTS.md

Guidance for cloud and automated agents working in this repository.

## Product

**Avalon: Paradise Engine** is a Godot 4 desktop city-building and management simulation prototype. There is no web server, database, or package manager (npm/pip). Development requires the Godot 4.2 engine only.

The playable project is on `main`. Create normal task branches from the latest `main`; the former scaffold branch is obsolete.

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

Main scene: `res://scenes/main.tscn` (1280×720 city-builder UI).

### Web export and hosted playtest

Install the official Godot 4.2 Web templates and build the static package with:

```bash
bash scripts/install-godot-export-templates.sh
bash scripts/export-web.sh
```

The output under `build/web/` includes an isolation service worker required by Godot 4.2. Test the package through HTTP/HTTPS, not `file://`.

`.github/workflows/deploy-web-playtest.yml` builds and deploys `main` to GitHub Pages. Pages must use **GitHub Actions** as its publishing source. Do not commit generated `build/` output; the workflow uploads it as a Pages artifact.

### Lint / tests

There is no ESLint or pytest suite. Validate changes by:

1. Opening/running the project in Godot 4.2 without GDScript parse errors.
2. Running the Godot checks:

```bash
godot --headless --path . res://tests/map_system_test.tscn
godot --headless --path . res://tests/structure_catalog_test.tscn
```

3. Using the city-builder UI: place roads and a facility, hire and assign staff, **Advance Day**, use the minimap, and Save/Load.

Audio falls back to the dummy driver in headless/cloud environments; that is expected.

### Saves

In-game saves write to Godot's user data path (`user://avalon_save.json`), not the repo.
