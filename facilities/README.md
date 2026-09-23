# Structure definitions

Structures are data-driven entries in `data/facilities.json`. `DataCatalog` resolves their abstract balance tiers through `data/balance_tiers.json`; simulation code consumes the resulting numeric values.

## Common fields

- `id`, `name`, `category`, and `description`
- `<property>_tier` for build cost, maintenance, capacity, fee, comfort, pleasure, safety, power use/production, energy storage, and waste production/removal
- `staffing` for provisional required staffing and optional category/house preferences or requirements
- `work_modes` and `default_work_mode` for player-selectable operating modes
- `modifiers` for conditional effects, penalties, and hooks into systems that do not exist yet

Properties that do not apply may be omitted. Tier ranges such as `low_to_medium` are averaged by the catalog and remain easy to rebalance centrally.

The Medical Center is present as an incomplete, non-buildable definition because the source specification names and describes it but does not provide its gameplay properties. Research & Development has no entries because the specification does not define any.
