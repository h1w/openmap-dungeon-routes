-- Exercise real route drawing; only the unavailable client line API is doubled.
local _, NS = ...
local function renderer()
	local layer = {}
	function layer:CreateLine(_, drawLayer)
		local line = { drawLayer = drawLayer, subLevel = 0 }
		function line:SetDrawLayer(layerName, subLevel) self.drawLayer, self.subLevel = layerName, subLevel end
		function line:SetThickness(width) self.width = width end
		function line:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
		function line:SetStartPoint(_, _, x, y) self.x1, self.y1 = x, -y end
		function line:SetEndPoint(_, _, x, y) self.x2, self.y2 = x, -y end
		function line:Show() self.shown = true end
		function line:Hide() self.shown = false end
		return line
	end
	return setmetatable({ layer = layer, lines = {}, width = 100, height = 100 }, { __index = NS.Render })
end

-- Composite line interiors in draw-layer order to detect casing over painted route.
local function pixel(r, x, y)
	local ordered = {}
	for i, line in ipairs(r.lines) do
		if line.shown then ordered[#ordered + 1] = { line = line, order = i } end
	end
	table.sort(ordered, function(a, b)
		if a.line.subLevel == b.line.subLevel then return a.order < b.order end
		return a.line.subLevel < b.line.subLevel
	end)
	local color = { 0, 0, 0 }
	for _, entry in ipairs(ordered) do
		local line = entry.line
		local dx, dy = line.x2 - line.x1, line.y2 - line.y1
		local len2 = dx * dx + dy * dy
		if len2 > 0 then
			local t = ((x - line.x1) * dx + (y - line.y1) * dy) / len2
			local px, py = line.x1 + t * dx, line.y1 + t * dy
			if t >= 0 and t <= 1 and (x - px)^2 + (y - py)^2 <= (line.width / 2)^2 then
				local c = line.color
				for k = 1, 3 do color[k] = c[k] * c[4] + color[k] * (1 - c[4]) end
			end
		end
	end
	return color
end

local failures = {}
local function check(ok, message)
	if not ok then failures[#failures + 1] = message end
end
local function main(pts) return { kind = "main", floor = 1, pts = pts } end
local source = { GradientColor = function() return 0.4, 0.8, 0.6 end }
local previousDB = NS.db
NS.db = { routes = true }
local r = renderer()
local crossing = { paths = {
	main({ 0.1, 0.5, 0.9, 0.5 }),
	main({ 0.5, 0.1, 0.5, 0.9 }),
} }
r:Paths(source, crossing, 1)
check(pixel(r, 52, 50)[2] > 0.7, "later path casing covers an earlier path's colored interior")
r:Paths(source, { paths = { main({ 0.1, 0.5, 0.9, 0.5, 0.9, 0.52, 0.1, 0.52 }) } }, 1)
check(pixel(r, 50, 50)[2] > 0.7, "hairpin casing covers the outward colored route")

-- Reuse lines first as dashed branches, then main paths: their layer must change too.
r:Paths(source, { paths = { { kind = "side", floor = 1, pts = { 0.1, 0.5, 0.9, 0.5 } } } }, 1)
r:Paths(source, crossing, 1)
check(pixel(r, 52, 50)[2] > 0.7, "reused branch lines retain a casing-over-color layer")
check(pixel(r, 44, 49)[2] < 0.2, "direction arrows are hidden underneath route color")

-- Lengths 10 and 40: midpoint fractions are 0.1 and 0.6, not vertex indices.
local samples = {}
source.GradientColor = function(t) samples[#samples + 1] = t; return 0.4, 0.8, 0.6 end
local uneven = main({ 0.1, 0.1, 0.2, 0.1, 0.6, 0.1 })
uneven.t0, uneven.t1 = 0.2, 0.8
r:Paths(source, { paths = { uneven } }, 1)
check(math.abs(samples[1] - 0.26) < 1e-9 and math.abs(samples[2] - 0.56) < 1e-9,
	"gradient follows vertex count instead of segment midpoint distance and t0/t1")
samples = {}
r:Paths(source, { paths = { main({ 0.1, 0.1, 0.1, 0.1 }) } }, 1)
check(samples[1] == 0, "zero-length path produces a non-finite gradient")
r:Paths(source, crossing, 2)
check(pixel(r, 52, 50)[2] == 0, "route lines leak onto another floor")
NS.db = previousDB
assert(#failures == 0, table.concat(failures, "\n"))
print("PASS: crossing/hairpin colors; pooled layers; visible arrows; distance gradient; zero-length path; floor isolation")
