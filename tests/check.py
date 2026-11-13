"""Run Lua 5.1 scenarios against the installed addons; never execute game code."""
from pathlib import Path
import argparse
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--addons", required=True, type=Path)
args = parser.parse_args()
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('DR = {L=setmetatable({}, {__index=function(_,k) return k end}), Rooms={}}; NS = {}; GetLocale=function() return "enUS" end; time=function() return 100 end')
load = lua.eval('function(code, name, ns) local fn, err=loadstring(code, name); assert(fn,err); return fn(name,ns) end')
for name in ("Dungeons", "Floors", "Rooms", "Pictures", "Encounters", "DefaultRoutes", "Minimaps"):
    path = args.addons / "ForeverDungeonRoutes" / "Data" / (name + ".lua")
    load(path.read_text(encoding="utf-8-sig"), str(path), lua.globals().DR)
load((args.addons / "ForeverDungeonRoutes/Routes.lua").read_text(encoding="utf-8-sig"), "Routes", lua.globals().DR)
lua.execute('DR.db={routes={},active={}}; DR.cdb={progress={}}; DR:BuildIndex(); DR.Safe=function(v) if type(v)=="table" and v.secret then return nil end return v end')
for name in ("Data", "Location"):
    path = ROOT / "OpenMapDungeonRoutes" / (name + ".lua")
    if not path.exists():
        raise AssertionError(f"Missing integration module: {path.name}")
    load(path.read_text(encoding="utf-8"), str(path), lua.globals().NS)
lua.execute('''
local D=NS.Data
local floors=D.BuildFloors(DR,189)
assert(#floors==4, "Scarlet Monastery must retain all four wings")
assert(floors[1].fdrFloor==302 and floors[4].fdrFloor==305, "wing order")
assert(floors[2].wing=="Scarlet Monastery - Library", "OpenMap wing selection")
local dalaran=D.BuildFloors(DR,2959)
assert(#dalaran==2 and dalaran[2].fdrFloor==1029592, "Dalaran Underbelly lost")
local naxx=D.BuildFloors(DR,533)
assert(#naxx==6 and naxx[1].tiles[1]==DR.Floors[166].tiles[1], "missing Naxxramas floors")
local scholo=D.BuildFloors(DR,289)
assert(scholo[1].tiles[1]==5332424, "wrong Scholomance map art")
local u,v,r,b=D.ImageCrop(DR.Floors[1029591].image,1)
assert(u==0 and v==0 and math.abs(r-256/1002)<1e-9 and math.abs(b-256/668*0.667)<1e-9, "custom map crop")
local L=NS.Location
DR.currentKey="deadmines"
DR.LocatePlayer=function() return "deadmines",291,0.25,0.75 end
DR.GetPlayerFacing=function() return 0 end
DR.Room={Get=function() return {name="Test room"} end, OnFloor=function() return true end, Center=function() return 0.5,0.5 end}
local p=L.Resolve(DR,"deadmines",291)
assert(p.kind=="exact" and p.x==0.25 and p.y==0.75 and p.facing==0, "self location must win over room")
DR.LocatePlayer=function() return "deadmines" end
p=L.Resolve(DR,"deadmines",291)
assert(p.kind=="room" and p.x==0.5 and p.room.name=="Test room", "room fallback")
assert(L.Resolve(DR,"stockade",225)==nil, "player leaked onto browsed dungeon")
DR.Room.Get=function() return nil end
assert(L.Resolve(DR,"deadmines",291)==nil, "unknown location fabricated")
DR.LocatePlayer=function() return "deadmines",292,0.3,0.4 end
assert(L.Resolve(DR,"deadmines",291)==nil, "player shown on wrong floor")
''')
load((ROOT / "OpenMapDungeonRoutes/Portraits.lua").read_text(encoding="utf-8"), "Portraits", lua.globals().NS)
provider = lua.table()
load((args.addons / "AzerothCompendium/data/instances.lua").read_text(encoding="utf-8-sig"), "Compendium data", provider)
load((args.addons / "AzerothCompendium/data/instance_maps.lua").read_text(encoding="utf-8-sig"), "Compendium map data", provider)
lua.globals().Provider = provider
lua.execute('''
Provider.MapPins={}; Provider.GetAddonMeta=function() return "AzerothCompendium" end
D4SharedSettingsRegistry={entries={{owner=Provider}}}
NS.Portraits.Build(DR)
local applied
SetPortraitTextureFromCreatureDisplayID=function(_,model) applied=model end
local texture={SetTexCoord=function() end,SetTexture=function() applied="fallback" end}
assert(NS.Portraits.Apply(texture,DR,"hallofthanes",{name="Faldrim Anvilmar"}), "private Compendium provider not found")
assert(applied==142826,"wrong boss portrait model")
''')
load((ROOT / "tests/portrait_providers.lua").read_text(encoding="utf-8"), "Portrait providers", lua.globals().NS)
journal = lua.table(Constants=lua.table(ALBA_FAIRMOON_LOCATION="Alba Fairmoon"))
for part in ("Dungeons", "Bosses"):
    load((args.addons / "ForeverDungeonJournal/Data" / (part + ".lua")).read_text(encoding="utf-8-sig"), "Journal " + part, journal)
