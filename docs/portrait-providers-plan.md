# Ordered portrait providers implementation plan

User-approved order, per boss: native Forever Encounter Journal API; installed ForeverDungeonJournal; installed AzerothCompendium; skull. Do not replace earlier successes with later providers, do not infer identity from boss order, and do not equate DungeonEncounterID with JournalEncounterID.

1. Add Lua regression cases for native priority, missing individual entries, model failures, optional addons absent, aliases, same-name bosses scoped to instances, secret values, journal tier/instance restoration. Run red.
2. Replace Portraits.lua with native journal enumeration/index by instance and DungeonEncounterID/localized names, plus separate runtime addon adapters. Native Build scans tiers/dungeons/raids once and restores selection; Apply tries each provider's model/texture then skull. Record chosen source on pin for diagnostics. Late addon loads rebuild indexes.
3. Add ForeverDungeonJournal OptionalDeps. Keep maps independent: existing Compendium map images where available, else FDR minimap geometry on exact same floor coordinates for Scholomance/Naxxramas; no global integration abort. No third-party assets copied. Add fallback map rendering test, preserve UV hook fix.
4. Run existing checks plus provider cases against installed journal data. Inspect Hall of Thanes (Infurnus alias) in game. Exercise no-optional-provider and native-API-success paths in isolated Lua without changing enabled addon settings. Native API is present but returns no journal tiers on the tested client. Update README/changelog/version/archive.
