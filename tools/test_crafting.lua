-- Forever Loot Journal recipe scanner test with WoW 16001 profession APIs.
local frames={}
function CreateFrame()
    local f={events={}}
    function f:RegisterEvent(name) self.events[name]=true end
    function f:SetScript(name,func) self[name]=func end
    frames[#frames+1]=f
    return f
end
time=function() return 1770000000 end
UnitFullName=function(unit) return "Crafter","Realm" end
C_Timer={After=function(_,callback) callback() end}
local db={records={},recipes={}}
local refreshCount=0
local FLJ={GetDB=function()return db end,UI={Refresh=function()refreshCount=refreshCount+1 end}}
local learned={
    [100]={name="Copper Sword",recipeID=100,learned=true,icon=122,hyperlink="|Hspell:100|h[Copper Sword]|h"},
    [200]={name="Linen Bandage",recipeID=200,learned=true,icon=123},
    [300]={name="Unlearned Recipe",recipeID=300,learned=false,icon=124},
}
C_TradeSkillUI={
    GetAllRecipeIDs=function() return {100,200,300} end,
    GetRecipeInfo=function(id) return learned[id] end,
    GetBaseProfessionInfo=function() return {professionName="Blacksmithing"} end,
    GetTradeSkillLineForRecipe=function(id)
        if id==200 then return 1,"First Aid" end
        return 2,"Blacksmithing"
    end,
    GetRecipeSchematic=function(id)
        if id==100 then
            return {
                outputItemID=111,
                reagentSlotSchematics={
                    {quantityRequired=2,reagents={{itemID=500}}},
                    {quantityRequired=1,reagents={{itemID=501}}},
                },
            }
        end
        return {reagentSlotSchematics={}}
    end,
    GetRecipeItemLink=function(id) return "item:"..id end,
}
C_Item={GetItemNameByID=function(id)
    if id==500 then return "Copper Bar" end
    if id==501 then return "Flux" end
end}
assert(loadfile("Crafting.lua"))("ForeverLootJournal",FLJ)
local function Fire(event,...)
    for _,f in ipairs(frames) do
        if f.events[event] and f.OnEvent then f.OnEvent(f,event,...) end
    end
end
Fire("TRADE_SKILL_SHOW")
assert(db.recipes["100"] and db.recipes["200"],"learned recipes were not stored")
assert(not db.recipes["300"],"unlearned recipe must not be stored as learned")
assert(#FLJ.Crafting.GetRecipes()==2,"incorrect learned recipe count")
local sword=db.recipes["100"]
assert(sword.name=="Copper Sword" and sword.profession=="Blacksmithing")
assert(sword.knownBy["Crafter-Realm"],"character ownership missing")
assert(#sword.materials==2,"recipe schematic materials were not stored")
assert(sword.materials[1].name=="Copper Bar" and sword.materials[1].quantity==2)
assert(sword.itemLink=="item:100","crafted item link missing")
local refreshed=refreshCount
Fire("TRADE_SKILL_LIST_UPDATE")
assert(#FLJ.Crafting.GetRecipes()==2,"rescan created duplicate recipe records")
assert(refreshCount==refreshed,"unchanged recipe list shouldn't trigger refresh")
learned[400]={name="Rare Helm",recipeID=400,learned=true,icon=125}
Fire("NEW_RECIPE_LEARNED",400)
assert(db.recipes["400"] and db.recipes["400"].knownBy["Crafter-Realm"],"newly learned recipe not saved")
assert(#FLJ.Crafting.GetRecipes()==3,"new recipe not in archive")
print("Crafting recipe scanner tests passed")