lua.globals().ForeverDungeonJournal_NS = journal
lua.execute('''
NS.Portraits.Build(DR)
local drawn
local texture={SetTexture=function(_,v) drawn=v end,SetTexCoord=function() end}
local ok,source=NS.Portraits.Apply(texture,DR,"hallofthanes",{name="Infurnus",encounters={3495}})
assert(ok and source=="journal" and drawn=="Interface\\\\Icons\\\\Spell_Fire_Elemental_Totem","installed journal Infurnus alias missing")
ForeverDungeonJournal_NS=nil
NS.Portraits.Build(DR)
''')
load((ROOT / "OpenMapDungeonRoutes/Host.lua").read_text(encoding="utf-8"), "Host", lua.globals().NS)
lua.execute('''
local original=DR.Floors[291].tiles[1]
local om={GetModule=function() end,Media={tex="Interface\\\\AddOns\\\\OpenMap\\\\Media\\\\Textures\\\\Forever\\\\"},MapDungeonMaps={},MapStitch={},MapDungeonMinimap={}}
assert(NS.Host.Install(DR,om))
local floor=om.MapDungeonMaps[36][1]
assert(floor.tiles[1]=="Interface\\\\AddOns\\\\OpenMap\\\\Media\\\\Textures\\\\Forever\\\\MapTile\\\\449591", "built-in OpenMap locale fix bypassed")
assert(floor.image==nil and DR.Floors[291].tiles[1]==original, "FDR source mutated")
assert(om.MapDungeonMaps[289][1].image.path=="Interface\\\\AddOns\\\\AzerothCompendium\\\\media\\\\306", "Scholomance compatible art")
assert(om.MapDungeonMaps[533][1].image.path=="Interface\\\\AddOns\\\\AzerothCompendium\\\\media\\\\166", "Naxxramas art")
assert(om.MapDungeonMaps[2959][2].image.file=="maps\\\\dalaran_underbelly", "custom floor art retained")
NS.CheckedCatalog=om.MapDungeonMaps
''')
lua.execute('''
local compendium=NS.Portraits.provider
NS.Portraits.provider=nil
local noOptional={GetModule=function() end,Media={tex="map/"},MapDungeonMaps={},MapStitch={},MapDungeonMinimap={}}
local previousLocale=GetLocale;GetLocale=function() return "ruRU" end
assert(NS.Host.Install(DR,noOptional),"integration refuses to start without optional addons")
assert(noOptional.MapDungeonMaps[533][1].minimap==DR.MinimapArt[166],"raid map lost without Compendium")
assert(noOptional.MapDungeonMaps[289][1].minimap==DR.MinimapArt[306],"Scholomance floor lost without Compendium")
assert(noOptional.MapDungeonMaps[36][1].tiles[1]=="map/MapTile\\\\449591","ordinary map depends on optional addon")
GetLocale=previousLocale;NS.Portraits.provider=compendium
''')
lua.execute('''
InCombatLockdown=function() return false end
WorldMapFrame={}; ShowUIPanel=function() end
NS.T=function(k) return k end; NS.Print=function() end
local opened
local pin={instances={{36,"Deadmines"}},OnClick=function(p) opened=p.instances[1][1] end}
NS.Host.om.MapStitch.PinSet=function() return {pins={pin}} end
NS.Host.SelectFloor=function() return true end
assert(NS.Host.Open("naxxramas") and opened==533,"dungeon without entrance cannot be browsed")
assert(pin.instances[1][1]==36,"borrowed entrance changed permanently")
''')
checked = set()
for _, floors in lua.globals().NS.CheckedCatalog.items():
    for _, floor in floors.items():
        for _, texture in floor.tiles.items():
            if isinstance(texture, str):
                relative = texture.removeprefix("Interface\\AddOns\\").replace("\\", "/")
                assert (args.addons / (relative + ".blp")).exists(), f"Missing map art: {relative}"
                checked.add(relative)
