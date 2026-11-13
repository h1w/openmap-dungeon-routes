# OpenMap Dungeon Routes implementation plan

## Goal and approved design

A separate Interface 16001 addon, requiring OpenMap and ForeverDungeonRoutes, renders routes, boss portraits, progress and player location in OpenMap's dungeon view only. No upstream addon files are patched. FDR remains authoritative for routes, localization, completion and room inference. AzerothCompendium is optional, read at runtime for display IDs; none of its code, databases or art is redistributed.

## Constraints

- Lua 5.1, secret-safe game API reads, no protected actions in combat.
- All FDR dungeons/wings, all available built-in and user route variants. Explicit absence when no route exists.
- Exact position only from unsecret numeric API data. Room centroid explicitly approximate, never presented as measured coordinates.
- Map coordinates/floors come from installed FDR. Standard art references OpenMap's MapTile locale fix; custom images reference FDR; Scholomance/Naxxramas use Compendium images when available, otherwise FDR minimap projections. No optional addon is required for startup. No art is redistributed.
- OpenMap private view access isolated in Host.lua and capability checked; fail visibly on incompatible versions.
- No edits to installed upstream addons. Publishing source branches requires user approval; releases and game assets are never uploaded automatically.

## Tasks

1. Workspace and regression scenarios
   - Work in linked worktree feat/dungeon-route-integration.
   - Add uv-managed Lua 5.1 test runner (lupa) with real installed FDR data and pure domain scenarios.
   - Verify missing integration fails; implement afterward.
2. Data.lua and Host.lua
   - Data.BuildFloors(instanceID) builds union of FDR wing floors with original tiles/images, stable FDR floor IDs and OpenMap wing names.
   - Supply these definitions to OpenMap's runtime map catalogue; reload without the integration restores original upstream data.
   - Host detects OpenMapDungeonView, maps view floor to FDR floor and switches floors using OpenMap's existing next-button handler, not copied frame layout logic.
   - Image floors draw referenced textures with original crop; standard floors use OpenMap's bundled local tiles. Map switches hide all overlays.
3. Render.lua and Core.lua
   - Pooled lines, gradient main paths, dashed branches, direction arrows, route stop/note/link pins.
   - Route selector enumerates DR:GetRoutes(key); selection uses DR:SetActiveRoute and progress stays in FDR.
   - Stop click uses FDR completion; all available routes, progress events and floor changes redraw.
4. Location.lua and Portraits.lua
   - Exact self marker uses DR:LocatePlayer and facing. Room polygon overlay and explicitly approximate name marker when exact unavailable; group labels from FDR room exchange.
   - Portrait lookup order per boss: native Forever API, installed DungeonJournal, installed Compendium, neutral game skull. Runtime addon data only.
   - Controls: show/hide routes, follow room/floor, route choice, position diagnostics and dungeon browser.
5. Verification and delivery
   - Run deterministic real-data regression scenarios and Lua syntax checks once after integration; fix any failures.
   - Review changes; package own addon, README installation/limitations, MIT license and FDR attribution.
   - Request permission for game-folder installation and short reload/UI verification; no character movement or chat messages to other players. Actual dungeon position requires user already inside a dungeon.
