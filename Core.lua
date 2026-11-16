-- Forever Loot Journal 1.2.2 - World of Warcraft: Forever (interface 16001)
-- Account-wide saved loot archive with optional party sync via Sync.lua.
local addonName, FLJ = ...
_G.ForeverLootJournal = FLJ
local DB
local recentRolls = {}    -- session-scoped (encounterID:lootListKey -> record ID)
local deferred = {}       -- items whose item data is still being loaded
local deferredRemote = {} -- received group loot awaiting item rarity metadata
local retries = {}        -- delayed history updates
local groupNames = {}     -- case-folded full/short name -> canonical player key
local inGroup = {}        -- canonical player key -> true
local groupUnits = {}     -- canonical player key -> live unit token (not persisted)
local initialized = false
local initializingUI = false
-- Account-wide active loot limit. The default keeps the previous 5,000-item
-- behavior, so installing an update cannot silently remove a user's history.
local STORAGE_PRESETS = {
    POTATO  = {label="Potato PC", limit=1000},
    NORMAL  = {label="Normal PC", limit=2000},
    STRONG  = {label="Strong PC", limit=3000},
    MONSTER = {label="MONSTER PC", limit=5000},
    EXTREME = {label="EXTREME!!", limit=10000},
}
local STORAGE_ORDER={"POTATO","NORMAL","STRONG","MONSTER","EXTREME"}
local DEFAULT_PRESET="MONSTER"
FLJ.StoragePresets=STORAGE_PRESETS
FLJ.StoragePresetOrder=STORAGE_ORDER

local function SavedPreset()
    local key=DB and DB.ui and DB.ui.storagePreset
    if not STORAGE_PRESETS[key] then key=DEFAULT_PRESET end
    return key
end
function FLJ.GetStoragePreset()
    local key=SavedPreset()
    return key,STORAGE_PRESETS[key].limit,STORAGE_PRESETS[key].label
end
local function TrimRecords()
    if not DB then return 0 end
    local limit=STORAGE_PRESETS[SavedPreset()].limit
    local records=DB.records
    local removed=0
    while #records>limit do
        local old=table.remove(records)
        if old and old.winner then
            local key=type(old.winner)=="string" and old.winner:lower()
            local player=key and DB.players[key]
            if player and (tonumber(player.lootCount) or 0)>0 then
                player.lootCount=player.lootCount-1
            end
        end
        removed=removed+1
    end
    return removed
end
function FLJ.SetStoragePreset(key)
    if not DB or not STORAGE_PRESETS[key] then return false,0 end
    DB.ui.storagePreset=key
    local removed=TrimRecords()
    if FLJ.UI and FLJ.UI.Refresh then FLJ.UI.Refresh() end
    return true,removed
end
-- Registration preferences control ONLY future records. Never prune older
-- entries when the user changes a rarity toggle.
local RARITIES={
    {id=0,label="Poor",       color={.56,.56,.56}},
    {id=1,label="Common",     color={.97,.97,.97}},
    {id=2,label="Uncommon",   color={.12,1,.12}},
    {id=3,label="Rare",       color={.10,.50,1}},
    {id=4,label="Epic",       color={.73,.34,1}},
    {id=5,label="Legendary",  color={1,.50,.07}},
    {id=6,label="Artifact",   color={.90,.80,.45}},
    {id=7,label="Heirloom",   color={.12,.84,.80}},
}
FLJ.RarityOptions=RARITIES
local function RarityPreferences()
    if not DB or type(DB.ui)~="table" then return nil end
    if type(DB.ui.rarityRegistration)~="table" then DB.ui.rarityRegistration={} end
    return DB.ui.rarityRegistration
end
function FLJ.IsRarityEnabled(id)
    id=tonumber(id)
    local preferences=RarityPreferences()
    if id==nil or id<0 or id>7 or id%1~=0 then return true end
    return not preferences or preferences[id]~=false
end
function FLJ.SetRarityEnabled(id,enabled)
    id=tonumber(id)
    if not id or id%1~=0 or id<0 or id>7 or type(enabled)~="boolean" then return false end
    local preferences=RarityPreferences()
    if not preferences then return false end
    preferences[id]=enabled
    -- Important: do not call TrimRecords(), ClearRecords(), or mutate DB.records.
    return true
end
local function RegistrationAllowed(quality)
    local q=tonumber(quality)
    if q~=nil and q>=0 and q<=7 then
        return FLJ.IsRarityEnabled(q)
    end
    -- If all rarities are enabled, an uncached item is safe to register.
    -- Otherwise wait for item quality to load instead of guessing "Common".
    local prefs=RarityPreferences()
    if prefs then
        for i=0,7 do if prefs[i]==false then return nil end end
    end
    return true
end

local CLASS_ARMOR, CLASS_WEAPON, CLASS_RECIPE = 4, 2, 9
-- ItemClass values from the game API. Receipts are the source of this archive.
function FLJ.IsCraftingItem(item)
    local id=tonumber(type(item)=="table" and item.classID or item)
    return id==CLASS_RECIPE or id==7 or id==5 or id==19
