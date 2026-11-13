local ADDON, NS = ...
_G.OpenMapDungeonRoutes = NS
local RU = GetLocale() == "ruRU"
local strings = {
	routes = { "Routes", "Маршруты" }, follow = { "Follow", "Следовать" },
	bosses = { "Bosses", "Боссы" },
	choose = { "Choose route", "Выбрать маршрут" }, browse = { "Dungeons", "Подземелья" },
	noroute = { "No route available in FDR. Create or import one in /fdr.", "В FDR нет маршрута. Создай или импортируй его через /fdr." },
	approx = { "approx.", "примерно" }, room = { "Current room", "Текущая комната" },
	notcoords = { "room estimate, not coordinates", "область комнаты, не точные координаты" },
	position = { "Position", "Координаты" }, you = { "You", "Ты" }, floor = { "Change floor", "Перейти на этаж" },
	unknown = { "Position unavailable; waiting for a known room.", "Позиция недоступна; ожидаем известную комнату." },
	tick = { "Click: toggle completion. Alt-click: show to group (FDR).", "Клик: отметить прохождение. Alt-клик: показать группе (FDR)." },
	combat = { "Open the dungeon map after combat.", "Открой карту подземелья после боя." },
	entrance = { "Dungeon entrance not built yet. Open its entrance on OpenMap first.", "Вход ещё не построен. Сначала открой вход этого данжа на OpenMap." },
	incompatible = { "Unsupported OpenMap dungeon view; integration disabled.", "Несовместимое окно данжей OpenMap; интеграция отключена." },
	ready = { "Ready. /omdr opens the dungeon browser; /omdr pos checks location.", "Готово. /omdr — список подземелий; /omdr pos — проверка позиции." },
	missing = { "OpenMap and ForeverDungeonRoutes must be enabled.", "Включи OpenMap и ForeverDungeonRoutes." },
}
function NS.T(key) local s = strings[key] return s and s[RU and 2 or 1] or key end
function NS.Print(text) DEFAULT_CHAT_FRAME:AddMessage("|cffe6b85cOpenMap Routes|r: " .. tostring(text)) end

local frame = CreateFrame("Frame")
local currentView, currentFloor, currentKey, renderer
local dirty, elapsed = true, 0
local lastWidth, lastHeight, lastFloor
local following = true

local function browser(owner)
	if not WorldMapFrame:IsShown() then
		if InCombatLockdown() then NS.Print(NS.T("combat")) return end
		ShowUIPanel(WorldMapFrame)
	end
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle("OpenMap Dungeon Routes")
		for _, dungeon in ipairs(NS.dr.Dungeons) do
			local key = dungeon.key
			root:CreateButton(NS.dr:GetKeyName(key), function() NS.Host.Open(key) dirty = true end)
		end
	end)
end

local function controls(view)
	local bar = CreateFrame("Frame", nil, view.port)
	bar:SetPoint("TOPLEFT", 8, -8)
	bar:SetPoint("TOPRIGHT", -8, -8)
	bar:SetHeight(25)
	bar:SetFrameLevel(view:GetFrameLevel() + 45)
	local function button(text, width, x, click)
		local b = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
		b:SetSize(width, 24)
		b:SetPoint("TOPLEFT", x, 0)
		b:SetText(text)
		b:SetScript("OnClick", click)
		return b
	end
	bar.route = button(NS.T("choose"), 210, 0, function(owner)
		MenuUtil.CreateContextMenu(owner, function(_, root)
			root:CreateTitle(NS.dr:GetKeyName(currentKey))
			for _, route in ipairs(NS.dr:GetRoutes(currentKey)) do
				local id = route.id
				root:CreateRadio(NS.dr:GetRouteName(route), function()
					local active = NS.dr:GetActiveRoute(currentKey)
					return active and active.id == id
				end, function()
					NS.dr:SetActiveRoute(currentKey, id)
					NS.Host.SelectFloor(NS.dr:GetRouteStartFloor(route))
					dirty = true
				end)
			end
		end)
	end)
	bar.follow = button(NS.T("follow"), 100, 216, function()
		following = not following
		lastFloor = nil
		dirty = true
	end)
	bar.toggle = button(NS.T("routes"), 100, 322, function() NS.db.routes = not NS.db.routes dirty = true end)
	bar.bosses = button(NS.T("bosses"), 70, 426, function()
		view.omdr.showBosses = not view.omdr.showBosses
		dirty = true
	end)
	bar.browse = button(NS.T("browse"), 110, 428, browser)
	bar:SetScript("OnSizeChanged", function(_, width)
		local available = math.max(80, width - 324)
		bar.route:SetWidth(available)
		bar.follow:ClearAllPoints()
		bar.follow:SetPoint("LEFT", bar.route, "RIGHT", 4, 0)
		bar.follow:SetWidth(80)
		bar.toggle:ClearAllPoints()
		bar.toggle:SetPoint("LEFT", bar.follow, "RIGHT", 4, 0)
		bar.toggle:SetWidth(80)
		bar.bosses:ClearAllPoints()
		bar.bosses:SetPoint("LEFT", bar.toggle, "RIGHT", 4, 0)
		bar.bosses:SetWidth(70)
		bar.browse:ClearAllPoints()
		bar.browse:SetPoint("LEFT", bar.bosses, "RIGHT", 4, 0)
		bar.browse:SetWidth(78)
	end)
	return bar
end

