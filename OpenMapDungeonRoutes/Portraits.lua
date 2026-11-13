local _, NS = ...
local Portraits = {}
NS.Portraits = Portraits

local function value(v)
	if issecretvalue and issecretvalue(v) then return end
	if type(v) == "table" then return end
	return v
end
local function number(v)
	v = value(v)
	return type(v) == "number" and v > 0 and v or nil
end
local function plain(name)
	name = value(name)
	return type(name) == "string" and name:lower():gsub("^the ", ""):gsub("[%s%p]", "") or ""
end
local function call(fn, ...)
	if type(fn) ~= "function" then return end
	local ok, result = pcall(fn, ...)
	if ok then return value(result) end
end
local function add(index, name, record)
	local key = plain(name)
	if key ~= "" then index[key] = record end
end

-- JournalEncounterID and DungeonEncounterID are different. Discover their
-- relationship from the native journal, never pass a route's ID as a journal ID.
local function native(dr)
	local maps, seen = {}, {}
	if not EJ_GetInstanceByIndex or not EJ_SelectInstance or not EJ_GetEncounterInfoByIndex or not EJ_GetCreatureInfo then return maps end
	local oldTier = number(call(EJ_GetCurrentTier))
	local oldInstance = number(call(EJ_GetCurrentInstance))
	local tiers = number(call(EJ_GetNumTiers)) or 1
	local function scan()
		for tier = 1, tiers do
			if EJ_SelectTier then pcall(EJ_SelectTier, tier) end
			for _, raid in ipairs({ false, true }) do
				for i = 1, 200 do
					local ok, id, name, _, _, _, _, _, _, _, _, mapID = pcall(EJ_GetInstanceByIndex, i, raid)
					id, mapID = number(id), number(mapID)
					if not ok or not id then break end
					if not seen[id] then
						seen[id] = true
						local keys = {}
						for _, dungeon in ipairs(dr.Dungeons) do
							if (mapID and dungeon.instanceID == mapID) or (not mapID and plain(dungeon.name) == plain(name)) then
								keys[#keys + 1] = dungeon.key
								maps[dungeon.key] = maps[dungeon.key] or { names = {}, ids = {} }
							end
						end
						if #keys > 0 and pcall(EJ_SelectInstance, id) then
							for e = 1, 100 do
								local good, encounterName, _, encounterID, _, _, _, combatID = pcall(EJ_GetEncounterInfoByIndex, e, id)
								encounterID, combatID = number(encounterID), number(combatID)
								if not good or not encounterID then break end
								for c = 1, 9 do
									local valid, creatureID, creatureName, _, model, icon = pcall(EJ_GetCreatureInfo, c, encounterID)
									if not valid or not number(creatureID) then break end
									model, icon = number(model), number(icon)
									if model or icon then
										local record = { model = model, icon = icon }
										for _, key in ipairs(keys) do
											local index = maps[key]
											add(index.names, creatureName, record)
											if c == 1 then
												add(index.names, encounterName, record)
												if combatID then index.ids[combatID] = record end
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
	local ok, err = pcall(scan)
	if oldTier and EJ_SelectTier then pcall(EJ_SelectTier, oldTier) end
	if oldInstance then pcall(EJ_SelectInstance, oldInstance) end
	if not ok and geterrorhandler then geterrorhandler()(err) end
	return maps
end

-- Optional addon data stays in its installed addon; nothing is redistributed.
function Portraits.Build(dr)
	local compendium = _G.AzerothCompendium
	if not compendium then
		local registry = _G.D4SharedSettingsRegistry
		for _, entry in ipairs(registry and registry.entries or {}) do
			local owner = entry.owner
			if type(owner) == "table" and owner.INSTANCES and owner.MapPins and owner.GetAddonMeta
				and plain(owner:GetAddonMeta("Title")):find("azerothcompendium", 1, true) then compendium = owner break end
		end
	end
	Portraits.provider = compendium
	Portraits.native = native(dr)
	Portraits.journal, Portraits.compendium = {}, {}
	local journal = _G.ForeverDungeonJournal_NS
	for _, dungeon in ipairs(dr.Dungeons) do
		local records = {}
		Portraits.journal[dungeon.key] = records
		for name, instance in pairs(journal and journal.DB or {}) do
			local mapped = journal.INSTANCE_ID_TO_DUNGEON and journal.INSTANCE_ID_TO_DUNGEON[dungeon.instanceID]
			local same = plain(name) == plain(dungeon.name) or (mapped and plain(name) == plain(mapped))
			local split = type(name) == "string" and name:match("^(.-):")
			if same or (split and plain(split) == plain(dungeon.name)) then
				for _, boss in ipairs(instance.bosses or {}) do
					local npc = boss.portraitNpcID or boss.npcID
					local icon = value(boss.customIcon)
					local model = not icon and (number(boss.displayID) or number(journal.STATIC_DISPLAY_IDS and journal.STATIC_DISPLAY_IDS[npc])) or nil
					local record = { model = model, icon = icon }
					add(records, boss.name, record)
					for _, alias in ipairs(boss.aliases or {}) do add(records, alias, record) end
				end
			end
		end
		local models = {}
		Portraits.compendium[dungeon.key] = models
		for _, inst in ipairs(compendium and compendium.INSTANCES or {}) do
			if plain(inst.name) == plain(dungeon.name) then
				for _, boss in ipairs(inst.bosses or {}) do
					local model = number(boss.model)
					if model then add(models, boss.name, { model = model }) end
				end
			end
		end
	end
end

local function named(index, dr, key, stop)
	if not index then return end
	local record = index[plain(stop.name)] or index[plain(dr.LocText(stop, "name"))]
	if record then return record end
	local encounter = dr:GetStopEncounter(key, stop)
	if encounter then return index[plain(encounter.name)] or index[plain(dr.LocText(encounter, "name"))] end
end
local function apply(texture, record)
	if not record then return false end
	if record.model and SetPortraitTextureFromCreatureDisplayID then
		local ok, result = pcall(SetPortraitTextureFromCreatureDisplayID, texture, record.model)
		if ok and result ~= false then return true end
	end
	if (type(record.icon) == "string" and record.icon ~= "") or number(record.icon) then
		local ok, result = pcall(texture.SetTexture, texture, record.icon)
		if ok and result ~= false then return true end
	end
	return false
end

function Portraits.Apply(texture, dr, key, stop)
	texture:SetTexture(nil)
	texture:SetTexCoord(0, 1, 0, 1)
	local index = Portraits.native and Portraits.native[key]
	local record
	if index then
		for _, id in ipairs(stop.encounters or {}) do if index.ids[id] then record = index.ids[id] break end end
		if not record then record = named(index.names, dr, key, stop) end
	end
	if apply(texture, record) then return true, "forever" end
	if apply(texture, named(Portraits.journal and Portraits.journal[key], dr, key, stop)) then return true, "journal" end
	if apply(texture, named(Portraits.compendium and Portraits.compendium[key], dr, key, stop)) then return true, "compendium" end
	texture:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
	return false, "skull"
end
