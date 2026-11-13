# Changelog

## 0.1.2 — 2026-11-13

- Boss portrait sources are tried per boss: native Forever API, optional DungeonJournal, optional AzerothCompendium, then skull.
- Native journal IDs are discovered independently of combat encounter IDs; journal selection is restored after scanning.
- DungeonJournal aliases/custom icons resolve renamed bosses such as Infurnus/Magmatus without positional guessing.
- Neither optional addon is required to start. Scholomance and Naxxramas use FDR minimap projections when Compendium images are unavailable.
- Fixed duplicate native OpenMap skull markers appearing while holding left mouse to pan: suppression now runs after each native layout frame, including newly pooled pins.

## 0.1.1 — 2026-11-13

- Fixed custom map flicker/repeated tiles during left-button dragging and zoom: image UV crops are restored synchronously when OpenMap lays out tiles, including floor thumbnails.
- Added a temporary Bosses toggle. Boss pins reset to visible on reopen or a different dungeon; floor/zoom changes preserve the current choice. Route visibility remains persistent.

## 0.1.0 — 2026-11-13

- FDR routes, branches, direction arrows, notes and floor links inside OpenMap dungeon views.
- All available FDR route variants and user routes selectable without copying route data.
- Runtime Compendium boss portraits and FDR completion state; click and Alt-click actions.
- Exact self position when the client provides coordinates; otherwise explicitly approximate room marker and room area.
- FDR group room labels, follow-floor mode and `/omdr pos` diagnostics.
- OpenMap's bundled locale texture fix retained; custom FDR maps and Compendium Scholomance/Naxxramas images referenced in place.
- Dungeon browser supports instances with no OpenMap entrance, including Naxxramas.

No upstream addon files or third-party art/databases are redistributed. Actual movement/location inside an instance remains an in-game acceptance check.
