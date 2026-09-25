# Avalon: Paradise Engine

Avalon: Paradise Engine is an early Godot 4 city-builder and management simulation about operating a futuristic luxury resort island. The current milestone wraps the established economic loop in a spatial, turn-based island interface.

## Current Prototype

- Godot 4.x project scaffold with Git-friendly text assets.
- Autoload managers for game state, economy, facilities, staff, reputation, events, save/load, and data catalogs.
- Data-driven facility, staff, event, and guest type definitions in JSON.
- A flat 48×32 island map with coastline, an unbuildable mountain area, and quick navigation through a minimap.
- Data-derived, rotatable multi-tile building footprints plus placeable roads and road-access checks.
- An early-city-builder dashboard UI for:
  - advancing one day at a time,
  - viewing funds, category demand, satisfaction, staff count, and capacity,
  - placing facilities and roads on buildable terrain,
  - hiring staff,
  - assigning staff to facilities,
  - reviewing detailed budgets and a concise morning briefing,
  - saving/loading a local JSON save.

## Project Layout

```text
/art              Placeholder icon and future visual assets
/characters       Future character resources and scene assets
/data             JSON definitions for simulation content
/events           Future event scenes/resources
/facilities       Future facility scenes/resources
/scenes           Main Godot scenes
/scripts          Scene scripts
/systems          Singleton/autoload gameplay managers
/ui               UI scenes and scripts
```

## Running

1. Open the repository folder in Godot 4.x.
2. Run the main scene (`res://scenes/main.tscn`).
3. Use the dashboard to place buildings and roads, hire and assign staff, and advance the day.

Facilities remain in the existing authoritative simulation managers. The map stores their position, orientation, footprint, construction state, and road access; it does not replace the economic, staffing, reputation, or event systems.

## Web build

Godot 4.2 export templates are required to produce a browser build. With those installed, run:

```bash
scripts/export-web.sh
```

The build is written to `build/web/`. Serve that directory over HTTP or HTTPS rather than opening `index.html` directly. The export includes a small service worker that enables the cross-origin isolation required by Godot 4.2 on ordinary static hosts; the first visit reloads once while that worker activates.

### Hosted playtest

`.github/workflows/deploy-web-playtest.yml` builds and publishes the latest `main` branch to GitHub Pages after every push. It can also be run manually from the repository's Actions tab.

Repository Pages must be enabled once under **Settings → Pages → Build and deployment → Source: GitHub Actions**. After the first successful deployment, the playtest is available at:

<https://authorinkwell.github.io/AvalonSim/>

The site works in an ordinary current browser without Godot, Python, extensions, or relaxed browser security settings.

Saves are written to `user://avalon_save.json`, which keeps local playtest state out of the repository.

## Design Notes

The framework keeps adult themes at the setting and atmosphere level. The implemented mechanics focus on hospitality operations, staffing, finances, reputation, construction, random incidents, and expansion hooks.
