-- Simulate all storage tiers in the same WoW 16001 addon API mock.
-- This reuses the Core.lua + Sync.lua initialization from test_sync.lua.
dofile("tools/test_sync.lua")
local FLJ=assert(_G.ForeverLootJournal)
local db=assert(FLJ.GetDB())
local key,limit,label=FLJ.GetStoragePreset()
assert(key=="MONSTER" and limit==5000 and label=="MONSTER PC",
    "existing installations must default to the old 5000 record limit")
local expected={
    POTATO={"Potato PC",1000},
    NORMAL={"Normal PC",2000},
    STRONG={"Strong PC",3000},
    MONSTER={"MONSTER PC",5000},
    EXTREME={"EXTREME!!",10000},
}
for k,p in pairs(expected) do
    assert(FLJ.StoragePresets[k].label==p[1] and FLJ.StoragePresets[k].limit==p[2],
        "incorrect saved-loot limit for "..k)
end

local records={}
for i=3001,1,-1 do records[#records+1]={id=i,itemID=i,name="Gear "..i,rolls={}} end
db.records=records
local ok,removed=FLJ.SetStoragePreset("STRONG")
assert(ok and removed==1 and #db.records==3000 and db.records[#db.records].id==2,
    "strong preset should prune exactly one oldest record")
ok,removed=FLJ.SetStoragePreset("EXTREME")
assert(ok and removed==0 and #db.records==3000,
    "increasing cap must not delete records")
-- Build a larger archive in newest-first order, without costly head inserts.
db.records={}
for i=10002,2,-1 do
    db.records[#db.records+1]={id=i,itemID=i,rolls={}}
end
assert(#db.records==10001)
ok,removed=FLJ.SetStoragePreset("EXTREME")
assert(ok and removed==1 and #db.records==10000,
    "extreme preset must cap at 10000 records")
ok,removed=FLJ.SetStoragePreset("POTATO")
assert(ok and removed==9000 and #db.records==1000,
    "potato preset should retain the newest 1000 entries")
assert(db.records[1].id==10002,"newest loot was discarded instead of oldest")
ok,removed=FLJ.SetStoragePreset("NORMAL")
assert(ok and removed==0 and #db.records==1000 and db.ui.storagePreset=="NORMAL",
    "normal preset should raise limit without resurrecting old records")
ok,removed=FLJ.SetStoragePreset("NOT_A_PC")
assert(not ok and removed==0 and db.ui.storagePreset=="NORMAL",
    "invalid preset must not change configuration")
assert(FLJ.GetStoragePreset()=="NORMAL" and select(2,FLJ.GetStoragePreset())==2000,
    "storage preset did not persist in SavedVariables")
print("Storage preset tests passed")
