local _, NS = ...
local Host = {}
NS.Host = Host
local PATH = "Interface\\AddOns\\ForeverDungeonRoutes\\"

function Host.Install(dr, om)
	if not om.GetModule or not om.MapDungeonMaps or not om.MapStitch or not om.Media then return false end
	Host.dr, Host.om = dr, om
	local catalog = {}
	local ids = {}
	for _, dungeon in ipairs(dr.Dungeons) do ids[dungeon.instanceID] = true end
	for id in pairs(ids) do
		catalog[id] = NS.Data.BuildFloors(dr, id)
		local provider = NS.Portraits.provider
		for _, floor in ipairs(catalog[id]) do
			local external = floor.fdrFloor == 306 or floor.fdrFloor == 307 or floor.fdrFloor == 308
				or floor.fdrFloor == 309 or id == 533
			if not floor.image and external and provider then
				for _, maps in pairs(provider.INSTANCEMAPS or {}) do
					for _, art in ipairs(maps) do
						if art.id == floor.fdrFloor then
							floor.image = { path = art.file, right = art.width / art.fileWidth, bottom = art.height / art.fileHeight }
						end
					end
				end
			elseif not floor.image and not external then
				local tiles = {}
				for tile, fid in ipairs(floor.tiles or {}) do tiles[tile] = om.Media.tex .. "MapTile\\" .. fid end
				floor.tiles = tiles
			end
			if floor.image then
				local texture = floor.image.path or PATH .. floor.image.file
				floor.tiles = {}
				for tile = 1, 12 do floor.tiles[tile] = texture end
			end
			if external and not floor.image then
				floor.minimap = dr.MinimapArt and dr.MinimapArt[floor.fdrFloor]
				if floor.minimap then floor.tiles = nil end
			end
		end
	end
	for id, floors in pairs(catalog) do om.MapDungeonMaps[id] = floors end
	-- These would win over our floor catalogue and use incompatible route coordinates.
	Host.minimaps = om.MapDungeonMinimap
	om.MapDungeonMinimap = {}
	return true
end

function Host.View()
	local view = _G.OpenMapDungeonView
	if not view or not view:IsShown() then return end
	if not view.page or not view.port or not view.inst or not view.floors or not view.next then return end
	local floor = view.floors[view.floor or 1]
	if not floor or not floor.fdrFloor then return end
	return view, floor
end

function Host.SelectFloor(id)
	local view = Host.View()
	if not view then return false end
	for i, f in ipairs(view.floors) do
		if f.fdrFloor == id then
			if i == view.floor then return true end
			-- Keep OpenMap's own layout, sounds, side panel and floor highlighting.
			view.floor = i - 1
			Host.selecting = true
			view.next:GetScript("OnClick")(view.next)
			Host.selecting = false
			return true
		end
	end
	return false
end

-- OpenMap resets tile UVs on every drag/zoom layout. Repair in the same setter
-- call, before rendering, rather than racing its OnUpdate from a periodic tick.
local function WatchCrop(tile, view, index, thumbnail)
	if tile.omdrCropHook then return end
	tile.omdrCropHook = true
	local correcting = false
	hooksecurefunc(tile, "SetTexCoord", function(self)
		if correcting then return end
		local floorIndex = thumbnail and thumbnail.item and thumbnail.item.floor or view.floor
		local def = view.floors and view.floors[floorIndex]
		if not def or not def.image then return end
		local l, t, r, b = NS.Data.ImageCrop(def.image, index)
		correcting = true
		self:SetTexCoord(l, r, t, b)
		correcting = false
	end)
end

-- FDR already projects minimap parts into its 1002x668 route coordinate
-- system; use that exact projection when no optional map art is installed.
local function PaintMinimap(page, def)
	local pool = page.omdrMinimap or {}
	page.omdrMinimap = pool
	local width, height = page:GetSize()
	local parts = def and def.minimap or {}
	for i, part in ipairs(parts) do
		local tile = pool[i]
		if not tile then tile = page:CreateTexture(nil, "ARTWORK") pool[i] = tile end
		tile:SetTexture(part[1], "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE", "TRILINEAR")
		tile:SetTexCoord(part[6], part[7], part[8], part[9], part[10], part[11], part[12], part[13])
		tile:SetDrawLayer("ARTWORK", part[14])
		tile:SetSize(part[4] / 1002 * width, part[5] / 668 * height)
		tile:ClearAllPoints()
		tile:SetPoint("TOPLEFT", page, "TOPLEFT", part[2] / 1002 * width, -part[3] / 668 * height)
		tile:Show()
	end
	for i = #parts + 1, #pool do pool[i]:Hide() end
end

local function HideNativePins(view)
	for _, pin in ipairs(view.bossPins or {}) do pin:Hide() end
end

function Host.Paint(view, floor)
	if not view.omdrPinHook and view.HookScript then
		view.omdrPinHook = true
		-- Runs after OpenMap's drag layout, including pins created in that frame.
		view:HookScript("OnUpdate", HideNativePins)
	end
	local function crop(tiles, def, thumbnail)
		if not def.image then return end
		for i, tile in ipairs(tiles) do
			WatchCrop(tile, view, i, thumbnail)
			local texture = def.image.path or PATH .. def.image.file
			if tile:GetTexture() ~= texture then tile:SetTexture(texture, nil, nil, "TRILINEAR") end
			local l, t, r, b = NS.Data.ImageCrop(def.image, i)
			tile:SetTexCoord(l, r, t, b)
			tile:Show()
		end
	end
	crop(view.tiles, floor)
	PaintMinimap(view.page, floor)
	if floor.minimap then for _, tile in ipairs(view.tiles) do tile:Hide() end end
	for _, thumb in ipairs(view.side and view.side.pool.thumb or {}) do
		if thumb:IsShown() and thumb.item then
			local def = view.floors[thumb.item.floor]
			crop(thumb.tiles, def, thumb)
			PaintMinimap(thumb, def)
			if def.minimap then for _, tile in ipairs(thumb.tiles) do tile:Hide() end end
		end
	end
	-- Stock pins refer to different floors/art and must not duplicate route stops.
	HideNativePins(view)
end

function Host.Open(key)
	if InCombatLockdown() then NS.Print(NS.T("combat")) return end
	local dungeon = Host.dr:GetDungeon(key)
	if not dungeon then return end
	ShowUIPanel(WorldMapFrame)
	local stitch = Host.om.MapStitch
	local pins = stitch.PinSet("dungeons").pins
	local chosen
	for _, pin in ipairs(pins) do
		if pin.OnClick and not chosen then chosen = pin end
		for _, inst in ipairs(pin.instances or {}) do
			if inst[1] == dungeon.instanceID and pin.OnClick then chosen = pin break end
		end
		if chosen == pin then
			local match = false
			for _, inst in ipairs(pin.instances or {}) do if inst[1] == dungeon.instanceID then match = true end end
			if match then break end
		end
	end
	if chosen then
		-- OpenMap exposes no OpenDungeon API. Borrow only the synchronous click handler;
		-- never borrow another dungeon's entrance coordinates for the requested map.
		local proxy = { instances = { { dungeon.instanceID, dungeon.name:gsub(": ", " - "), dungeon.raid or false,
			dungeon.levels[1], dungeon.levels[2] } } }
		chosen.OnClick(proxy)
		Host.SelectFloor(dungeon.floors[1])
		return true
	end
	NS.Print(NS.T("entrance"))
	return false
end
