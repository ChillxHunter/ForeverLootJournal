-- Core and sync must record profession loot; learned recipes never enter this view.
dofile("tools/test_sync.lua")
local FLJ=assert(_G.ForeverLootJournal)
local fire=assert(_G.FLJTestFire)
local db=FLJ.GetDB()
local legacy={name="Learned Copper Sword",recipeID=100,knownBy={["Local-Realm"]=true}}
db.recipes={["100"]=legacy}
local info=C_Item.GetItemInfo
local instant=C_Item.GetItemInfoInstant
local items={
    [901]={name="Plans: Copper Chain Vest",class=9,sub="Blacksmithing",quality=2},
    [902]={name="Silk Cloth",class=7,sub="Cloth",quality=1},
    [903]={name="Profession Pick",class=19,sub="Mining",quality=2},
    [904]={name="Arcane Reagent",class=5,sub="Reagent",quality=1},
    [905]={name="Formula: Enchant Bracer",class=9,sub="Enchanting",quality=2},
}
C_Item.GetItemInfo=function(link)
    local id=tonumber(tostring(link):match("item:(%d+)"))
    local x=items[id]
    if not x then return info(link) end
    return x.name,"item:"..id,x.quality,30,10,"Profession item",x.sub,1,"","Icon",0,x.class,0
end
C_Item.GetItemInfoInstant=function(link)
    local id=tonumber(tostring(link):match("item:(%d+)"))
    local x=items[id]
    if not x then return instant(link) end
    return id,"Profession item",x.sub,"","Icon",x.class,0
end
C_TradeSkillUI={GetAllRecipeIDs=function()error("learned recipes must not be scanned")end}
assert(loadfile("Crafting.lua"))("ForeverLootJournal",FLJ)
local before=#db.records
local sent={}
C_ChatInfo.SendAddonMessage=function(prefix,payload,channel)sent[#sent+1]=payload end
for id,x in pairs(items) do
    fire("CHAT_MSG_LOOT","You receive loot: |Hitem:"..id.."|h["..x.name.."]|h.")
end
assert(#db.records==before+5,"profession loot classes were not recorded")
assert(#FLJ.Crafting.GetDrops()==5,"crafting view must contain loot drops only")
assert(FLJ.Crafting.Scan()==0 and db.recipes["100"]==legacy,"viewing drops changed legacy recipes")
fire("TRADE_SKILL_SHOW")
fire("NEW_RECIPE_LEARNED",100)
assert(#FLJ.Crafting.GetDrops()==5,"profession events imported learned recipes")
for _,drop in ipairs(FLJ.Crafting.GetDrops()) do
    assert(drop.record and drop.foundBy=="Local-Realm" and drop.zone=="Home Map","drop provenance missing")
    assert(drop.recipeID:sub(1,5)=="loot-","drop identity missing")
end
local tradeSent=false
for _,payload in ipairs(sent) do
    if payload:find("L1\t",1,true)==1 and payload:find("\t7\t",1,true) then tradeSent=true end
end
assert(tradeSent,"trade goods did not share over party sync")
assert(FLJ.ReceiveSharedLoot("Remote-Realm","craft-900","item:902",7,"Far Mine"))
assert(#FLJ.Crafting.GetDrops()==6,"cross-zone material drop not shown")
assert(not FLJ.ReceiveSharedLoot("Remote-Realm","craft-900","item:902",7,"Far Mine"),"repeated sync duplicated a drop")
local oldCount=#db.records
FLJ.SetRarityEnabled(1,false)
fire("CHAT_MSG_LOOT","You receive loot: |Hitem:902|h[Silk Cloth]|h.")
assert(#db.records==oldCount,"materials bypassed rarity registration")
assert(db.recipes["100"]==legacy,"learned recipe history was deleted")
io.write("Crafting drops, provenance, party sync, rarity and legacy preservation tests passed\n")

