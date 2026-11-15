-- Forever Loot Journal v1.2.7 - WoW Forever social menu.
-- Uses the live WoW ignore list, not a parallel addon-maintained block list.
local addonName, FLJ = ...
local Social={}
FLJ.Social=Social

local function Notice(message)
    if type(print)=="function" then
        print("|cffffd76aForever Loot Journal:|r "..tostring(message))
    end
end

local function SafeQuery(fn,...)
    if type(fn)~="function" then return nil end
    local ok,result=pcall(fn,...)
    if ok then return result end
    return nil
end

local function PlayerName(player)
    local name=type(player)=="table" and player.name or nil
    if type(name)~="string" then return nil end
    name=name:match("^%s*(.-)%s*$")
    if name=="" or #name>96 or name:find("[%c|/]") then return nil end
    return name
end

local function OwnName()
    local name,realm
    if type(UnitFullName)=="function" then name,realm=UnitFullName("player") end
    if not name and type(UnitName)=="function" then name=UnitName("player") end
    if type(name)~="string" or name=="" then return nil end
    if type(realm)=="string" and realm~="" then return name.."-"..realm end
    return name
end

local function IsSelf(name)
    local own=OwnName()
    if not own or not name then return false end
    if own:lower()==name:lower() then return true end
    if not name:find("-",1,true) then
        return (own:match("^([^-]+)") or own):lower()==name:lower()
    end
    return false
end

local function Normal(s)
    if type(s)~="string" then return nil end
    return s:match("^%s*(.-)%s*$"):lower():gsub("%s+","")
end

-- Short form is accepted only when at least one name has no specified realm.
-- Two explicit but different realms must NOT be treated as the same character.
local function SameCharacterName(a,b)
    if type(a)~="string" or type(b)~="string" then return false end
    local rawA,rawB=a:lower(),b:lower()
    a,b=Normal(a),Normal(b)
    if not a or not b then return false end
    if a==b then return true end
    -- The game's confirmation messages can display Saint-Ramz as "Saint Ramz".
    -- Compare that format without treating different explicit realms as equal.
    if rawA:find("[%s%-]") and rawB:find("[%s%-]") and
       a:gsub("%-","")==b:gsub("%-","") then
        return true
    end
    local an,ar=a:match("^([^-]+)%-(.+)$")
    local bn,br=b:match("^([^-]+)%-(.+)$")
    an=an or a
    bn=bn or b
    return an==bn and (not ar or not br)
end

local lastRefresh
local pendingActions={}
local confirmedActions={}
local function Clock()
    local n=SafeQuery(GetTime)
    if type(n)=="number" then return n end
    n=SafeQuery(time)
    return type(n)=="number" and n or 0
end

local function KnownAction(name)
    local now=Clock()
    for key,entry in pairs(confirmedActions) do
        if now-entry.at>180 then confirmedActions[key]=nil
        elseif SameCharacterName(key,name) then return entry end
    end
    return nil
end

local function PendingAction(name)
    local now=Clock()
    for key,entry in pairs(pendingActions) do
        if now-entry.at>20 then pendingActions[key]=nil
        elseif SameCharacterName(key,name) then return entry end
    end
    return nil
end

local function EscapePattern(value)
    return (value:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])","%%%1"))
end

local function ServerCharacter(template,message)
    if type(template)~="string" or type(message)~="string" then return nil end
    local before,after=template:match("^(.-)%%s(.-)$")
    if not before then return nil end
    return message:match("^"..EscapePattern(before).."(.+)"..EscapePattern(after).."$")
end

local function ServerIgnoreConfirmation(message)
    local name=ServerCharacter(ERR_IGNORE_ADDED_S or "%s is now being ignored.",message)
    local blocked
    if name then
        blocked=true
    else
        name=ServerCharacter(ERR_IGNORE_REMOVED_S or "%s is no longer being ignored.",message)
        if name then blocked=false end
    end
    if not name then return end
    -- A real WoW server confirmation has priority over a stale friend-list
    -- snapshot. Never treat merely calling AddIgnore as confirmation.
    local now=Clock()
    for key in pairs(pendingActions) do
        if SameCharacterName(key,name) then pendingActions[key]=nil end
    end
    confirmedActions[name]={blocked=blocked,at=now}