load((ROOT / "tests/view_regressions.lua").read_text(encoding="utf-8"), "View regressions", lua.globals().NS)
load((ROOT / "OpenMapDungeonRoutes/Render.lua").read_text(encoding="utf-8"), "Render", lua.globals().NS)
load((ROOT / "tests/boss_visibility.lua").read_text(encoding="utf-8"), "Boss visibility", lua.globals().NS)
load((ROOT / "OpenMapDungeonRoutes/Core.lua").read_text(encoding="utf-8"), "Core", lua.globals().NS)
lua.execute('''
local driver=Frames[#Frames]
driver:Fire("OnEvent","PLAYER_LOGIN")
driver:Fire("OnUpdate",0.11)
local v=TestView;local r=v.omdr
assert(r.showBosses==true and r.lastBosses==true,"bosses not enabled on opening")
assert(r.bar.bosses,"boss visibility button missing")
r.bar.bosses:Fire("OnClick");driver:Fire("OnUpdate",0.11)
assert(r.showBosses==false and r.lastBosses==false,"boss toggle not applied")
TestFloor({fdrKey="deadmines",fdrFloor=292});driver:Fire("OnUpdate",0.11)
assert(r.showBosses==false,"floor change reset temporary boss preference")
r.bar.toggle:Fire("OnClick");driver:Fire("OnUpdate",0.11)
assert(OpenMapDungeonRoutesDB.routes==false,"route preference not persisted")
v:Hide();v:Show();driver:Fire("OnUpdate",0.11)
assert(r.showBosses==true and r.lastBosses==true,"fast reopen did not restore bosses")
assert(OpenMapDungeonRoutesDB.routes==false,"reopen reset persistent route preference")
r.bar.bosses:Fire("OnClick");driver:Fire("OnUpdate",0.11)
TestFloor({fdrKey="dalaran",fdrFloor=1029591});driver:Fire("OnUpdate",0.11)
assert(r.showBosses==true,"different dungeon inherited hidden bosses")
TestRestore()
''')
for path in (ROOT / "OpenMapDungeonRoutes").glob("*.lua"):
    lua.eval('function(code,name) local f,e=loadstring(code,name); assert(f,e) end')(path.read_text(encoding="utf-8"), path.name)
print(f"PASS: {len(checked)} map assets; native/journal/Compendium/skull priority; real journal alias; no optional addons; minimap projection; UV crops; native skull suppression during drag; boss visibility lifecycle; Lua 5.1")