end
local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end
FLJ.Plain = Plain
local function Now() return time and time() or 0 end
local function Clean(s)
    s = Plain(s)
    if type(s) ~= "string" then return nil end
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:]+:", ""):gsub("|r", "")
    s = s:match("^%s*(.-)%s*$")
    return s ~= "" and s or nil
end
local function Key(s) s = Clean(s); return s and s:lower() or nil end
local function ShortName(s) return s and s:match("^([^-]+)") or nil end
local function NameForm(s)
    local key=Key(s)
    return key and key:gsub("[%s%-]+","-") or nil
end
local function RosterAlias(name,canonical)
    local key=NameForm(name)
    if not key then return end
    local previous=groupNames[key]
    if previous==nil or previous==canonical then groupNames[key]=canonical
    else groupNames[key]=false end -- Ambiguous short names must never pick a realm.
end
local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a,b,c,d,e,f,g,h,i,j,k,l,m,n = pcall(fn, ...)
    if not ok then return nil end
    return Plain(a),Plain(b),Plain(c),Plain(d),Plain(e),Plain(f),Plain(g),Plain(h),Plain(i),Plain(j),Plain(k),Plain(l),Plain(m),Plain(n)
end
local function ItemInfo(link)
    local CI = C_Item
    local n, fullLink, rarity, lvl, req, typ, sub, stack, loc, icon, price, classID, subID
    n, fullLink, rarity, lvl, req, typ, sub, stack, loc, icon, price, classID, subID = SafeCall((CI and CI.GetItemInfo) or GetItemInfo, link)
    local itemID, instantTyp, instantSub, instantLoc, instantIcon, instantClass, instantSubID =
        SafeCall((CI and CI.GetItemInfoInstant) or GetItemInfoInstant, link)
    local name = n or (type(link)=="string" and link:match("|h%[(.-)%]|h"))
    return {
        id=itemID or (type(link)=="string" and tonumber(link:match("item:(%d+)"))),
        link=fullLink or link, name=name or "Unknown item", quality=rarity or (type(link)=="string" and tonumber(link:match("|cnIQ(%d+)"))),
        level=lvl, requiredLevel=req, type=typ or instantTyp, subtype=sub or instantSub,
        slot=loc or instantLoc, icon=icon or instantIcon or "Interface\\Icons\\INV_Misc_QuestionMark",
        classID=classID or instantClass, subclassID=subID or instantSubID,
    }
end
local function Gear(link)
    local item=ItemInfo(link)
    if FLJ.IsCraftingItem(item) then
        return item
    end
    if item.classID == CLASS_ARMOR or item.classID == CLASS_WEAPON then
        if item.slot and item.slot ~= "" then return item end
    end
    if item.id and (not item.classID or not item.slot) and C_Item and C_Item.RequestLoadItemDataByID then
        SafeCall(C_Item.RequestLoadItemDataByID, item.id)
    end
    return nil
