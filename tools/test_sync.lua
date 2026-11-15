-- Full integration test of Core.lua + Sync.lua under Lua 5.1.
-- Simulates a party member looting equipment on another map.
local now=1770000000
time=function() return now end
date=function() return "TEST" end
function wipe(t) for k in pairs(t) do t[k]=nil end end
local frames={}
function CreateFrame(kind,name,parent)
    local f={events={}}
    function f:RegisterEvent(k) self.events[k]=true end
    function f:SetScript(k,fn) self[k]=fn end
    frames[#frames+1]=f
    return f
end
C_Timer={
    After=function(seconds,fn) end,
    NewTicker=function(seconds,fn) end,
}
function IsInRaid() return false end
function IsInGroup() return true end
function GetNumGroupMembers() return 2 end
function UnitExists(u) return u=="player" or u=="party1" end
function UnitIsPlayer(u) return UnitExists(u) end
function UnitFullName(u)
    if u=="player" then return "Local","Realm" end
    if u=="party1" then return "Remote","Realm" end
end
function UnitName(u)
    if u=="player" then return "Local" end
    if u=="party1" then return "Remote" end
end
function UnitClass(u) return "Hunter","HUNTER" end
function UnitLevel(u) return 35 end
function UnitRace(u) return "Night Elf" end
function GetGuildInfo(u) return nil end
function GetRealZoneText() return "Home Map" end
LOOT_ITEM_SELF="You receive loot: %s."
LOOT_ITEM="%s receives loot: %s."
local sent={}
C_ChatInfo={
    RegisterAddonMessagePrefix=function(prefix)
        assert(prefix=="FLJLoot1")
        return 0
    end,
    SendAddonMessage=function(prefix,payload,channel)
        assert(prefix=="FLJLoot1")
        assert(channel=="PARTY")
        assert(#payload<=255)
        sent[#sent+1]={prefix,payload,channel}
        return 0
    end,
}
C_Item={
    GetItemInfo=function(item)
        local id=tonumber(tostring(item):match("item:(%d+)"))
        if id==123 then
            return "Local Sword","item:123",2,35,1,"Weapon","Sword",1,"INVTYPE_WEAPON","IconSword",0,2,7
        elseif id==456 then
            return "Remote Belt","item:456",2,30,1,"Armor","Leather",1,"INVTYPE_WAIST","IconBelt",0,4,2
        end
    end,
    GetItemInfoInstant=function(item)
        local id=tonumber(tostring(item):match("item:(%d+)"))
        if id==123 then return 123,"Weapon","Sword","INVTYPE_WEAPON","IconSword",2,7 end
        if id==456 then return 456,"Armor","Leather","INVTYPE_WAIST","IconBelt",4,2 end
    end,
    GetItemStats=function(link) return {ITEM_MOD_AGILITY_SHORT=6} end,
}
_G.ITEM_MOD_AGILITY_SHORT="Agility"
local prints={}
print=function(str) prints[#prints+1]=str end
SlashCmdList={}
local FLJ={}
assert(loadfile("Core.lua"))("ForeverLootJournal",FLJ)
assert(loadfile("Sync.lua"))("ForeverLootJournal",FLJ)
local function Fire(event,...)
    for _,frame in ipairs(frames) do
        if frame.events[event] and frame.OnEvent then frame.OnEvent(frame,event,...) end
    end
end
_G.FLJTestFire=Fire -- used by the separate registration-filter integration test
Fire("ADDON_LOADED","ForeverLootJournal")
Fire("PLAYER_LOGIN")
Fire("PLAYER_ENTERING_WORLD")
local found=false
for _,p in ipairs(FLJ.GetPlayers()) do
    if p.name=="Remote-Realm" and p.current then found=true end
end
assert(found,"remote player absent from roster")
local db=assert(FLJ.GetDB())
assert(db.ui.syncEnabled==true,"sharing should be enabled by default")

-- Local sword is broadcast to current group.
Fire("CHAT_MSG_LOOT","You receive loot: |Hitem:123|h[Local Sword]|h.")
local outgoing
for _,entry in ipairs(sent) do
    if entry[2]:sub(1,3)=="L1\t" then outgoing=entry[2] end
end
assert(outgoing and outgoing:find("item:123",1,true),"locally looted weapon was not broadcast")

-- Remote player loots armor on a different map: receiver sees it over chat addon.
local remote="L1\t17\t4\titem:456\tFaraway Map"
Fire("CHAT_MSG_ADDON","FLJLoot1",remote,"PARTY","Remote-Realm")
local count=0
local rec
for _,r in ipairs(FLJ.GetRecords()) do
    count=count+1
    if r.itemID==456 then rec=r end
end
assert(rec and rec.winner=="Remote-Realm","remote winner not saved")
assert(rec.zone=="Faraway Map","remote loot must retain the sender's zone")
assert(rec.classID==4,"remote armor lost its equipment class")
assert(rec.stats and #rec.stats>0 and rec.stats[1].value==6,"remote equipment stats not populated")

Fire("CHAT_MSG_ADDON","FLJLoot1",remote,"PARTY","Remote-Realm")
assert(#FLJ.GetRecords()==count,"duplicate remote transmission created duplicate loot")
Fire("CHAT_MSG_ADDON","FLJLoot1","L1\t18\t4\titem:456\tFaraway Map","PARTY","NotInGroup")
assert(#FLJ.GetRecords()==count,"non-party sender must be rejected")
Fire("CHAT_MSG_ADDON","FLJLoot1","L1\t19\t4\titem:456\tFaraway Map","GUILD","Remote-Realm")
assert(#FLJ.GetRecords()==count,"guild channel must be rejected")

SlashCmdList.FOREVERLOOTJOURNAL("sync off")
Fire("CHAT_MSG_ADDON","FLJLoot1","L1\t20\t4\titem:456\tFaraway Map","PARTY","Remote-Realm")
assert(#FLJ.GetRecords()==count,"sync off must reject remote records")
SlashCmdList.FOREVERLOOTJOURNAL("sync on")
assert(db.ui.syncEnabled==true,"sync on not persisted")
SlashCmdList.FOREVERLOOTJOURNAL("sync check")
SlashCmdList.FOREVERLOOTJOURNAL("sync status")
local previous=false
for _,p in ipairs(prints) do if p:find("detected peers=",1,true) then previous=true end end
assert(previous,"sync status command did not output detected peers")
print("Cross-zone group sharing integration tests passed")
