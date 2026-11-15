-- Forever Loot Journal v1.2.1 - saved learned crafting recipes
-- Recipes are stored separately from equipment loot and its PC preset caps.
local addonName, FLJ = ...
local Craft = {}
FLJ.Crafting = Craft
local busy=false
local scanScheduled=false
local professionOpen=false

local function Safe(func, ...)
    if type(func)~="function" then return nil end
    local ok,a,b,c,d=pcall(func,...)
    if not ok then return nil end
    return a,b,c,d
end

local function DB()
    local db=FLJ.GetDB and FLJ.GetDB()
    if type(db)~="table" then return nil end
    if type(db.recipes)~="table" then db.recipes={} end
    return db
end

local function Character()
    local name,realm=Safe(UnitFullName,"player")
    if not name then name=Safe(UnitName,"player") end
    if type(name)~="string" then return "Unknown character" end
    if type(realm)=="string" and realm~="" then return name.."-"..realm end
    return name
end

local function ItemName(itemID)
    if type(itemID)~="number" then return "Unknown material" end
    local name=Safe(C_Item and C_Item.GetItemNameByID,itemID)
    if type(name)~="string" then name=Safe(GetItemInfo,itemID) end
    return type(name)=="string" and name or ("Item #"..itemID)
end

local function ReadMaterials(recipeID)
    local api=C_TradeSkillUI
    local schematic=Safe(api and api.GetRecipeSchematic,recipeID,false)
    if type(schematic)~="table" then return {},nil end
    local materials={}
    local slots=schematic.reagentSlotSchematics
    if type(slots)=="table" then
        for _,slot in ipairs(slots) do
            if type(slot)=="table" and type(slot.reagents)=="table" then
                local reagent=slot.reagents[1]
                if type(reagent)=="table" then
                    local itemID=tonumber(reagent.itemID)
                    local count=tonumber(slot.quantityRequired) or 1
                    local name=itemID and ItemName(itemID) or (slot.slotInfo and slot.slotInfo.slotText) or "Special material"
                    materials[#materials+1]={
                        itemID=itemID, name=tostring(name), quantity=count,
                        optional=slot.required==false,
                        alternatives=#slot.reagents>1,
                    }
                end
            end
        end
    end
    return materials,tonumber(schematic.outputItemID)
end

local function ProfessionFor(id,fallback)
    local api=C_TradeSkillUI
    local _,name=Safe(api and api.GetTradeSkillLineForRecipe,id)
    if type(name)=="string" and name~="" then return name end
    return fallback or "Unknown profession"
end

local function SaveRecipe(id,info,profession)
    local db=DB()
    if not db or type(info)~="table" or info.learned~=true then return false end
    id=tonumber(id)
    if not id then return false end
    local name=info.name
    if type(name)~="string" or name=="" then return false end
    local key=tostring(id)
    local old=db.recipes[key]
    local entry=old or {recipeID=id,knownBy={}}
    if type(entry.knownBy)~="table" then entry.knownBy={} end
    local character=Character()
    local isNew=not old or not entry.knownBy[character]
    entry.recipeID=id
    entry.name=name
    entry.profession=ProfessionFor(id,profession)
    entry.icon=info.icon or entry.icon or "Interface\\Icons\\INV_Scroll_03"
    entry.link=info.hyperlink or entry.link
    entry.knownBy[character]=true
    entry.lastSeen=time and time() or 0
    local api=C_TradeSkillUI
    local itemLink=Safe(api and api.GetRecipeItemLink,id)
    if type(itemLink)=="string" and itemLink~="" then entry.itemLink=itemLink end
    local materials,output=ReadMaterials(id)
    if #materials>0 then entry.materials=materials end
    if output then entry.outputItemID=output end
    db.recipes[key]=entry
    return isNew
end

function Craft.GetRecipes()
    local db=DB()
    local result={}
    if db then
        for _,r in pairs(db.recipes) do
            if type(r)=="table" and type(r.name)=="string" then
                result[#result+1]=r
            end
        end
    end
    table.sort(result,function(a,b)
        local pa,pb=(a.profession or ""):lower(),(b.profession or ""):lower()
        if pa~=pb then return pa<pb end
        return (a.name or ""):lower()<(b.name or ""):lower()
    end)
    return result
end

function Craft.Scan()
    local api=C_TradeSkillUI
    if busy or not (api and type(api.GetAllRecipeIDs)=="function" and type(api.GetRecipeInfo)=="function") then
        return 0
    end
    if not DB() then return 0 end
    busy=true
    local ids=Safe(api.GetAllRecipeIDs)
    local added=0
    local base=Safe(api.GetBaseProfessionInfo)
    local profession=type(base)=="table" and base.professionName or nil
    if type(ids)=="table" then
        for _,id in ipairs(ids) do
            local info=Safe(api.GetRecipeInfo,id)
            if type(info)=="table" and info.learned==true then
                if SaveRecipe(id,info,profession) then added=added+1 end
            end
        end
    end
    busy=false
    if FLJ.UI and FLJ.UI.Refresh and added>0 then FLJ.UI.Refresh() end
    return added
end

local function ScheduleScan()
    if scanScheduled then return end
    scanScheduled=true
    if C_Timer and C_Timer.After then
        C_Timer.After(.3,function()
            scanScheduled=false
            Craft.Scan()
        end)
    else
        scanScheduled=false
        Craft.Scan()
    end
end

local events=CreateFrame("Frame")
events:RegisterEvent("TRADE_SKILL_SHOW")
events:RegisterEvent("TRADE_SKILL_CLOSE")
events:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
events:RegisterEvent("TRADE_SKILL_DATA_SOURCE_CHANGED")
events:RegisterEvent("NEW_RECIPE_LEARNED")
events:SetScript("OnEvent",function(_,event,recipeID)
    if event=="TRADE_SKILL_SHOW" then
        professionOpen=true
        ScheduleScan()
    elseif event=="TRADE_SKILL_CLOSE" then
        professionOpen=false
    elseif event=="NEW_RECIPE_LEARNED" then
        -- A known recipe may be learned without the profession panel open.
        local api=C_TradeSkillUI
        local info=Safe(api and api.GetRecipeInfo,recipeID)
        if type(info)=="table" and info.learned==true and SaveRecipe(recipeID,info) then
            if FLJ.UI and FLJ.UI.Refresh then FLJ.UI.Refresh() end
        end
        if professionOpen then ScheduleScan() end
    elseif professionOpen then
        ScheduleScan()
    end
end)
