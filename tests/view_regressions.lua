-- Client boundary double: setters and post-hooks run synchronously as in WoW.
local _, NS = ...
local dr = DR
hooksecurefunc = function(object, method, callback)
	local original = object[method]
	object[method] = function(self, ...)
		original(self, ...)
		callback(self, ...)
	end
end
local function tile()
	return {
		SetTexture = function(self, path) self.texture = path end,
		GetTexture = function(self) return self.texture end,
		SetTexCoord = function(self, ...) self.coords = { ... } end,
		Show = function() end,
	}
end
local floor = { image = { path = "custom-map", right = 1, bottom = 0.667 } }
local view = { floor = 1, floors = {floor}, tiles = {}, bossPins = {}, page={GetSize=function() return 1002,668 end} }
for i=1,12 do view.tiles[i] = tile() end
NS.Host.Paint(view, floor)
-- A drag at every zoom invokes OpenMap LayoutView, overwriting every tile's crop.
-- No Host.Paint/OnUpdate between the setter and the assertion: broken crops must
-- never reach a rendered frame, not merely be repaired by the next periodic tick.
for _, width in ipairs({128,256,512,1024}) do
	view.tiles[2]:SetTexCoord(0,1,0,1)
	local c=view.tiles[2].coords
	assert(math.abs(c[1]-256/1002)<1e-9 and math.abs(c[2]-512/1002)<1e-9,
		"drag exposes repeated full-map tiles before next update")
end
view.floors[1] = { tiles = {} }
view.tiles[2]:SetTexCoord(0,0.75,0,0.5)
assert(view.tiles[2].coords[1]==0 and view.tiles[2].coords[2]==0.75,
	"custom crop leaked onto standard tiled floor")
view.floors[1] = floor
NS.Host.Paint(view, floor)
view.tiles[2]:SetTexCoord(0,1,0,1)
assert(math.abs(view.tiles[2].coords[1]-256/1002)<1e-9,"reopening custom image lost crop hook")
-- Minimap parts use FDR's projection, not a guessed dungeon/world transform.
local part={123,100.2,66.8,200.4,133.6,0,0,0,1,1,0,1,1,0}
local mini={minimap={part}}
local drawn={}
local page={GetSize=function() return 501,334 end}
function page:CreateTexture()
	local t=tile()
	function t:SetDrawLayer() end
	function t:SetSize(w,h) self.w,self.h=w,h end
	function t:ClearAllPoints() end
	function t:SetPoint(_,_,_,x,y) self.x,self.y=x,y end
	function t:Show() self.visible=true end
	function t:Hide() self.visible=false end
	drawn[#drawn+1]=t
	return t
end
view.page=page
for _,t in ipairs(view.tiles) do t.Hide=function(self) self.hidden=true end end
NS.Host.Paint(view,mini)
assert(drawn[1].texture==123 and math.abs(drawn[1].x-50.1)<1e-9 and math.abs(drawn[1].y+33.4)<1e-9,"minimap floor projection shifted")
assert(math.abs(drawn[1].w-100.2)<1e-9 and view.tiles[1].hidden,"minimap floor scaled incorrectly")
NS.Host.Paint(view,floor)
assert(not drawn[1].visible,"old minimap leaked onto another dungeon floor")
-- Native layout recreates/shows skulls every frame while LMB is held.
local function nativePin()
	return { shown=false, Show=function(self) self.shown=true end, Hide=function(self) self.shown=false end }
end
local pin=nativePin()
local update
local dragView={floor=1,floors={{fdrFloor=279}},tiles={},bossPins={pin},page=page}
function dragView:HookScript(event,fn)
	assert(event=="OnUpdate")
	update=fn
end
NS.Host.Paint(dragView,dragView.floors[1])
pin:Show()
if update then update(dragView,0.016) end
assert(not pin.shown,"native skull visible during drag until periodic update")
local created=nativePin();dragView.bossPins[2]=created
created:Show()
if update then update(dragView,0.016) end
assert(not created.shown,"newly pooled native skull escaped drag suppression")
