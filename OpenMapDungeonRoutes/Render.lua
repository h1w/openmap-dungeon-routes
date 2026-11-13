local _, NS = ...
local Render = {}
NS.Render = Render
local MEDIA = "Interface\\AddOns\\ForeverDungeonRoutes\\media\\"

local function label(parent, size)
	local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetFont(text:GetFont(), size or 11, "OUTLINE")
	return text
end

function Render.Create(view)
	local r = setmetatable({ view = view, lines = {}, pins = {}, glows = {}, members = {} }, { __index = Render })
	r.layer = CreateFrame("Frame", nil, view.page)
	r.layer:SetAllPoints()
	r.layer:SetFrameLevel(view.page:GetFrameLevel() + 8)
	r.overlay = CreateFrame("Frame", nil, view.port)
	r.overlay:SetAllPoints()
	r.overlay:SetFrameLevel(view:GetFrameLevel() + 40)
	r.status = label(r.overlay, 12)
	r.status:SetPoint("BOTTOMLEFT", 10, 12)
	r.status:SetPoint("RIGHT", -10, 0)
	r.status:SetJustifyH("LEFT")
	r.status:SetWordWrap(true)
	r.player = r:Marker({ 1, 0.82, 0.2 })
	r.player.icon:SetTexture(MEDIA .. "player")
	r.player.icon:SetSize(26, 26)
	r.player.text:SetPoint("TOP", r.player, "BOTTOM", 0, -2)
	r.roomMarker = r:Marker({ 1, 0.82, 0.2 })
	r.roomMarker.icon:SetTexture(MEDIA .. "diamondring")
	r.roomMarker.text:SetPoint("TOP", r.roomMarker, "BOTTOM", 0, -2)
	return r
end

function Render:Marker(color)
	local pin = CreateFrame("Frame", nil, self.layer)
	pin:SetSize(24, 24)
	pin.icon = pin:CreateTexture(nil, "ARTWORK")
	pin.icon:SetAllPoints()
	pin.icon:SetTexture(MEDIA .. "ring")
	pin.icon:SetVertexColor(color[1], color[2], color[3])
	pin.text = label(pin, 12)
	pin.text:SetPoint("CENTER")
	pin.text:SetTextColor(color[1], color[2], color[3])
	pin:Hide()
	return pin
end

function Render:Place(pin, x, y)
	pin:ClearAllPoints()
	pin:SetPoint("CENTER", self.layer, "TOPLEFT", x * self.width, -y * self.height)
	pin:Show()
end

function Render:Line(x1, y1, x2, y2, thickness, red, green, blue, alpha)
	self.usedLines = self.usedLines + 1
	local line = self.lines[self.usedLines]
	if not line then
		line = self.layer:CreateLine(nil, "ARTWORK")
		self.lines[self.usedLines] = line
	end
	line:SetThickness(thickness)
	line:SetColorTexture(red, green, blue, alpha or 1)
	line:SetStartPoint("TOPLEFT", self.layer, x1, -y1)
	line:SetEndPoint("TOPLEFT", self.layer, x2, -y2)
	line:Show()
end

function Render:Arrow(x, y, dx, dy)
	local len = math.sqrt(dx * dx + dy * dy)
	if len < 0.01 then return end
	dx, dy = dx / len, dy / len
	self:Line(x - dx * 6 - dy * 3, y - dy * 6 + dx * 3, x, y, 2, 0.08, 0.06, 0.03)
	self:Line(x - dx * 6 + dy * 3, y - dy * 6 - dx * 3, x, y, 2, 0.08, 0.06, 0.03)
end