local function sync()
	local view, floor = NS.Host.View()
	if not view then
		if renderer then renderer.layer:Hide() renderer.overlay:Hide() renderer.bar:Hide() end
		currentView, currentFloor, currentKey = nil, nil, nil
		return
	end
	if currentView ~= view then
		currentView = view
		if not view.omdr then
			view.omdr = NS.Render.Create(view)
			view.omdr.bar = controls(view)
			view:HookScript("OnHide", function()
				view.omdr.showBosses = true
				currentView, currentFloor, currentKey = nil, nil, nil
				dirty = true
			end)
			view.prev:HookScript("OnClick", function() if not NS.Host.selecting then following = false dirty = true end end)
			view.next:HookScript("OnClick", function() if not NS.Host.selecting then following = false dirty = true end end)
			view.floorButton:HookScript("OnClick", function() following = false end)
		end
		renderer = view.omdr
		renderer.showBosses = true
		renderer.bar:Show()
		dirty = true
	end
	local key = floor.fdrKey
	if key ~= currentKey then
		currentKey = key
		following, lastFloor, dirty = true, nil, true
		renderer.showBosses = true
	end
	if following and key == NS.dr.currentKey then
		local wanted = NS.Location.FollowFloor(NS.dr, key, floor.fdrFloor)
		if wanted and wanted ~= lastFloor then
			lastFloor = wanted
			NS.Host.SelectFloor(wanted)
			view, floor = NS.Host.View()
		end
	end
	if not view then return end
	NS.Host.Paint(view, floor)
	local w, h = view.page:GetSize()
	if floor ~= currentFloor or w ~= lastWidth or h ~= lastHeight then
		currentFloor, lastWidth, lastHeight, dirty = floor, w, h, true
	end
	if dirty then
		renderer:Refresh(NS.dr, currentKey, floor.fdrFloor)
		local route = NS.dr:GetActiveRoute(currentKey)
		renderer.bar.route:SetText(route and NS.dr:GetRouteName(route) or NS.T("noroute"))
		renderer.bar.follow:SetText((following and "|cff66ff88" or "|cffaaaaaa") .. NS.T("follow") .. "|r")
		renderer.bar.toggle:SetText((NS.db.routes and "|cff66ff88" or "|cffaaaaaa") .. NS.T("routes") .. "|r")
		renderer.bar.bosses:SetText((renderer.showBosses and "|cff66ff88" or "|cffaaaaaa") .. NS.T("bosses") .. "|r")
		dirty = false
	else
		renderer:Position(NS.dr, currentKey, floor.fdrFloor)
		if not NS.dr:GetActiveRoute(currentKey) then renderer.status:SetText(NS.T("noroute")) end
	end
end

local function start()
	if not ForeverDungeonRoutes or not ForeverDungeonRoutes.db or not OpenMap then NS.Print(NS.T("missing")) return end
	NS.dr = ForeverDungeonRoutes
	OpenMapDungeonRoutesDB = OpenMapDungeonRoutesDB or { routes = true }
	NS.db = OpenMapDungeonRoutesDB
	if NS.db.routes == nil then NS.db.routes = true end
	NS.Portraits.Build(NS.dr)
	if not NS.Host.Install(NS.dr, OpenMap) then NS.Print(NS.T("incompatible")) return end
	-- Suppress FDR's automatic second map, leaving its command/editor available explicitly.
	local originalOnEnter = NS.dr.db.onEnter
	frame:RegisterEvent("PLAYER_LOGOUT")
	frame:HookScript("OnEvent", function(_, event)
		if event == "PLAYER_LOGOUT" then NS.dr.db.onEnter = originalOnEnter end
	end)
	NS.dr.db.onEnter = "none"
	if NS.dr.Window:IsMini() then NS.dr.Window:CloseMini() end
	local fdrFrame = NS.dr.Window:GetFrame()
	if fdrFrame then fdrFrame:Hide() end
	for _, event in ipairs({ "ROUTE_CHANGED", "PROGRESS_CHANGED", "ROOM_CHANGED", "DUNGEON_CHANGED", "GROUP_ROOMS_CHANGED" }) do
		NS.dr:On(event, function() dirty = true end)
	end
	frame:RegisterEvent("ADDON_LOADED")
	frame:HookScript("OnEvent", function(_, event, name)
		if event == "ADDON_LOADED" and (name == "ForeverDungeonJournal" or name == "AzerothCompendium") then
			NS.Portraits.Build(NS.dr)
			dirty = true
		end
	end)
	frame:SetScript("OnUpdate", function(_, dt)
		elapsed = elapsed + dt
		if elapsed < 0.1 then return end
		elapsed = 0
		sync()
	end)
	local api = OpenMapAPI
	if api and api.RegisterMenuToggle then
		api.RegisterMenuToggle(ADDON, { id = "routes", label = "Dungeon Routes", section = "Forever Dungeon Routes",
			get = function() return NS.db.routes end,
			set = function(on) NS.db.routes = on dirty = true end })
	end
	NS.Print(NS.T("ready"))
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event) if event == "PLAYER_LOGIN" then start() end end)
SLASH_OPENMAPDUNGEONROUTES1 = "/omdr"
SlashCmdList.OPENMAPDUNGEONROUTES = function(input)
	if not NS.dr then NS.Print(NS.T("missing")) return end
	if strtrim(input or ""):lower() == "pos" then
		SlashCmdList.FOREVERDUNGEONROUTES("pos")
	else browser(WorldMapFrame) end
end
