-- Forever Loot Journal 1.1.4 - World of Warcraft: Forever (interface 16001)
-- Account-wide saved loot archive; no communication with other addons or players.
local addonName, FLJ = ...
_G.ForeverLootJournal = FLJ
local DB
local recentRolls = {}    -- session-scoped (encounterID:lootListKey -> record ID)
local deferred = {}       -- items whose item data is still being loaded
local retries = {}        -- delayed history updates
local groupNames = {}     -- case-folded full/short name -> canonical player key
local inGroup = {}        -- canonical player key -> true
local groupUnits = {}     -- canonical player key -> live unit token (not persisted)
local initialized = false
local initializingUI = false
local MAX_RECORDS = 5000
local CLASS_ARMOR, CLASS_WEAPON = 4, 2
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
        link=fullLink or link, name=name or "Unknown item", quality=rarity or (type(link)=="string" and tonumber(link:match("|cnIQ(%d+)"))) or 1,
        level=lvl, requiredLevel=req, type=typ or instantTyp, subtype=sub or instantSub,
        slot=loc or instantLoc, icon=icon or instantIcon or "Interface\\Icons\\INV_Misc_QuestionMark",
        classID=classID or instantClass, subclassID=subID or instantSubID,
    }
end
local function Gear(link)
    local item=ItemInfo(link)
    if item.classID == CLASS_ARMOR or item.classID == CLASS_WEAPON then
        -- Armor class includes equippable rings/trinkets/shields; hide none of the equippable gear.
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
    local low=Key(name)
    return groupNames[low] or (not name:find("-",1,true) and groupNames[Key(ShortName(name))]) or name
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
                groupNames[Key(full)] = full
                if not groupNames[Key(nm)] then groupNames[Key(nm)] = full end
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
    local rec={ id=LatestID(), time=Now(), zone=Zone(), source=source or "Loot", status="Received", rolls={}}
    SetMetadata(rec,info)
    table.insert(DB.records,1,rec)
    if #DB.records>MAX_RECORDS then
        for i=#DB.records,MAX_RECORDS+1,-1 do table.remove(DB.records,i) end
    end
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
        if sameItem and (not winner or (r.winner and Key(ShortName(r.winner))==Key(ShortName(winner))))
          and (not requireRoll or r.source=="Group roll") and (not withoutReceipt or not r.receipt) then
            return r
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
    -- The roll event knows all players and precise roll values. Attach this receipt to
    -- that record instead of displaying the same drop twice.
    local rec=RecentMatch(item,player,60,true,true)
    if rec then
        rec.receipt=true; rec.status="Received"
        SetMetadata(rec,item)
        SetWinner(rec,player)
    else
        rec=AddRecord(item,"Loot message")
        rec.receipt=true
        SetWinner(rec,player)
    end
    Notify()
end
local function RunDeferred()
    if not DB or #deferred==0 then return end
    local pending=deferred; deferred={}
    for _,p in ipairs(pending) do
        if Now()-(p.time or 0)<12 then
            local info=Gear(p.link)
            if info then
                local existing=RecentMatch(info,p.player,60,true,true)
                if existing then
                    existing.receipt=true; existing.status="Received"
                    SetMetadata(existing,info); SetWinner(existing,p.player)
                else
                    local rec=AddRecord(info,"Loot message")
                    rec.receipt=true; SetWinner(rec,p.player)
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
        if not rec or (rec.rollSession and rec.rollSession~=sessionKey) then rec=AddRecord(item,"Group roll") end
        recentRolls[sessionKey]=rec.id
        rec.rollSession=sessionKey
        rec.source="Group roll"
    end
    SetMetadata(rec,item)
    rec.rolls={}
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
        rec.status="Rolling"
    end
    if #rec.rolls==0 and rec.winner==nil and rec.status=="Rolling" then
        -- A roll can arrive before the first choice; leave status as Rolling.
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
    wipe(DB.records); wipe(recentRolls)
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
        RunDeferred(); Notify()
    elseif event=="PLAYER_REGEN_ENABLED" then
        RunDeferred(); ScanActive()
    end
end)
if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(2,function() if initialized then RunDeferred() end end)
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
