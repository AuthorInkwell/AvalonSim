# Avalon: Paradise Engine

Avalon: Paradise Engine is an early Godot 4 management/simulation prototype about operating a futuristic luxury resort island. The first milestone focuses on a stable economic loop instead of art polish or narrative depth.

## Current Prototype

- Godot 4.x project scaffold with Git-friendly text assets.
- Autoload managers for game state, economy, facilities, staff, reputation, events, save/load, and data catalogs.
- Data-driven facility, staff, event, and guest type definitions in JSON.
- Basic dashboard UI for:
  - advancing one day at a time,
  - viewing funds, demand, staff count, and capacity,
  - building facilities,
  - hiring staff,
  - assigning staff to facilities,
  - tracking reputation,
  - reviewing daily reports and event logs,
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
3. Use the dashboard to build, hire, assign staff, and advance the day.

Saves are written to `user://avalon_save.json`, which keeps local playtest state out of the repository.

## Design Notes

The framework keeps adult themes at the setting and atmosphere level. The implemented mechanics focus on hospitality operations, staffing, finances, reputation, construction, random incidents, and expansion hooks.
