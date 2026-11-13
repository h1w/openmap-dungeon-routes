local _, NS = ...
local P=NS.Portraits
local savedProvider=Provider
local savedJournal=ForeverDungeonJournal_NS
local currentTier,currentInstance=2,800
EJ_GetNumTiers=function() return 2 end
EJ_GetCurrentTier=function() return currentTier end
EJ_GetCurrentInstance=function() return currentInstance end
EJ_SelectTier=function(t) currentTier=t end
EJ_SelectInstance=function(i) currentInstance=i end
EJ_GetInstanceByIndex=function(i,raid)
 if currentTier==1 and not raid and i==1 then return 700,"Hall of Thanes",nil,nil,nil,nil,nil,0,nil,false,3065 end
end
EJ_GetEncounterInfoByIndex=function(i,id)
 assert(currentInstance==id,"native encounter enumerated without selecting its instance")
 if id==700 and i==1 then return "Localized encounter","",900,nil,nil,700,3493,3065 end
end
EJ_GetCreatureInfo=function(i,id)
 assert(id==900,"DungeonEncounterID incorrectly used as JournalEncounterID")
 if i==1 then return 88,"Localized creature","",12345,98765 end
end
ForeverDungeonJournal_NS={DB={["Hall of Thanes"]={bosses={
 {name="Faldrim Anvilmar",npcID=261306},
 {name="Magmatus",aliases={"Magmatus","Infurnus"},customIcon="native-fire-icon"},
 {name="Plunder",npcID=261311},
}}},STATIC_DISPLAY_IDS={[261306]=111,[261311]=222}}
D4SharedSettingsRegistry={entries={{owner=Provider}}}
P.Build(DR)
assert(currentTier==2 and currentInstance==800,"native journal browsing selection changed")
local texture={SetTexCoord=function() end,SetTexture=function(self,v) self.value=v end}
SetPortraitTextureFromCreatureDisplayID=function(t,id) t.value=id end
local stop={name="Faldrim Anvilmar",encounters={3493}}
local ok,source=P.Apply(texture,DR,"hallofthanes",stop)
assert(ok and source=="forever" and texture.value==12345,"native API must precede both addons")
SetPortraitTextureFromCreatureDisplayID=function(t,id) if id==12345 then error("model unavailable") end t.value=id end
ok,source=P.Apply(texture,DR,"hallofthanes",stop)
assert(ok and source=="forever" and texture.value==98765,"native icon not tried after native model failure")
ok,source=P.Apply(texture,DR,"hallofthanes",{name="Infurnus",encounters={3495}})
assert(ok and source=="journal" and texture.value=="native-fire-icon","journal alias/custom icon missed")
ok,source=P.Apply(texture,DR,"hallofthanes",{name="Plunder"})
assert(ok and source=="journal" and texture.value==222,"journal must precede Compendium per boss")
ForeverDungeonJournal_NS=nil
P.Build(DR)
ok,source=P.Apply(texture,DR,"hallofthanes",{name="Plunder"})
assert(ok and source=="compendium" and texture.value==142840,"Compendium fallback missing")
D4SharedSettingsRegistry=nil;AzerothCompendium=nil
P.Build(DR)
ok,source=P.Apply(texture,DR,"hallofthanes",stop)
assert(ok and source=="forever" and texture.value==98765,"optional addons required for native result")
ok,source=P.Apply(texture,DR,"hallofthanes",{name="Unknown"})
assert(not ok and source=="skull" and texture.value:find("Skull"),"missing portrait must clear stale texture")
-- Secret IDs/text must not become indices or be compared with ordinary values.
EJ_GetCreatureInfo=function() return nil,{secret=true},nil,{secret=true},{secret=true} end
P.Build(DR)
ok,source=P.Apply(texture,DR,"hallofthanes",stop)
assert(not ok and source=="skull","secret values accepted as public portrait data")
EJ_GetInstanceByIndex=nil;EJ_GetEncounterInfoByIndex=nil;EJ_GetCreatureInfo=nil;EJ_GetNumTiers=nil
ForeverDungeonJournal_NS=savedJournal
D4SharedSettingsRegistry={entries={{owner=savedProvider}}}
P.Build(DR)
