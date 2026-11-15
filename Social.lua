-- Forever Loot Journal v1.2.5: WoW Forever social actions for stored players.
-- All modifications are triggered by explicit clicks in the Blizzard context menu.
local addonName, FLJ = ...
local Social={}
FLJ.Social=Social

local function Notice(message)
    if type(print)=="function" then
        print("|cffffd76aForever Loot Journal:|r "..tostring(message))
    end
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
    -- A short name is safe to compare only when the other name has no realm.
    if not name:find("-",1,true) then
        return (own:match("^([^-]+)") or own):lower()==name:lower()
    end
    return false
end

local function SafeQuery(fn,...)
    if type(fn)~="function" then return nil end
    local ok,result=pcall(fn,...)
    return ok and result or nil
end

-- Ignore entries sometimes use a name-realm variant that differs from the
-- player name saved in the journal. Inspect Blizzard's actual ignore list
-- before falling back to the direct name lookup.
local function SameCharacterName(a,b)
    if type(a)~="string" or type(b)~="string" then return false end
    a=a:match("^%s*(.-)%s*$"):lower()
    b=b:match("^%s*(.-)%s*$"):lower()
    if a==b then return true end
    local aName,aRealm=a:match("^([^-]+)%-(.+)$")
    local bName,bRealm=b:match("^([^-]+)%-(.+)$")
    aName=aName or a
    bName=bName or b
    return aName==bName and (not aRealm or not bRealm or aRealm==bRealm)
end

function Social.FindIgnoredName(name)
    if type(name)~="string" or name=="" then return nil end
    local api=C_FriendList
    local count=SafeQuery(api and api.GetNumIgnores)
    if count==nil then count=SafeQuery(GetNumIgnores) end
    local getName=(api and api.GetIgnoreName) or GetIgnoreName
    if type(count)=="number" and type(getName)=="function" then
        for index=1,math.min(50,math.max(0,count)) do
            local entry=SafeQuery(getName,index)
            if type(entry)=="table" then entry=entry.name end
            if SameCharacterName(entry,name) then
                return entry -- use exactly the name recorded by WoW
            end
        end
    end
    local check=(api and api.IsIgnored) or (api and api.IsOnIgnoredList) or IsIgnored
    if SafeQuery(check,name)==true then return name end
    local short=name:match("^([^-]+)%-")
    if short and SafeQuery(check,short)==true then return short end
    return nil
end

function Social.IsIgnored(name)
    return Social.FindIgnoredName(name)~=nil
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
        Notice(action.." was not accepted by the game.")
        return false
    end
    -- Do not claim an invitation was accepted: the target decides.
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
    Notice("The whisper window is unavailable.")
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
    local ignoredName=Social.FindIgnoredName(name)
    if ignoredName then
        return Perform("Unblock",C_FriendList and C_FriendList.DelIgnore or DelIgnore,ignoredName)
    end
    return Perform("Block",C_FriendList and C_FriendList.AddIgnore or AddIgnore,name)
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
        local ignored=Social.IsIgnored(name)
        MenuOption(root,ignored and "Unblock Player" or "Block Player (Ignore)",
            not selfTarget,function()
                Social.ToggleIgnore(player)
            end)
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
