-- Regression for the Forever chat and spaced player names shown in the report.
dofile("tools/test_sync.lua")
local FLJ=assert(_G.ForeverLootJournal)
local fire=assert(_G.FLJTestFire)
local db=FLJ.GetDB()
function GetNumGroupMembers() return 4 end
function UnitExists(u) return u=="player" or u=="party1" or u=="party2" or u=="party3" end
function UnitFullName(u)
    if u=="player" then return "Local","Realm" end
    if u=="party1" then return "Aeon","Darkmere" end
    if u=="party2" then return "Groman","Magus" end
    if u=="party3" then return "Aeon","Sunwarden" end
end
function UnitName(u) local n=UnitFullName(u);return n end
fire("GROUP_ROSTER_UPDATE")
assert(FLJ.SamePlayer("Aeon Darkmere","Aeon-Darkmere"),"spaced roster name was not resolved")
assert(not FLJ.SamePlayer("Aeon-Darkmere","Aeon-Sunwarden"),"different realms collapsed")
assert(not FLJ.SamePlayer("Aeon","Aeon-Darkmere"),"ambiguous short name picked a realm")
local oldInfo,oldInstant=C_Item.GetItemInfo,C_Item.GetItemInfoInstant
local cached=true
local function Link(id)
    return "|cff1eff00|Hitem:"..id..":0:0:0:0:0:0:0|h[Robust Helm of the Bandit]|h|r"
end
C_Item.GetItemInfo=function(item)
    local id=tonumber(tostring(item):match("item:(%d+)"))
    if id and id>=777 and id<=782 then
        if id==778 and not cached then return nil end
        local class=id==781 and 7 or id==782 and 19 or 4
        return "Robust Helm of the Bandit",Link(id),2,30,20,"Armor","Leather",1,class==4 and "INVTYPE_HEAD" or "","IconHelm",0,class,2
    end
    return oldInfo(item)
end
C_Item.GetItemInfoInstant=function(item)
    local id=tonumber(tostring(item):match("item:(%d+)"))
    if id and id>=777 and id<=782 then
        if id==778 and not cached then return nil end
        local class=id==781 and 7 or id==782 and 19 or 4
        return id,"Armor","Leather",class==4 and "INVTYPE_HEAD" or "","IconHelm",class,2
    end
    return oldInstant(item)
end
LOOT_ROLL_GREED_SELF="You have selected Greed for: %s"
LOOT_ROLL_ROLLED_NEED="Need Roll - %d for %s by %s"
LOOT_ROLL_PASSED="%s passed on: %s"
-- The observed English fallback must work even with a mismatched global string.
LOOT_ROLL_WON="%s wins an item: %s"
local count=#db.records
fire("CHAT_MSG_LOOT","You have selected Greed for: "..Link(777))
fire("CHAT_MSG_LOOT","Need Roll - 60 for "..Link(777).." by Aeon Darkmere")
fire("CHAT_MSG_LOOT","Groman Magus passed on: "..Link(777))
fire("CHAT_MSG_LOOT","Aeon Darkmere won: "..Link(777))
assert(#db.records==count+1,"reported chat sequence did not create one record")
local rec=db.records[1]
assert(rec.winner=="Aeon-Darkmere" and rec.status=="Won","chat winner was not registered canonically")
assert(#rec.rolls==3,"Need / Greed / Pass choices missing")
local need,greed,passed=false,false,false
for _,roll in ipairs(rec.rolls) do
    if roll.name=="Aeon-Darkmere" then need=roll.action=="Need" and roll.value==60 and roll.winner end
    if roll.name=="Local-Realm" then greed=roll.action=="Greed" end
    if roll.name=="Groman-Magus" then passed=roll.action=="Pass" end
end
assert(need and greed and passed,"chat roll data incorrect")
assert(db.players["aeon-darkmere"].lootCount==1,"winner total missing")
fire("CHAT_MSG_LOOT","Aeon Darkmere won: "..Link(777))
fire("CHAT_MSG_LOOT","Aeon Darkmere receives loot: "..Link(777)..".")
assert(#db.records==count+1 and rec.receipt,"winner and receipt were duplicated")
assert(db.players["aeon-darkmere"].lootCount==1,"duplicate event increased the winner total")
C_LootHistory={GetSortedInfoForDrop=function()
    return {itemHyperlink=Link(777),winner={playerName="Aeon Darkmere"},rollInfos={}}
end}
fire("LOOT_HISTORY_UPDATE_DROP",1,1)
assert(#db.records==count+1 and #rec.rolls==3,"history echo duplicated or erased chat rolls")

-- Deferred metadata must retain the roll value and winner, in arrival order.
cached=false
fire("CHAT_MSG_LOOT","Need Roll - 42 for "..Link(778).." by Aeon Darkmere")
fire("CHAT_MSG_LOOT","Aeon Darkmere won: "..Link(778))
assert(#db.records==count+1,"uncached item was guessed")
cached=true
fire("ITEM_DATA_LOAD_RESULT",778,true)
assert(#db.records==count+2,"uncached roll result was lost")
assert(db.records[1].winner=="Aeon-Darkmere" and db.records[1].rolls[1].value==42,"deferred winner/roll lost")

-- Locale templates support numbered and reordered substitution arguments.
LOOT_ROLL_ROLLED_NEED="%3$s needs %2$s with roll %1$d"
LOOT_ROLL_WON="%2$s awarded to %1$s"
fire("CHAT_MSG_LOOT","Aeon Darkmere needs "..Link(779).." with roll 19")
fire("CHAT_MSG_LOOT",Link(779).." awarded to Aeon Darkmere")
assert(#db.records==count+3 and db.records[1].winner=="Aeon-Darkmere","numbered locale template failed")
assert(db.records[1].rolls[1].value==19,"numbered roll value failed")
fire("CHAT_MSG_LOOT","Intruder Nobody won: "..Link(780))
assert(#db.records==count+3,"non-party chat name was accepted")

-- A new roll still obeys rarity registration.
FLJ.SetRarityEnabled(2,false)
fire("CHAT_MSG_LOOT","Aeon Darkmere won: "..Link(780))
assert(#db.records==count+3,"chat fallback bypassed rarity registration")
FLJ.SetRarityEnabled(2,true)
-- Sync uses the actual chat sender and the same roster identity rules.
fire("CHAT_MSG_ADDON","FLJLoot1","L1\t9001\t7\titem:781\tFar Map","PARTY","Aeon Darkmere")
fire("CHAT_MSG_ADDON","FLJLoot1","L1\t9002\t19\titem:782\tFar Map","PARTY","Aeon Darkmere")
assert(#db.records==count+5,"profession item classes or spaced sender rejected")
assert(db.records[1].winner=="Aeon-Darkmere","sync sender was not canonicalized")
fire("CHAT_MSG_ADDON","FLJLoot1","L1\t9003\t88\titem:782\tFar Map","PARTY","Aeon Darkmere")
assert(#db.records==count+5,"invalid sync class was accepted")
-- Another actual roll of the same item must not replace the earlier winner.
fire("CHAT_MSG_LOOT","Groman Magus needs "..Link(777).." with roll 33")
fire("CHAT_MSG_LOOT",Link(777).." awarded to Groman Magus")
assert(#db.records==count+6 and db.records[1].winner=="Groman-Magus","a second drop replaced an earlier winner")
assert(db.players["aeon-darkmere"].lootCount==5,"an earlier winner total changed")
io.write("Forever roll chat, canonical names, deduplication, deferred metadata, locale and sync tests passed\n")
