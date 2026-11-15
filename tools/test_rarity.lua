-- Registration rarity filters: test new loot only and preservation of existing entries.
dofile("tools/test_sync.lua")
local FLJ=assert(_G.ForeverLootJournal)
local db=assert(FLJ.GetDB())
local fire=assert(_G.FLJTestFire)
local initial=#FLJ.GetRecords()
assert(initial>=2,"fixture must start with existing archived loot")

local expected={"Poor","Common","Uncommon","Rare","Epic","Legendary","Artifact","Heirloom"}
assert(#FLJ.RarityOptions==8,"all eight game rarities must be available")
for i=0,7 do
    local entry=FLJ.RarityOptions[i+1]
    assert(entry.id==i and entry.label==expected[i+1],"incorrect rarity label")
    assert(FLJ.IsRarityEnabled(i)==true,"new players should save every rarity")
end
assert(not FLJ.SetRarityEnabled(-1,false),"invalid rarity accepted")
assert(not FLJ.SetRarityEnabled(8,false),"quality 8 is not a supported toggle")
assert(not FLJ.SetRarityEnabled(2,"no"),"invalid enabled flag accepted")

-- Turn Uncommon OFF: no existing records or owner information can be deleted.
assert(FLJ.SetRarityEnabled(2,false))
assert(FLJ.IsRarityEnabled(2)==false)
assert(#db.records==initial,"switching rarity off deleted previously recorded loot")
local initialWinner=db.records[1].winner
local initialID=db.records[1].id

fire("CHAT_MSG_LOOT","You receive loot: |Hitem:123|h[Local Sword]|h.")
assert(#db.records==initial,"new local Uncommon loot was saved despite OFF setting")
local remoteAdded=FLJ.ReceiveSharedLoot("Remote-Realm","301","item:456",4,"Faraway Map")
assert(not remoteAdded and #db.records==initial,"cross-map Uncommon loot bypassed rarity filter")

-- Add a new quality-4 item for Need/Greed roll API and remote messages.
local getInfo=C_Item.GetItemInfo
local getInstant=C_Item.GetItemInfoInstant
C_Item.GetItemInfo=function(link)
    if tostring(link):match("item:789") then
        return "Epic Staff","item:789",4,40,1,"Weapon","Staff",1,"INVTYPE_2HWEAPON","IconStaff",0,2,10
    end
    return getInfo(link)
end
C_Item.GetItemInfoInstant=function(link)
    if tostring(link):match("item:789") then
        return 789,"Weapon","Staff","INVTYPE_2HWEAPON","IconStaff",2,10
    end
    return getInstant(link)
end
C_LootHistory={
    GetSortedInfoForDrop=function(encounter,key)
        return {
            itemHyperlink="item:789",
            winner={playerName="Remote-Realm",playerClass="HUNTER",roll=88,isSelf=false},
            rollInfos={},
        }
    end,
}
FLJ.SetRarityEnabled(4,false)
fire("LOOT_HISTORY_UPDATE_DROP",40,51)
assert(#db.records==initial,"new Epic group-roll record bypassed disabled rarity")
assert(FLJ.IsRarityEnabled(4)==false)
-- An enabled rarity still records; it doesn't depend on other rarities.
FLJ.SetRarityEnabled(4,true)
fire("LOOT_HISTORY_UPDATE_DROP",40,52)
assert(#db.records==initial+1,"enabled Epic group-roll item was not registered")
assert(db.records[1].quality==4,"Epic quality was lost")

-- Remotely received gear with uncached rarity must wait for metadata instead of
-- guessing Common or writing the record while any rarity is disabled.
local getInfoWithEpic=C_Item.GetItemInfo
local ready=false
C_Item.GetItemInfo=function(link)
    if tostring(link):match("item:999") then
        if ready then return "Delayed Rare Sword","item:999",3,40,1,"Weapon","Sword",1,"INVTYPE_WEAPON","IconRare",0,2,7 end
        return nil
    end
    return getInfoWithEpic(link)
end
FLJ.SetRarityEnabled(2,false)
local lastCount=#db.records
assert(not FLJ.ReceiveSharedLoot("Remote-Realm","401","item:999",2,"Other Map"))
assert(#db.records==lastCount,"uncached quality was registered prematurely")
ready=true
fire("ITEM_DATA_LOAD_RESULT",999,true)
assert(#db.records==lastCount+1,"deferred rare item was not registered after quality resolved")
assert(db.records[1].quality==3 and db.records[1].zone=="Other Map")
FLJ.SetRarityEnabled(3,false)
local afterDisabled=#db.records
FLJ.ReceiveSharedLoot("Remote-Realm","402","item:999",2,"Other Map")
assert(#db.records==afterDisabled,"disabled Rare item was saved")

-- Existing records remain intact regardless of subsequent toggles.
local foundOld=false
for _,record in ipairs(db.records) do
    if record.id==initialID and record.winner==initialWinner then foundOld=true end
end
assert(foundOld,"existing archived loot was changed by filter settings")
FLJ.SetRarityEnabled(2,true)
FLJ.SetRarityEnabled(3,true)
assert(db.ui.rarityRegistration[2]==true and db.ui.rarityRegistration[3]==true,
       "registration settings did not persist in SavedVariables")
print("Rarity registration integration tests passed")