function Render:Paths(dr, route, floor)
	self.usedLines = 0
	if route and NS.db.routes then
		for _, path in ipairs(route.paths or {}) do
			if path.floor == floor then
				local pts = path.pts
				local travelled, nextArrow = 0, 38
				local count = math.max(1, #pts / 2 - 1)
				for j = 1, #pts - 3, 2 do
					local x1, y1 = pts[j] * self.width, pts[j + 1] * self.height
					local x2, y2 = pts[j + 2] * self.width, pts[j + 3] * self.height
					local dx, dy = x2 - x1, y2 - y1
					local len = math.sqrt(dx * dx + dy * dy)
					if path.kind == "side" then
						if len > 0 then
							local start = -(travelled % 12)
							while start < len do
								local a, b = math.max(0, start), math.min(len, start + 7)
								if b > a then self:Line(x1 + dx * a / len, y1 + dy * a / len,
									x1 + dx * b / len, y1 + dy * b / len, 2.5, 0.9, 0.87, 0.75) end
								start = start + 12
							end
						end
					else
						local t = (path.t0 or 0) + ((j - 1) / 2 / count) * ((path.t1 or 1) - (path.t0 or 0))
						local red, green, blue = dr.GradientColor(t)
						self:Line(x1, y1, x2, y2, 6, 0.05, 0.04, 0.03, 0.85)
						self:Line(x1, y1, x2, y2, 3.5, red, green, blue)
						while nextArrow <= travelled + len do
							local f = len > 0 and (nextArrow - travelled) / len or 0
							self:Arrow(x1 + dx * f, y1 + dy * f, dx, dy)
							nextArrow = nextArrow + 58
						end
					end
					travelled = travelled + len
				end
			end
		end
	end
	for i = self.usedLines + 1, #self.lines do self.lines[i]:Hide() end
end

function Render:NewPin()
	local pin = CreateFrame("Button", nil, self.layer)
	pin:SetSize(30, 30)
	pin:SetFrameLevel(self.layer:GetFrameLevel() + 3)
	pin.bg = pin:CreateTexture(nil, "BACKGROUND")
	pin.bg:SetPoint("TOPLEFT", -2, 2)
	pin.bg:SetPoint("BOTTOMRIGHT", 2, -2)
	pin.bg:SetTexture(MEDIA .. "circle")
	pin.bg:SetVertexColor(0.05, 0.04, 0.03, 0.95)
	pin.icon = pin:CreateTexture(nil, "ARTWORK")
	pin.icon:SetAllPoints()
	local mask = pin:CreateMaskTexture()
	mask:SetAllPoints()
	mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	pin.icon:AddMaskTexture(mask)
	pin.ring = pin:CreateTexture(nil, "OVERLAY")
	pin.ring:SetAllPoints()
	pin.ring:SetTexture(MEDIA .. "ring")
	pin.text = label(pin, 12)
	pin.text:SetPoint("BOTTOMRIGHT", 3, -2)
	pin.check = pin:CreateTexture(nil, "OVERLAY", nil, 2)
	pin.check:SetSize(18, 18)
	pin.check:SetPoint("TOPRIGHT", 4, 4)
	pin.check:SetTexture(MEDIA .. "check")
	pin:SetScript("OnEnter", function(p)
		GameTooltip:SetOwner(p, "ANCHOR_RIGHT")
		GameTooltip:AddLine(p.title, 1, 0.82, 0)
		if p.note and p.note ~= "" then GameTooltip:AddLine(p.note, 0.9, 0.9, 0.9, true) end
		if p.kind == "stop" then GameTooltip:AddLine(NS.T("tick"), 0.6, 0.8, 1, true) end
		GameTooltip:Show()
	end)
	pin:SetScript("OnLeave", GameTooltip_Hide)
	pin:SetScript("OnClick", function(p)
		if p.kind == "stop" then
			if IsAltKeyDown() then NS.dr.Group:ShowStop(p.key, p.route, p.index)
			else NS.dr:ToggleStopDone(p.key, p.route, p.index) end
		elseif p.kind == "link" then NS.Host.SelectFloor(p.to) end
	end)
	return pin
end

function Render:Pin(kind, key, route, entry, text, index)
	self.usedPins = self.usedPins + 1
	local pin = self.pins[self.usedPins]
	if not pin then pin = self:NewPin() self.pins[self.usedPins] = pin end
	pin.kind, pin.key, pin.route, pin.index, pin.to = kind, key, route, index, entry.to
	pin.title = NS.dr.LocText(entry, kind == "note" and "text" or "name") or NS.T("floor")
	pin.note = NS.dr.LocText(entry, "note")
	pin.text:SetText(text)
	local done = kind == "stop" and NS.dr:IsStopDone(key, route, index)
	pin.check:SetShown(done and true or false)
	pin:SetAlpha(done and 0.5 or 1)
	pin.icon:SetVertexColor(1, 1, 1)
	if kind == "stop" then
		local _, source = NS.Portraits.Apply(pin.icon, NS.dr, key, entry)
		pin.portraitSource = source
		if entry.kind == "rare" then pin.ring:SetVertexColor(0.75, 0.75, 0.75)
		elseif entry.kind == "optional" then pin.ring:SetVertexColor(0.45, 0.7, 1)
		else pin.ring:SetVertexColor(1, 0.8, 0.25) end
	else
		pin.icon:SetTexture(kind == "note" and "Interface\\GossipFrame\\AvailableQuestIcon" or "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
		pin.ring:SetVertexColor(0.4, 0.7, 1)
	end
	self:Place(pin, entry.x, entry.y)
end

function Render:Pins(dr, key, route, floor)
	self.usedPins = 0
	if route then
		local labels = dr:GetStopLabels(route)
		for i, stop in ipairs(route.stops or {}) do
			if self.showBosses ~= false and dr.OnFloor(stop, floor) then self:Pin("stop", key, route, stop, labels[i], i) end
		end
		for _, note in ipairs(route.notes or {}) do
			if dr.OnFloor(note, floor) then self:Pin("note", key, route, note, "!") end
		end
		for _, link in ipairs(route.links or {}) do
			if link.floor == floor then self:Pin("link", key, route, link, link.label or ">") end
		end
		-- Most routes encode floor changes only as adjacent main-path pieces.
		local previous
		for _, path in ipairs(route.paths or {}) do
			if path.kind == "main" and #path.pts >= 2 then
				if previous and previous.floor ~= path.floor then
					if previous.floor == floor then
						self:Pin("link", key, route, { x = previous.pts[#previous.pts - 1], y = previous.pts[#previous.pts], to = path.floor }, ">")
					elseif path.floor == floor then
						self:Pin("link", key, route, { x = path.pts[1], y = path.pts[2], to = previous.floor }, "<")
					end
				end
				previous = path
			end
		end
	end
	for _, note in ipairs(dr.MapNotes and dr.MapNotes[floor] or {}) do
		self:Pin("note", key, route, note, "!")
	end
	for i = self.usedPins + 1, #self.pins do self.pins[i]:Hide() end
end

function Render:Room(room, floor, red, green, blue)
	for _, box in ipairs(room.boxes) do
		if box[1] == floor then
			self.usedGlows = self.usedGlows + 1
			local line = self.glows[self.usedGlows]
			if not line then line = self.layer:CreateLine(nil, "BACKGROUND") self.glows[self.usedGlows] = line end
			local scale = self.width / 1002
			local x, y = box[2] * self.width, box[3] * self.height
			local dx, dy = math.cos(box[6]) * box[4] * scale / 2, math.sin(box[6]) * box[4] * scale / 2
			line:SetTexture(MEDIA .. "roomglow")
			line:SetThickness(math.max(1, box[5] * scale))
			line:SetVertexColor(red, green, blue, 0.4)
			line:SetStartPoint("TOPLEFT", self.layer, x - dx, -y + dy)
			line:SetEndPoint("TOPLEFT", self.layer, x + dx, -y - dy)
			line:Show()
		end
	end
end

function Render:Position(dr, key, floor)
	self.usedGlows = 0
	self.player:Hide()
	self.roomMarker:Hide()
	for _, marker in ipairs(self.members) do marker:Hide() end
	local pos = NS.Location.Resolve(dr, key, floor)
	local me = dr.Safe(UnitName("player")) or NS.T("you")
	if pos then
		if pos.kind == "exact" then
			self.player.text:SetText(me)
			self.player.icon:SetTexture(MEDIA .. (pos.facing and "player" or "circle"))
			self.player.icon:SetRotation(pos.facing or 0)
			self:Place(self.player, pos.x, pos.y)
			self.status:SetText(("%s: %.1f, %.1f"):format(NS.T("position"), pos.x * 100, pos.y * 100))
		else
			self:Room(pos.room, floor, 1, 0.75, 0.2)
			self.roomMarker.text:SetText(me .. " — " .. NS.T("approx"))
			self:Place(self.roomMarker, pos.x, pos.y)
			self.status:SetText(NS.T("room") .. ": " .. (dr.LocText(pos.room, "name") or "") .. " — " .. NS.T("notcoords"))
		end
	else
		self.status:SetText(key == dr.currentKey and NS.T("unknown") or "")
	end
	for i, entry in ipairs(dr.Group:RoomsOn(key, floor)) do
		self:Room(entry.room, floor, 0.35, 0.65, 1)
		local x, y = dr.Room:Center(entry.room, floor)
		if x then
			local marker = self.members[i]
			if not marker then marker = self:Marker({ 0.4, 0.7, 1 }) self.members[i] = marker end
			marker.text:SetText(table.concat(entry.names, ", ") .. " ~")
			self:Place(marker, x, y)
		end
	end
	for i = self.usedGlows + 1, #self.glows do self.glows[i]:Hide() end
end

function Render:Refresh(dr, key, floor)
	self.width, self.height = self.view.page:GetSize()
	if not self.width or self.width <= 0 then return end
	local route = dr:GetActiveRoute(key)
	self:Paths(dr, route, floor)
	self:Pins(dr, key, route, floor)
	self:Position(dr, key, floor)
	self.layer:Show()
	self.overlay:Show()
	if not route then self.status:SetText(NS.T("noroute")) end
end
