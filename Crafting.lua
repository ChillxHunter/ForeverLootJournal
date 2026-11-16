-- Crafting is a view of recorded loot, never a learned-recipe catalogue.
local _,FLJ=...
local Craft={}
FLJ.Crafting=Craft
local function Classify(record)
    local id=tonumber(record.classID)
    if not id and record.link and FLJ.ItemInfo then
        local ok,info=pcall(FLJ.ItemInfo,record.link)
        if ok and type(info)=="table" then id=tonumber(info.classID) end
    end
    return id
end
function Craft.GetDrops()
    local result={}
    for _,r in ipairs(FLJ.GetRecords and FLJ.GetRecords() or {}) do
        local cls=Classify(r)
        if cls==9 or cls==7 or cls==5 or cls==19 then
            result[#result+1]={
                recipeID="loot-"..tostring(r.id),record=r,looted=true,
                name=r.name,icon=r.icon,itemLink=r.link,quality=r.quality,
                profession=r.subtype or r.type or "Profession item",
                kind=cls==9 and "Recipe / Plan" or cls==19 and "Profession equipment" or "Material / Reagent",
                classID=cls,foundBy=r.winner,zone=r.zone,date=r.time,
                status=r.status,source=r.source,itemLevel=r.itemLevel,
                requiredLevel=r.requiredLevel,rolls=r.rolls or {},
            }
        end
    end
    table.sort(result,function(a,b)
        if (a.date or 0)~=(b.date or 0) then return (a.date or 0)>(b.date or 0) end
        return (tonumber(a.record.id) or 0)>(tonumber(b.record.id) or 0)
    end)
    return result
end
-- Compatibility for callers of the earlier module; no profession UI scans.
Craft.GetRecipes=Craft.GetDrops
function Craft.Scan() return 0 end

