local _, NS = ...
local Render = NS.Render
local rows = {}
local r = setmetatable({pins={}, showBosses=false}, {__index=Render})
r.Pin=function(_,kind) rows[#rows+1]=kind end
local route={stops={{kind="boss",floor=1}},notes={{floor=1}},links={{floor=1,to=2}},paths={}}
local source={GetStopLabels=function() return {"1"} end,OnFloor=function(e,f) return e.floor==f end}
r:Pins(source,"test",route,1)
assert(#rows==2 and rows[1]=="note" and rows[2]=="link","boss toggle hides notes/links or leaves boss pins")
r.showBosses=true; rows={}
r:Pins(source,"test",route,1)
assert(#rows==3 and rows[1]=="stop","boss toggle does not restore boss pins")

-- Drive real Core.lua event/update/button callbacks at the game-frame boundary.
local function frame()
 local f={scripts={},shown=true,width=800}
 function f:SetScript(k,fn) self.scripts[k]=fn end
 function f:HookScript(k,fn) local old=self.scripts[k]; self.scripts[k]=function(...) if old then old(...) end fn(...) end end
 function f:Fire(k,...) if self.scripts[k] then self.scripts[k](self,...) end end
 function f:RegisterEvent() end
 function f:SetText(t) self.text=t end
 function f:SetWidth(w) self.width=w end
 function f:GetWidth() return self.width end
 function f:SetSize() end
 function f:SetPoint() end
 function f:SetHeight() end
 function f:SetFrameLevel() end
 function f:ClearAllPoints() end
 function f:Show() local was=self.shown;self.shown=true;if not was then self:Fire("OnShow") end end
 function f:Hide() local was=self.shown;self.shown=false;if was then self:Fire("OnHide") end end
 function f:IsShown() return self.shown end
 return f
end
Frames={}
CreateFrame=function() local f=frame();Frames[#Frames+1]=f;return f end
GetLocale=function() return "ruRU" end
DEFAULT_CHAT_FRAME={AddMessage=function() end};SlashCmdList={}
OpenMap={}; OpenMapDungeonRoutesDB={routes=true}
local view=frame();view.port=frame();view.page={GetSize=function() return 800,533 end};view.GetFrameLevel=function() return 1 end
view.prev=frame();view.next=frame();view.floorButton=frame()
local f1={fdrKey="deadmines",fdrFloor=291};local floor=f1
local dr=DR;ForeverDungeonRoutes=dr;dr.currentKey=nil
local originalOn=dr.On
local callbacks={};dr.On=function(_,event,fn) callbacks[event]=fn end
local originalRoute=dr.GetActiveRoute
local originalName=dr.GetRouteName
dr.GetActiveRoute=function() return {id="default"} end;dr.GetRouteName=function() return "Route" end
dr.Window={IsMini=function() return false end,GetFrame=function() end}
NS.Host.Install=function() return true end
NS.Host.View=function() if view:IsShown() then return view,floor end end
NS.Host.Paint=function() end
NS.Portraits.Build=function() end
NS.Render.Create=function()
 local object={layer=frame(),overlay=frame()}
 object.Refresh=function(self) self.lastBosses=self.showBosses end
 object.Position=function() end
 return object
end
TestView=view
TestFloor=function(f) floor=f end
TestCallbacks=callbacks
TestRestore=function() dr.On=originalOn;dr.GetActiveRoute=originalRoute;dr.GetRouteName=originalName end