end

function Social.RefreshIgnoreList(force)
    local api=C_FriendList
    local refresh=(api and api.ShowFriends) or ShowFriends
    if type(refresh)~="function" then return false end
    local now=Clock()
    if not force and lastRefresh and now-lastRefresh<20 then return true end
    local ok=pcall(refresh)
    if ok then lastRefresh=now end
    return ok
end

local function DirectStatus(name,player)
    local api=C_FriendList
    local foundResult=false
    local tokens={name}
    local short=type(name)=="string" and name:match("^([^-]+)%-")
    if short then tokens[#tokens+1]=short end
    if player and FLJ.GetUnitForPlayer then
        local unit=SafeQuery(FLJ.GetUnitForPlayer,name)
        if type(unit)=="string" then tokens[#tokens+1]=unit end
    end
    local checkers={}
    -- Never pass an array containing holes to ipairs: its first nil stops
    -- iteration and skips the remaining working APIs on some WoW clients.
    local function AddChecker(fn)
        if type(fn)=="function" then checkers[#checkers+1]=fn end
    end
    AddChecker(api and api.IsIgnored)
    AddChecker(api and api.IsOnIgnoredList)
    AddChecker(IsIgnored)
    for _,token in ipairs(tokens) do
        for _,fn in ipairs(checkers) do
            local result=SafeQuery(fn,token)
            if result==true then return true,token end
            if result==false then foundResult=true end
        end
    end
    local guid=player and player.guid
    if not guid and player and FLJ.GetUnitForPlayer and type(UnitGUID)=="function" then
        local unit=SafeQuery(FLJ.GetUnitForPlayer,name)
        if type(unit)=="string" then guid=SafeQuery(UnitGUID,unit) end
    end
    if type(guid)=="string" and type(api and api.IsIgnoredByGuid)=="function" then
        local result=SafeQuery(api.IsIgnoredByGuid,guid)
        if result==true then return true,name end
        if result==false then foundResult=true end
    end
    if foundResult then return false,nil end
    return nil,nil
end

-- Results: true/false/nil (nil = the client's ignore state is unverified),
-- the actual name stored by WoW, and its ignore-list index if available.
function Social.ResolveIgnore(name,player)
    if type(name)~="string" or name=="" then return nil end
    local api=C_FriendList
    local count=SafeQuery(api and api.GetNumIgnores)
    if count==nil then count=SafeQuery(GetNumIgnores) end
    local getName=(api and api.GetIgnoreName) or GetIgnoreName
    local canEnumerate=type(count)=="number" and type(getName)=="function"
    local complete=canEnumerate
    if canEnumerate then
        for i=1,math.min(50,math.max(0,count)) do
            local ignored=SafeQuery(getName,i)
            if type(ignored)=="table" then ignored=ignored.name end
            if type(ignored)=="string" and ignored~="" then
                if SameCharacterName(ignored,name) then
                    return true,ignored,i
                end
            else
                -- Do not infer "not blocked" from an unloaded/partial list.
                complete=false
            end
        end
    end
    local direct,token=DirectStatus(name,player)
    local confirmed=KnownAction(name)
    if confirmed and confirmed.blocked then
        return true,confirmed.name or name,nil
    end
    if direct==true and not (confirmed and not confirmed.blocked) then
        return true,token,nil
    end
    if PendingAction(name) then return nil,nil,nil end
    if confirmed and not confirmed.blocked then return false,nil,nil end
    if complete or direct==false then return false,nil,nil end
    return nil,nil,nil
end

function Social.FindIgnoredName(name)
    local ignored,entry=Social.ResolveIgnore(name)
    return ignored==true and entry or nil
end

function Social.IsIgnored(name)
    local status=Social.ResolveIgnore(name)
    return status==true
end

function Social.IsFriend(name)
    local api=C_FriendList and C_FriendList.GetFriendInfo
    return type(SafeQuery(api,name))=="table"
end

function Social.CanPartyInvite(player)
    if not PlayerName(player) or IsSelf(player.name) or player.current then return false end
    if C_PartyInfo and type(C_PartyInfo.CanInvite)=="function" then
        return SafeQuery(C_PartyInfo.CanInvite)==true
    end
    return true
end

function Social.CanGuildInvite(player)
    if not PlayerName(player) or IsSelf(player.name) then return false end
    if type(IsInGuild)=="function" and not SafeQuery(IsInGuild) then return false end
    if type(CanGuildInvite)=="function" and not SafeQuery(CanGuildInvite) then return false end
    return true
end

local function Perform(action,fn,name)
    if type(fn)~="function" then
        Notice(action.." is not supported by this WoW client.")
        return false
    end
    local ok,result=pcall(fn,name)
    if not ok then
        Notice(action.." could not be completed; check game permissions.")
        return false
    end
    if result==false then
        Notice(action.." was rejected by WoW.")
        return false
    end
    return true
end

function Social.Whisper(player)
    local name=PlayerName(player)
    if not name or IsSelf(name) then return false end
    if type(ChatFrame_SendTell)=="function" then
        return Perform("Whisper",ChatFrame_SendTell,name)
    end
    if type(ChatFrame_OpenChat)=="function" then
        return Perform("Whisper",function(target)
            ChatFrame_OpenChat("/w "..target.." ")
        end,name)
    end
    Notice("Whisper is unavailable.")
    return false
end

function Social.AddFriend(player)
    local name=PlayerName(player)
    if not name or IsSelf(name) or Social.IsFriend(name) then return false end
    local fn=(C_FriendList and C_FriendList.AddFriend) or AddFriend
    return Perform("Add Friend",fn,name)
end

function Social.ToggleIgnore(player)
    local name=PlayerName(player)
    if not name or IsSelf(name) then return false end
    local blocked,stored,index=Social.ResolveIgnore(name,player)
    if PendingAction(name) then
        Notice("Waiting for WoW to confirm the previous ignore-list request.")
        return false
    end
    if blocked==true then
        local api=C_FriendList
        local ok
        if index and api and type(api.DelIgnoreByIndex)=="function" then
            ok=Perform("Unblock",api.DelIgnoreByIndex,index)
        else
            ok=Perform("Unblock",(api and api.DelIgnore) or DelIgnore,stored or name)
        end
        if ok then pendingActions[name]={at=Clock(),blocked=false} end
        return ok
    elseif blocked==false then
        local api=C_FriendList
        local ok=Perform("Block",(api and api.AddIgnore) or AddIgnore,name)
        if ok then pendingActions[name]={at=Clock(),blocked=true} end
        return ok
    end
    Notice("Ignore list not loaded. Refresh the list, then right-click again.")
    Social.RefreshIgnoreList(true)
    return false
end

function Social.InviteParty(player)
    local name=PlayerName(player)
    if not name or not Social.CanPartyInvite(player) then return false end
    return Perform("Party invite",(C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit,name)
end

function Social.InviteGuild(player)
    local name=PlayerName(player)
    if not name or not Social.CanGuildInvite(player) then return false end
    return Perform("Guild invite",(C_GuildInfo and C_GuildInfo.Invite) or GuildInvite,name)
end

local function MenuOption(root,label,enabled,callback)
    local item=root:CreateButton(label,callback)
    if not enabled and item and type(item.SetEnabled)=="function" then
        item:SetEnabled(false)
    end
    return item
end

function FLJ.ShowPlayerContextMenu(owner,player)
    local name=PlayerName(player)
    if not name or not owner then return false end
    if not MenuUtil or type(MenuUtil.CreateContextMenu)~="function" then
        Notice("Player context menus are not available on this client.")
        return false
    end
    -- The game keeps its Ignore list current. Do not send ShowFriends()
    -- every time a player is right-clicked; repeated requests can race.
    MenuUtil.CreateContextMenu(owner,function(_,root)
        root:CreateTitle(name)
        local selfTarget=IsSelf(name)
        MenuOption(root,"Whisper",not selfTarget,function()
            Social.Whisper(player)
        end)
        local friend=Social.IsFriend(name)
        MenuOption(root,friend and "Already Friends" or "Add Friend",
            not selfTarget and not friend,function()
                Social.AddFriend(player)
            end)
        local status=Social.ResolveIgnore(name,player)
        if status==nil then
            MenuOption(root,PendingAction(name) and "Waiting for Ignore Response" or "Refresh Ignore Status",
                not selfTarget and not PendingAction(name),function()
                    Social.RefreshIgnoreList(true)
                    Notice("Ignore list refresh requested. Right-click the player again.")
                end)
        else
            MenuOption(root,status and "Unblock Player" or "Block Player (Ignore)",
                not selfTarget,function()
                    Social.ToggleIgnore(player)
                end)
        end
        if type(root.CreateDivider)=="function" then root:CreateDivider() end
        MenuOption(root,"Invite to Party",Social.CanPartyInvite(player),function()
            Social.InviteParty(player)
        end)
        MenuOption(root,"Invite to Guild",Social.CanGuildInvite(player),function()
            Social.InviteGuild(player)
        end)
    end)
    return true
end

-- Diagnostic for a client whose ignore-list API does not return current data.
-- Prints only the requested character, not the player's entire Ignore list.
function Social.IgnoreStatus(name)
    if type(name)~="string" or name=="" then
        Notice("Usage: /flj ignorestatus Character-Realm")
        return
    end
    local api=C_FriendList
    local ignored,stored,index=Social.ResolveIgnore(name)
    local count=SafeQuery(api and api.GetNumIgnores)
    local primary=SafeQuery(api and api.IsIgnored,name)
    local secondary=SafeQuery(api and api.IsOnIgnoredList,name)
    local short=name:match("^([^-]+)%-")
    local shortIgnored=short and SafeQuery(api and api.IsIgnored,short)
    Notice("Ignore check "..name..
        ": status="..(ignored==nil and "unknown" or tostring(ignored))..
        ", entries="..tostring(count)..
        ", IsIgnored="..tostring(primary)..
        ", IsOnIgnoredList="..tostring(secondary)..
        ", shortName="..tostring(shortIgnored)..
        ", match="..tostring(stored)..
        ", index="..tostring(index))
end

local priorSlash=SlashCmdList and SlashCmdList.FOREVERLOOTJOURNAL
if priorSlash then
    SlashCmdList.FOREVERLOOTJOURNAL=function(message)
        local args=tostring(message or ""):match("^%s*(.-)%s*$")
        local name=args:match("^ignorestatus%s+(.+)$")
        if args=="ignorestatus" then
            Notice("Usage: /flj ignorestatus Character-Realm")
        elseif name then
            Social.RefreshIgnoreList(true)
            Social.IgnoreStatus(name)
        else
            priorSlash(message)
            if args=="help" then
                Notice("Ignore diagnostics: /flj ignorestatus Character-Realm")
            end
        end
    end
end

-- Request WoW's friends/ignore data and listen for server-side ignore changes.
-- Never create a separate, potentially incorrect addon block database.
local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("IGNORELIST_UPDATE")
events:RegisterEvent("FRIENDLIST_UPDATE")
events:RegisterEvent("CHAT_MSG_SYSTEM")
events:SetScript("OnEvent",function(_,event,message)
    if event=="PLAYER_LOGIN" then
        Social.RefreshIgnoreList(true)
    elseif event=="CHAT_MSG_SYSTEM" then
        ServerIgnoreConfirmation(message)
    elseif event=="IGNORELIST_UPDATE" then
        -- Ignore updates are authoritative; the next context menu reads fresh.
        lastRefresh=nil
    end
end)
