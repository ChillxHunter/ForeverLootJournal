-- Forever Loot Journal v1.2.4: WoW Forever social actions for stored players.
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

function Social.IsIgnored(name)
    local f=C_FriendList and (C_FriendList.IsIgnored or C_FriendList.IsOnIgnoredList)
    local ignored=SafeQuery(f,name)
    if ignored~=nil then return ignored==true end
    if type(IsIgnored)=="function" then return SafeQuery(IsIgnored,name)==true end
    return false
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
    local ignored=Social.IsIgnored(name)
    if ignored then
        return Perform("Unblock",C_FriendList and C_FriendList.DelIgnore or DelIgnore,name)
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
        MenuOption(root,ignored and "Unblock Player (Unignore)" or "Block Player (Ignore)",
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