end
FLJ.ItemInfo, FLJ.Gear = ItemInfo, Gear
local function Stats(link)
    local ret = {}
    local tbl = SafeCall(C_Item and C_Item.GetItemStats, link)
    if type(tbl)=="table" then
        for stat,value in pairs(tbl) do
            value=Plain(value)
            if type(stat)=="string" and type(value)=="number" then
                ret[#ret+1]={key=stat, label=(_G[stat] or stat:gsub("ITEM_MOD_", ""):gsub("_SHORT", ""):gsub("_", " ")), value=value}
            end
        end
    end
    table.sort(ret, function(a,b) return a.label<b.label end)
    return ret
end
local function MyName()
    local name, realm = SafeCall(UnitFullName, "player")
    if not name then name = SafeCall(UnitName, "player") end
    if not name then return nil end
    return realm and realm~="" and (name.."-"..realm) or name
end
local function Resolve(name)
    name=Clean(name)
    if not name then return nil end
    name=name:gsub("|Hplayer:[^|]+|h%[(.-)%]|h","%1"):gsub("|Hplayer:[^|]+|h(.-)|h","%1")
    return groupNames[NameForm(name)] or name
end
FLJ.ResolvePlayer=Resolve
function FLJ.SamePlayer(a,b)
    local left,right=NameForm(Resolve(a)),NameForm(Resolve(b))
    return left~=nil and right~=nil and left==right
end
local function Notify()
    if FLJ.UI and FLJ.UI.Refresh then FLJ.UI.Refresh() end
end
local function PlayerKey(name)
    name=Resolve(name)
    return name and Key(name) or nil
end
local function EnsurePlayer(name, meta)
    local pk=PlayerKey(name)
    if not pk then return nil end
    local old=DB.players[pk]
    local p=old or {name=Resolve(name), firstSeen=Now(), lootCount=0}
    p.name=Resolve(name) or p.name
    p.lastSeen=Now()
    if meta then
        if meta.class then p.class=Plain(meta.class) or p.class end
        if meta.level and tonumber(meta.level) and tonumber(meta.level)>0 then p.level=tonumber(meta.level) end
        if meta.guild then p.guild=Plain(meta.guild) or p.guild end
        if meta.zone then p.zone=Plain(meta.zone) or p.zone end
        if meta.race then p.race=Plain(meta.race) or p.race end
    end
    DB.players[pk]=p
    return p,pk
end
local function Zone()
    return (GetRealZoneText and Plain(GetRealZoneText())) or (GetZoneText and Plain(GetZoneText())) or "Unknown zone"
end
FLJ.Zone=Zone
local function RegisterRoster()
    if not DB then return end
    wipe(groupNames); wipe(inGroup); wipe(groupUnits)
    local count = (GetNumGroupMembers and GetNumGroupMembers()) or 0
    local raid = IsInRaid and IsInRaid()
    local units={"player"}
    if count>0 then
        if raid then for i=1,count do units[#units+1]="raid"..i end
        else for i=1,count-1 do units[#units+1]="party"..i end end
    end
    for _, unit in ipairs(units) do
        if UnitExists(unit) and UnitIsPlayer(unit) then
            local nm, realm=SafeCall(UnitFullName,unit)
            if not nm then nm=SafeCall(UnitName,unit) end
            local full=nm and (realm and realm~="" and (nm.."-"..realm) or nm)
            if full then
                -- Do not collapse different realms with identical short names in the saved DB.
                RosterAlias(full,full)
                RosterAlias(nm,full)
                inGroup[Key(full)] = true
                groupUnits[Key(full)] = unit
                local _,class=SafeCall(UnitClass,unit)
                local race=SafeCall(UnitRace,unit)
                local level=SafeCall(UnitLevel,unit)
                local guild=SafeCall(GetGuildInfo,unit)
                EnsurePlayer(full,{class=class, level=level, guild=guild, race=race,zone=Zone()})
            end
        end
    end
    Notify()
end
FLJ.RegisterRoster=RegisterRoster
function FLJ.GetUnitForPlayer(name)
    local canonical = Resolve(name)
    return canonical and groupUnits[Key(canonical)] or nil
end
function FLJ.GetPlayers()
    if not DB then return {} end
    local result={}
    for pk,p in pairs(DB.players) do
        p.current = inGroup[pk] and true or false
        result[#result+1]=p
    end
    table.sort(result,function(a,b)
        if (not not a.current)~=(not not b.current) then return a.current end
        return (a.name or "")<(b.name or "")
    end)
    return result
end
function FLJ.GetRecords() return DB and DB.records or {} end
function FLJ.GetDB() return DB end
local function LatestID() DB.nextID=(DB.nextID or 0)+1; return DB.nextID end
local function SetMetadata(rec, info)
    rec.link=info.link or rec.link
    rec.name=info.name or rec.name
    rec.itemID=info.id or rec.itemID
    rec.icon=info.icon or rec.icon
    rec.quality=info.quality or rec.quality
    rec.itemLevel=info.level or rec.itemLevel
    rec.requiredLevel=info.requiredLevel or rec.requiredLevel
    rec.type=info.type or rec.type
    rec.subtype=info.subtype or rec.subtype
    rec.slot=info.slot or rec.slot
    rec.classID=info.classID or rec.classID
    local latestStats=Stats(rec.link)
    if #latestStats>0 or not rec.stats then rec.stats=latestStats end
end
local function AddRecord(info, source)
    if RegistrationAllowed(info and info.quality)~=true then return nil end
    local rec={ id=LatestID(), time=Now(), zone=Zone(), source=source or "Loot", status="Received", rolls={}}
    SetMetadata(rec,info)
    table.insert(DB.records,1,rec)
    TrimRecords()
    Notify()
    return rec
end
local function FindRecord(id)
    if not id then return nil end
    for _,r in ipairs(DB.records) do if r.id==id then return r end end
end
local function SetWinner(rec, name, class)
    if not name then return end
    name=Resolve(name)
    if not name then return end
    local p=EnsurePlayer(name,{class=class, zone=Zone()})
    if Key(rec.winner)~=Key(name) then
        -- Correct the previous owner's count if the server revises a roll winner.
        if rec.winner then
            local previous=DB.players[PlayerKey(rec.winner)]
            if previous and (previous.lootCount or 0)>0 then
                previous.lootCount=previous.lootCount-1
            end
        end
        rec.winner=name
        if p then p.lootCount=(p.lootCount or 0)+1 end
    end
end
local function RecentMatch(info,winner,seconds,requireRoll,withoutReceipt)
    local now=Now()
    for _,r in ipairs(DB.records) do
        if now-(r.time or 0) > (seconds or 15) then break end
        local sameItem=(info.id and r.itemID==info.id)
            or (type(info.link)=="string" and info.link~="" and r.link==info.link)
        if sameItem and (not winner or (r.winner and FLJ.SamePlayer(r.winner,winner)))
          and (not requireRoll or r.source=="Group roll") and (not withoutReceipt or not r.receipt) then
            return r
        end
    end
end
-- Sync.lua verifies that sender is an actual current party/raid member.
-- Locally saved source IDs ensure repeated transmissions do not double-count.
function FLJ.ReceiveSharedLoot(sender, serial, itemString, statedClass, remoteZone)
    if not DB or type(sender)~="string" or type(itemString)~="string" then return false end
    local classID=tonumber(statedClass)
    if classID~=CLASS_ARMOR and classID~=CLASS_WEAPON and not FLJ.IsCraftingItem(classID) then return false end
    local remoteID=tonumber(itemString:match("^item:(%d+)"))
    if not remoteID then return false end
    local who=Resolve(sender)
    local unique=Key(who)..":"..tostring(serial)
    for _,entry in ipairs(DB.records) do
        if entry.syncKey==unique then return false end
    end
    local info=Gear(itemString) or ItemInfo(itemString)
    if info.classID and info.classID~=classID then return false end
    local register=RegistrationAllowed(info.quality)
    if register==nil then
        -- A party member may be in another zone and the receiver may not have
        -- this item's rarity cached yet. Defer rather than guessing Common.
        if C_Item and C_Item.RequestLoadItemDataByID then
            SafeCall(C_Item.RequestLoadItemDataByID,remoteID)
        end
        if not deferredRemote[unique] then
            deferredRemote[unique]={
                sender=sender,serial=serial,itemString=itemString,
                statedClass=statedClass,remoteZone=remoteZone,time=Now(),
            }
        end
        return false
    elseif register==false then return false end
    info.id=info.id or remoteID
    info.classID=classID
    local rec=RecentMatch(info,who,6,false,false)
    if rec and rec.syncKey and rec.syncKey~=unique then rec=nil end
    if not rec then rec=AddRecord(info,"Party sync") end
    rec.syncKey=unique
    rec.receipt=true
    rec.status="Received"
    if rec.source~="Group roll" then rec.source="Party sync" end
    rec.zone=type(remoteZone)=="string" and remoteZone~="" and remoteZone or rec.zone
    SetWinner(rec,who)
    Notify()
    return true
end
local function RunDeferredRemote()
    for unique,p in pairs(deferredRemote) do
        if Now()-p.time>60 then
            deferredRemote[unique]=nil
        else
            local info=ItemInfo(p.itemString)
            if RegistrationAllowed(info.quality)~=nil then
                deferredRemote[unique]=nil
                FLJ.ReceiveSharedLoot(p.sender,p.serial,p.itemString,p.statedClass,p.remoteZone)
            end
        end
    end
end

-- Different localizations use different LOOT_* global format strings. These match only
-- actual loot receipt templates, not roll announcements and not crafted items.
local function FormatPattern(fmt)
    if type(fmt)~="string" then return nil end
    fmt=fmt:gsub("%%[%d]*%$?[sd]", "\001")
    fmt=fmt:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    return "^"..fmt:gsub("\001", "(.-)").."$"
end
local LOOT_FORMATS={
    {"LOOT_ITEM_SELF", true},{"LOOT_ITEM_SELF_MULTIPLE",true},
    {"LOOT_ITEM",false},{"LOOT_ITEM_MULTIPLE",false},
    {"LOOT_ITEM_PUSHED_SELF",true},{"LOOT_ITEM_PUSHED_SELF_MULTIPLE",true},
    {"LOOT_ITEM_PUSHED",false},{"LOOT_ITEM_PUSHED_MULTIPLE",false},
}
local patterns={}
for _,entry in ipairs(LOOT_FORMATS) do
    local pat=FormatPattern(_G[entry[1]])
    if pat then patterns[#patterns+1]={pattern=pat, self=entry[2]} end
end
local function ExtractItemLink(msg)
    if type(msg)~="string" then return nil end
    -- Retain colored hyperlink, including Forever's modern |cnIQ... wrapper.
    return msg:match("(|cnIQ%d+:[^|]*|Hitem:.-|h%[.-%]|h|r)")
       or msg:match("(|c%x%x%x%x%x%x%x%x|Hitem:.-|h%[.-%]|h|r)")
       or msg:match("(|Hitem:.-|h%[.-%]|h)")
end
local function WhoReceived(msg)
    for _,ent in ipairs(patterns) do
        local a,b,c = msg:match(ent.pattern)
        if a ~= nil then
            if ent.self then return MyName() end
            -- The first substitution in LOOT_ITEM is the receiving player's name.
            return Clean((a or ""):gsub("|Hplayer:[^|]+|h%[([^%]]+)%]|h", "%1"))
        end
    end
    return nil
end
local function TrackLootMessage(msg)
    msg=Plain(msg)
    if type(msg)~="string" then return end
    local link=ExtractItemLink(msg)
    if not link then return end
    local player=WhoReceived(msg)
    if not player then return end
    local pk=PlayerKey(player)
    local myself=Key(MyName())
    if not pk or (pk~=myself and not inGroup[pk]) then return end
    local item=Gear(link)
    if not item then
        local id=tonumber(link:match("item:(%d+)"))
        if id then deferred[#deferred+1]={link=link,player=player,time=Now()} end
        return
    end
    -- Update existing roll records even if their rarity is now excluded.
    -- New receipts obey the registration switches.
    local rec=RecentMatch(item,player,60,true,true)
    if not rec then
        local allowed=RegistrationAllowed(item.quality)
        if allowed==nil then
            if item.id and C_Item and C_Item.RequestLoadItemDataByID then
                SafeCall(C_Item.RequestLoadItemDataByID,item.id)
            end
            deferred[#deferred+1]={link=link,player=player,time=Now()}
            return
        elseif allowed==false then return end
    end
    if rec then
        rec.receipt=true; rec.status="Received"
        SetMetadata(rec,item)
        SetWinner(rec,player)
    else
        rec=AddRecord(item,"Loot message")
        if not rec then return end
        rec.receipt=true
        SetWinner(rec,player)
    end
    if pk==myself and FLJ.SendSelfLoot then FLJ.SendSelfLoot(rec) end
    Notify()
end
-- Classic/Forever chat fallback: some clients have no encounter-scoped history.
-- Only CHAT_MSG_LOOT is parsed; ordinary player chat cannot create loot records.
local rollChatPending={}
local function MatchRollFormat(format,message)
    format=Clean(format)
    if not format then return nil end
    local parts,indices={},{}
    local offset,sequence=1,0
    while true do
        local first,last,index,kind=format:find("%%(%d*)%$?([sd])",offset)
        if not first then
            parts[#parts+1]=(format:sub(offset):gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])","%%%1"))
            break
        end
        parts[#parts+1]=(format:sub(offset,first-1):gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])","%%%1"))
        sequence=sequence+1
        indices[#indices+1]=tonumber(index) or sequence
        parts[#parts+1]=kind=="d" and "(%d+)" or "(.-)"
        offset=last+1
    end
    if #indices==0 then return nil end
    local captures={message:match("^"..table.concat(parts).."$")}
    if #captures==0 then return nil end
    local values={}
    for i,index in ipairs(indices) do values[index]=captures[i] end
    return values
end
local rollFormats={
    {"LOOT_ROLL_WON","won",1},
    {"LOOT_ROLL_YOU_WON","won",0},
    {"LOOT_ROLL_ROLLED_NEED","roll",3,"Need",1},
    {"LOOT_ROLL_ROLLED_GREED","roll",3,"Greed",1},
    {"LOOT_ROLL_ROLLED_DE","roll",3,"Disenchant",1},
    {"LOOT_ROLL_NEED","choice",1,"Need"},
    {"LOOT_ROLL_GREED","choice",1,"Greed"},
    {"LOOT_ROLL_DISENCHANT","choice",1,"Disenchant"},
    {"LOOT_ROLL_PASSED","choice",1,"Pass"},
    {"LOOT_ROLL_NEED_SELF","choice",0,"Need"},
    {"LOOT_ROLL_GREED_SELF","choice",0,"Greed"},
    {"LOOT_ROLL_DISENCHANT_SELF","choice",0,"Disenchant"},
    {"LOOT_ROLL_PASSED_SELF","choice",0,"Pass"},
    {"LOOT_ROLL_ALL_PASSED","passed"},
}
local function ParseRollMessage(message)
    message=Clean(message)
    if not message then return nil end
    local link=ExtractItemLink(message)
    if not link then return nil end
    for _,format in ipairs(rollFormats) do
        local args=MatchRollFormat(_G[format[1]],message)
        if args then
            return {link=link,kind=format[2],player=format[3]==0 and MyName() or args[format[3]],
                action=format[4],value=format[5] and tonumber(args[format[5]])}
        end
    end
    -- Exact English forms used by Forever, even if its globals use another form.
    local first,last=message:find("|Hitem:.-|h%[.-%]|h")
    if not first then return nil end
    local text=(message:sub(1,first-1).."\001"..message:sub(last+1)):lower()
    text=text:gsub("^%[loot%]%s*:%s*","")
    local player=text:match("^(.-) won:%s*\001%.?$") or text:match("^(.-) won%s+\001%.?$")
    if player then return {link=link,kind="won",player=player=="you" and MyName() or player} end
    for _,action in ipairs({"Need","Greed","Disenchant"}) do
        local number,name=text:match("^"..action:lower().." roll %- (%d+) for \001 by (.-)%.?$")
        if not number then number,name=text:match("^"..action:lower().." roll of (%d+) for \001 by (.-)%.?$") end
        if number then return {link=link,kind="roll",player=name,action=action,value=tonumber(number)} end
        if text:match("^you have selected "..action:lower().." for:%s*\001%.?$") then
            return {link=link,kind="choice",player=MyName(),action=action}
        end
        name=text:match("^(.-) has selected "..action:lower().." for:%s*\001%.?$")
        if name then return {link=link,kind="choice",player=name,action=action} end
    end
    player=text:match("^(.-) passed on:%s*\001%.?$")
    if player then return {link=link,kind="choice",player=player=="you" and MyName() or player,action="Pass"} end
    if text:match("^everyone passed on:%s*\001%.?$") then return {link=link,kind="passed"} end
end
local function SameDrop(record,info)
    local a=record.link and (record.link:match("|H(item:[^|]+)|h") or record.link:match("^(item:[^|%s]+)"))
    local b=info.link and (info.link:match("|H(item:[^|]+)|h") or info.link:match("^(item:[^|%s]+)"))
    if a and b then return a==b end
    return info.id and record.itemID==info.id
end
local function FindChatRecord(info,data)
    for _,record in ipairs(DB.records) do
        local age=Now()-(record.time or 0)
        if age>180 then break end
        if SameDrop(record,info) then
            if not record.winner and record.status~="All passed" and record.source=="Group roll" then return record end
            if record.source=="Group roll" then
                if data.kind=="won" and age<=8 and FLJ.SamePlayer(record.winner,data.player) then return record end
                if data.kind=="roll" and age<=2 then
                    for _,roll in ipairs(record.rolls or {}) do
                        if FLJ.SamePlayer(roll.name,data.player) and
                            (roll.value==data.value or (roll.value==nil and not record.receipt)) then return record end
                    end
                end
            end
            if record.source~="Group roll" and data.kind=="won" and age<=25 and FLJ.SamePlayer(record.winner,data.player) then return record end
        end
    end
end
local function ApplyRollChat(data)
    if not DB then return true end
    if data.player and not data.authorized then
        data.player=Resolve(data.player)
        local pk=PlayerKey(data.player)
        if not pk or (not inGroup[pk] and not FLJ.SamePlayer(data.player,MyName())) then
            RegisterRoster()
            data.player=Resolve(data.player);pk=PlayerKey(data.player)
            if not pk or (not inGroup[pk] and not FLJ.SamePlayer(data.player,MyName())) then return true end
        end
        data.authorized=true
    end
    local info=Gear(data.link)
    if not info then return false end
    local record=FindChatRecord(info,data)
    if not record then
        local allowed=RegistrationAllowed(info.quality)
        if allowed==nil then
            if info.id and C_Item and C_Item.RequestLoadItemDataByID then SafeCall(C_Item.RequestLoadItemDataByID,info.id) end
            return false
        elseif allowed==false then return true end
        record=AddRecord(info,"Group roll")
        if not record then return true end
        record.status="Rolling"
    end
    record.source="Group roll"
    record.chatRoll=true
    SetMetadata(record,info)
    record.rolls=record.rolls or {}
    if data.kind=="passed" then
        if not record.winner then record.status="All passed" end
    else
        local entry
        for _,roll in ipairs(record.rolls) do if FLJ.SamePlayer(roll.name,data.player) then entry=roll;break end end
        if not entry then
            local player=EnsurePlayer(data.player)
            entry={name=data.player,class=player and player.class}
            record.rolls[#record.rolls+1]=entry
        end
        if data.action then entry.action=data.action end
        if data.value then entry.value=data.value end
        if data.kind=="won" then
            SetWinner(record,data.player,entry.class)
            record.status="Won"
            for _,roll in ipairs(record.rolls) do roll.winner=FLJ.SamePlayer(roll.name,record.winner) end
            entry.action=entry.action or "Winner"
        end
    end
    Notify()
    return true
end
local function TrackRollMessage(message)
    message=Plain(message)
    local data=type(message)=="string" and ParseRollMessage(message)
    if data and not ApplyRollChat(data) then rollChatPending[#rollChatPending+1]={data=data,time=Now()} end
end
local function RunRollChatDeferred()
    local pending=rollChatPending
    rollChatPending={}
    for _,entry in ipairs(pending) do
        if Now()-entry.time<60 and not ApplyRollChat(entry.data) then rollChatPending[#rollChatPending+1]=entry end
    end
end

local function RunDeferred()
    if not DB then return end
    RunRollChatDeferred()
    if #deferred==0 then return end
    local pending=deferred; deferred={}
    for _,p in ipairs(pending) do
        if Now()-(p.time or 0)<60 then
            local info=Gear(p.link)
            if info then
                local rec=RecentMatch(info,p.player,60,true,true)
                if not rec then
                    local allowed=RegistrationAllowed(info.quality)
                    if allowed==nil then
                        deferred[#deferred+1]=p
                    elseif allowed==true then
                        rec=AddRecord(info,"Loot message")
                    end
                end
                if rec then
                    rec.receipt=true; rec.status="Received"
                    SetMetadata(rec,info); SetWinner(rec,p.player)
                    if Key(Resolve(p.player))==Key(MyName()) and FLJ.SendSelfLoot then
                        FLJ.SendSelfLoot(rec)
                    end
                end
            else deferred[#deferred+1]=p end
        end
    end
    Notify()
end
local ROLL_STATE = Enum and Enum.EncounterLootDropRollState
local ROLL_NAME={
    [(ROLL_STATE and ROLL_STATE.NeedMainSpec) or 0]="Need",
    [(ROLL_STATE and ROLL_STATE.NeedOffSpec) or 1]="Need (off-spec)",
    [(ROLL_STATE and ROLL_STATE.Transmog) or 2]="Transmog",
    [(ROLL_STATE and ROLL_STATE.Greed) or 3]="Greed",
    [(ROLL_STATE and ROLL_STATE.NoRoll) or 4]="Waiting",
    [(ROLL_STATE and ROLL_STATE.Pass) or 5]="Pass",
}
local function ProcessHistory(encounterID,lootListKey)
    if not DB or not (C_LootHistory and C_LootHistory.GetSortedInfoForDrop) then return false end
    encounterID=Plain(encounterID); lootListKey=Plain(lootListKey)
    if encounterID==nil or lootListKey==nil then return false end
    local drop=SafeCall(C_LootHistory.GetSortedInfoForDrop,encounterID,lootListKey)
    if type(drop)~="table" then return false end
    local link=Plain(drop.itemHyperlink)
    if type(link)~="string" then return false end
    local item=Gear(link)
    if not item then return false end
    local sessionKey=tostring(encounterID)..":"..tostring(lootListKey)
    local rec=FindRecord(recentRolls[sessionKey])
    if not rec then
        -- If the winner was already in the chat before the LootHistory event fired,
        -- reuse that recent receipt instead of creating a duplicate row.
        local win=type(drop.winner)=="table" and (Plain(drop.winner.playerName) or (Plain(drop.winner.isSelf) and MyName()))
        rec=RecentMatch(item,win,25,false,false)
        if not rec or (rec.rollSession and rec.rollSession~=sessionKey) then
            local allowed=RegistrationAllowed(item.quality)
            if allowed~=true then
                if allowed==nil and item.id and C_Item and C_Item.RequestLoadItemDataByID then
                    SafeCall(C_Item.RequestLoadItemDataByID,item.id)
                end
                return allowed==false
            end
            rec=AddRecord(item,"Group roll")
            if not rec then return true end
        end
        recentRolls[sessionKey]=rec.id
        rec.rollSession=sessionKey
        rec.source="Group roll"
    end
    SetMetadata(rec,item)
    if type(drop.rollInfos)=="table" and #drop.rollInfos>0 then rec.rolls={} else rec.rolls=rec.rolls or {} end
    local seenNames={}
    if type(drop.rollInfos)=="table" then
        for _,raw in ipairs(drop.rollInfos) do
            local name=Plain(raw.playerName) or (Plain(raw.isSelf) and MyName())
            local cls=Plain(raw.playerClass)
            if name then
                name=Resolve(name)
                EnsurePlayer(name,{class=cls})
                local state=Plain(raw.state)
                local entry={name=name, class=cls, action=ROLL_NAME[state] or "Unknown",
                    value=Plain(raw.roll), winner=Plain(raw.isWinner)==true}
                rec.rolls[#rec.rolls+1]=entry
                seenNames[Key(name)]=true
            end
        end
    end
    if type(drop.winner)=="table" then
        local w=drop.winner
        local win=Plain(w.playerName) or (Plain(w.isSelf) and MyName())
        if win then
            SetWinner(rec,win,Plain(w.playerClass))
            local hasWinner=false
            for _,r in ipairs(rec.rolls) do
                if Key(r.name)==Key(Resolve(win)) then r.winner=true; hasWinner=true end
            end
            if not hasWinner then
                rec.rolls[#rec.rolls+1]={name=Resolve(win),class=Plain(w.playerClass),action=ROLL_NAME[Plain(w.state)] or "Winner",
                    value=Plain(w.roll),winner=true}
            end
            rec.status="Won"
        end
    elseif Plain(drop.allPassed)==true then
        rec.status="All passed"
    else
        rec.status=rec.winner and "Won" or "Rolling"
    end
    if #rec.rolls==0 and rec.winner==nil and rec.status=="Rolling" then
        -- A roll can arrive before the first choice; leave status as Rolling.
    end
    if rec.winner and Key(Resolve(rec.winner))==Key(MyName()) and FLJ.SendSelfLoot then
        FLJ.SendSelfLoot(rec)
    end
    Notify()
    return true
end
local function ScanEncounter(encounterID, onlyActive)
    if not (C_LootHistory and C_LootHistory.GetSortedDropsForEncounter) then return end
    local drops=SafeCall(C_LootHistory.GetSortedDropsForEncounter,encounterID)
    if type(drops)~="table" then return end
    for _,drop in ipairs(drops) do
        local key=Plain(drop.lootListKey)
        if key~=nil and (not onlyActive or (not drop.winner and Plain(drop.allPassed)~=true)) then
            ProcessHistory(encounterID,key)
        end
    end
end
local function ScanActive()
    if not (C_LootHistory and C_LootHistory.GetAllEncounterInfos) then return end
    local encounters=SafeCall(C_LootHistory.GetAllEncounterInfos)
    if type(encounters)~="table" then return end
    for _,enc in ipairs(encounters) do
        if enc.encounterID then ScanEncounter(Plain(enc.encounterID),true) end
    end
end
local function RetryUpdate(enc,key)
    if enc==nil or key==nil then return end
    local token=tostring(enc)..":"..tostring(key)
    if retries[token] then return end
    retries[token]=true
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5,function()
            if not ProcessHistory(enc,key) then
                C_Timer.After(1.5,function() ProcessHistory(enc,key) end)
            end
            retries[token]=nil
        end)
    end
end
function FLJ.ClearRecords()
    if not DB then return end
    wipe(DB.records); wipe(recentRolls); wipe(deferredRemote); wipe(deferred); wipe(rollChatPending)
    for _,p in pairs(DB.players) do p.lootCount=0 end
    Notify()
end
function FLJ.ClearAll()
    FLJ.ClearRecords()
    wipe(DB.players)
    RegisterRoster()
end
local f=CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("CHAT_MSG_LOOT")
f:RegisterEvent("LOOT_HISTORY_UPDATE_DROP")
f:RegisterEvent("LOOT_HISTORY_UPDATE_ENCOUNTER")
f:RegisterEvent("LOOT_ROLLS_COMPLETE")
f:RegisterEvent("START_LOOT_ROLL")
f:RegisterEvent("ITEM_DATA_LOAD_RESULT")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_LEVEL_UP")
f:SetScript("OnEvent",function(_,event,a,b,c)
    if event=="ADDON_LOADED" then
        if a~=addonName then return end
        if type(ForeverLootJournalDB)~="table" then ForeverLootJournalDB={} end
        DB=ForeverLootJournalDB
        DB.records=type(DB.records)=="table" and DB.records or {}
        DB.players=type(DB.players)=="table" and DB.players or {}
        DB.nextID=tonumber(DB.nextID) or 0
        DB.ui=type(DB.ui)=="table" and DB.ui or {}
        if not STORAGE_PRESETS[DB.ui.storagePreset] then
            DB.ui.storagePreset=DEFAULT_PRESET
        end
        TrimRecords()
        initialized=true
        return
    end
    if not initialized then return end
    if event=="PLAYER_ENTERING_WORLD" then
        RegisterRoster()
        if C_Timer and C_Timer.After then C_Timer.After(2,ScanActive) end
    elseif event=="GROUP_ROSTER_UPDATE" or event=="PLAYER_LEVEL_UP" then
        RegisterRoster()
    elseif event=="CHAT_MSG_LOOT" then
        TrackRollMessage(a)
        TrackLootMessage(a)
    elseif event=="LOOT_HISTORY_UPDATE_DROP" then
        if not ProcessHistory(a,b) then RetryUpdate(Plain(a),Plain(b)) end
    elseif event=="LOOT_HISTORY_UPDATE_ENCOUNTER" then
        if a~=nil then ScanEncounter(Plain(a),false) end
    elseif event=="START_LOOT_ROLL" then
        -- The third event argument is the lootListKey. Encounter ID is not given.
        -- The encounter-scoped history update links the roll to its participants.
        if C_Timer and C_Timer.After then C_Timer.After(0.3,ScanActive) end
    elseif event=="LOOT_ROLLS_COMPLETE" then
        if C_Timer and C_Timer.After then C_Timer.After(0.3,ScanActive) end
    elseif event=="ITEM_DATA_LOAD_RESULT" then
        -- Enrich old records when the item cache finishes loading, even after a
        -- roll has already completed and the initial tooltip stats were empty.
        local loadedItemID=Plain(a)
        if loadedItemID and Plain(b) ~= false then
            for _,rec in ipairs(DB.records) do
                if rec.itemID==loadedItemID then
                    local info=Gear(rec.link or loadedItemID)
                    if info then SetMetadata(rec,info) end
                end
            end
        end
        RunDeferred(); RunDeferredRemote(); Notify()
    elseif event=="PLAYER_REGEN_ENABLED" then
        RunDeferred(); ScanActive()
    end
end)
if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(2,function()
        if initialized then RunDeferred(); RunDeferredRemote() end
    end)
end
SLASH_FOREVERLOOTJOURNAL1="/flj"
SLASH_FOREVERLOOTJOURNAL2="/foreverloot"
SlashCmdList.FOREVERLOOTJOURNAL=function(msg)
    msg=(msg or ""):lower():match("^%s*(.-)%s*$")
    if msg=="" or msg=="show" then
        FLJ.Toggle()
    elseif msg=="clear" then
        if FLJ.ShowClearConfirm then FLJ.ShowClearConfirm() end
    elseif msg=="players" then
        FLJ.Toggle(true)
    elseif msg=="refresh" then
        RegisterRoster(); ScanActive(); print("|cffffd76aForever Loot Journal:|r group and loot history refreshed.")
    elseif msg=="help" then
        print("|cffffd76aForever Loot Journal|r: /flj (open), /flj players, /flj refresh, /flj clear")
    else
        print("|cffffd76aForever Loot Journal|r: unknown command. Use /flj help")
    end
end

