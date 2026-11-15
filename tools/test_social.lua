-- Forever Loot Journal right-click social actions under Lua 5.1.
-- Simulates the WoW Forever Blizzard MenuUtil context-menu environment.
local currentMenu
local menuCalls=0
local socialFrame
function CreateFrame()
    local f={events={}}
    function f:RegisterEvent(name) self.events[name]=true end
    function f:SetScript(name,callback) self[name]=callback end
    socialFrame=f
    return f
end
GetTime=function() return 500 end
ERR_IGNORE_ADDED_S="%s is now being ignored."
ERR_IGNORE_REMOVED_S="%s is no longer being ignored."

local function Root()
    local root={entries={}}
    function root:CreateTitle(text) self.title=text end
    function root:CreateDivider() self.divider=true end
    function root:CreateButton(label,callback)
        local item={label=label,callback=callback,enabled=true}
        function item:SetEnabled(value) self.enabled=value end
        self.entries[#self.entries+1]=item
        return item
    end
    function root:Get(label)
        for _,item in ipairs(self.entries) do
            if item.label==label then return item end
        end
        return nil
    end
    return root
end
MenuUtil={CreateContextMenu=function(owner,generator)
    assert(owner=="playerrow","menu must be anchored to the clicked roster row")
    menuCalls=menuCalls+1
    currentMenu=Root()
    generator(owner,currentMenu)
end}
UnitFullName=function() return "Tester","Realm" end
local friends,ignores={},{}
local socialRequests=0
C_FriendList={
    ShowFriends=function() socialRequests=socialRequests+1 end,
    GetNumIgnores=function()
        local total=0
        for _ in pairs(ignores) do total=total+1 end
        return total
    end,
    GetIgnoreName=function(index)
        local names={}
        for name in pairs(ignores) do names[#names+1]=name end
        table.sort(names)
        return names[index]
    end,
    GetFriendInfo=function(name)
        return friends[name] and {name=name} or nil
    end,
    AddFriend=function(name)
        friends[name]=true
        return nil
    end,
    IsIgnored=function(name) return ignores[name]==true end,
    AddIgnore=function(name)
        ignores[name]=true
        return true
    end,
    DelIgnore=function(name)
        ignores[name]=nil
        return true
    end,
    DelIgnoreByIndex=function(index)
        local names={}
        for name in pairs(ignores) do names[#names+1]=name end
        table.sort(names)
        local entry=names[index]
        if entry then ignores[entry]=nil end
        return entry~=nil
    end,
}
local partyInvites,guildInvites,whispers={},{},{}
local canParty=true
C_PartyInfo={
    CanInvite=function() return canParty end,
    InviteUnit=function(name) partyInvites[#partyInvites+1]=name end,
}
local canGuild=true
IsInGuild=function() return true end
CanGuildInvite=function() return canGuild end
C_GuildInfo={Invite=function(name) guildInvites[#guildInvites+1]=name end}
ChatFrame_SendTell=function(name) whispers[#whispers+1]=name end
local notices={}
print=function(message) notices[#notices+1]=message end

local slashFallbackCalls=0
SlashCmdList={FOREVERLOOTJOURNAL=function() slashFallbackCalls=slashFallbackCalls+1 end}
local addon={}
assert(loadfile("Social.lua"))("ForeverLootJournal",addon)
assert(socialFrame and socialFrame.events.PLAYER_LOGIN and socialFrame.events.IGNORELIST_UPDATE
    and socialFrame.events.CHAT_MSG_SYSTEM)
socialFrame.OnEvent(socialFrame,"PLAYER_LOGIN")
assert(socialRequests==1,"must fetch live ignore list at login")
local name="Ranger-Realm"
local player={name=name,current=false}
assert(addon.ShowPlayerContextMenu("playerrow",player))
assert(currentMenu.title==name)
assert(#currentMenu.entries==5)
for _,label in ipairs({"Whisper","Add Friend","Block Player (Ignore)","Invite to Party","Invite to Guild"}) do
    local entry=currentMenu:Get(label)
    assert(entry and entry.enabled,"missing enabled action: "..label)
end

currentMenu:Get("Whisper").callback()
assert(#whispers==1 and whispers[1]==name,"whisper did not open correct target")
currentMenu:Get("Add Friend").callback()
assert(friends[name]==true,"friend request did not use WoW friends list")
currentMenu:Get("Block Player (Ignore)").callback()
assert(ignores[name]==true,"blocked player was not ignored")
currentMenu:Get("Invite to Party").callback()
assert(#partyInvites==1 and partyInvites[1]==name,"party invite didn't reach WoW API")
currentMenu:Get("Invite to Guild").callback()
assert(#guildInvites==1 and guildInvites[1]==name,"guild invite didn't reach WoW API")

assert(addon.ShowPlayerContextMenu("playerrow",player))
assert(currentMenu:Get("Already Friends").enabled==false,"friend option should be disabled for existing friend")
local unblock=currentMenu:Get("Unblock Player")
assert(unblock and unblock.enabled,"menu should offer unblocking ignored players")
unblock.callback()
assert(not ignores[name],"unblock didn't remove WoW ignore")
socialFrame.OnEvent(socialFrame,"CHAT_MSG_SYSTEM","Ranger-Realm is no longer being ignored.")

-- An ignore that existed BEFORE installing the addon might have been
-- stored as a short name while the journal displays Name-Realm.
ignores["Saint"]=true
local preblocked={name="Saint-Ramz",current=false}
assert(addon.ShowPlayerContextMenu("playerrow",preblocked))
local existingBlock=currentMenu:Get("Unblock Player")
assert(existingBlock and existingBlock.enabled,"pre-existing short-name ignore not recognized")
assert(not currentMenu:Get("Block Player (Ignore)"),"already ignored player still shows Block")
existingBlock.callback()
assert(not ignores["Saint"],"unblock must use the stored ignore-list entry, not the displayed realm name")
socialFrame.OnEvent(socialFrame,"CHAT_MSG_SYSTEM","Saint Ramz is no longer being ignored.")
assert(socialRequests==1,"social actions should not repeatedly call ShowFriends")

-- Conversely, never confuse two fully qualified names on different realms.
ignores["Saint-AnotherRealm"]=true
assert(addon.ShowPlayerContextMenu("playerrow",preblocked))
assert(currentMenu:Get("Block Player (Ignore)"),"different-realm player incorrectly treated as ignored")
ignores["Saint-AnotherRealm"]=nil

-- The Forever client may implement the secondary ignored-list API while
-- IsIgnored is missing. It must still detect an existing ignore.
ignores["Saint-Ramz"]=true
local savedGetNum=C_FriendList.GetNumIgnores
local savedGetName=C_FriendList.GetIgnoreName
local savedIsIgnored=C_FriendList.IsIgnored
local savedSecondary=C_FriendList.IsOnIgnoredList
C_FriendList.GetNumIgnores=nil
C_FriendList.GetIgnoreName=nil
C_FriendList.IsIgnored=nil
C_FriendList.IsOnIgnoredList=function(token)
    return ignores[token] or false
end
assert(addon.ShowPlayerContextMenu("playerrow",preblocked))
assert(currentMenu:Get("Unblock Player"),
    "secondary ignore API must detect previously ignored player even if first API is absent")
currentMenu:Get("Unblock Player").callback()
assert(not ignores["Saint-Ramz"],"secondary ignore API unblock failed")

-- A failed/unavailable ignore-list lookup must never offer another Block
-- button that could produce an unknown server friend response.
C_FriendList.IsOnIgnoredList=nil
assert(addon.ShowPlayerContextMenu("playerrow",preblocked))
assert(currentMenu:Get("Refresh Ignore Status"),
    "uncertain ignore state must offer refresh, not Block Player")
assert(not currentMenu:Get("Block Player (Ignore)"),
    "unverified ignore status must never be treated as definitely unblocked")
C_FriendList.GetNumIgnores=savedGetNum
C_FriendList.GetIgnoreName=savedGetName
C_FriendList.IsIgnored=savedIsIgnored
C_FriendList.IsOnIgnoredList=savedSecondary

-- A broken primary lookup returning false should not suppress a secondary
-- successful lookup, even when the complete list API is unavailable.
ignores["Saint-Ramz"]=true
C_FriendList.GetNumIgnores=nil
C_FriendList.GetIgnoreName=nil
C_FriendList.IsIgnored=function() return false end
C_FriendList.IsOnIgnoredList=function(name) return ignores[name]==true end
assert(addon.ShowPlayerContextMenu("playerrow",preblocked))
assert(currentMenu:Get("Unblock Player"),"positive secondary lookup must outrank negative primary")
C_FriendList.GetNumIgnores=savedGetNum
C_FriendList.GetIgnoreName=savedGetName
C_FriendList.IsIgnored=savedIsIgnored
C_FriendList.IsOnIgnoredList=savedSecondary
ignores["Saint-Ramz"]=nil

-- Real screenshot regression: WoW confirms "Saint Ramz is now being ignored."
-- while the friends-list APIs still return an older, unblocked snapshot.
local savedAdd=C_FriendList.AddIgnore
local serverAdds=0
C_FriendList.AddIgnore=function(target)
    serverAdds=serverAdds+1
    -- The request is asynchronous; don't update the mock ignore list here.
    return true
end
local delayed={name="Saint-Ramz",current=false}
assert(addon.ShowPlayerContextMenu("playerrow",delayed))
assert(currentMenu:Get("Block Player (Ignore)"),"unblocked player must offer Block")
currentMenu:Get("Block Player (Ignore)").callback()
assert(serverAdds==1,"ignore request sent more than once")
assert(addon.ShowPlayerContextMenu("playerrow",delayed))
assert(currentMenu:Get("Waiting for Ignore Response"),
    "a pending request must not offer another Block action")
assert(not currentMenu:Get("Block Player (Ignore)"),
    "repeat Block action must not be available during pending server confirmation")
socialFrame.OnEvent(socialFrame,"CHAT_MSG_SYSTEM","Saint Ramz is now being ignored.")
assert(addon.ShowPlayerContextMenu("playerrow",delayed))
assert(currentMenu:Get("Unblock Player"),
    "confirmed ignored player must display Unblock despite stale friends-list API")
assert(socialRequests==1,
    "opening player menu and toggling Ignore must not spam ShowFriends requests")
C_FriendList.AddIgnore=savedAdd
socialFrame.OnEvent(socialFrame,"CHAT_MSG_SYSTEM","Saint Ramz is no longer being ignored.")

-- Ignore-list entries can also contain a display-space rather than a realm hyphen.
ignores["Saint Ramz"]=true
assert(addon.ShowPlayerContextMenu("playerrow",delayed))
assert(currentMenu:Get("Unblock Player"),"space/hyphen name variants must match")
currentMenu:Get("Unblock Player").callback()
assert(not ignores["Saint Ramz"],"unignore must remove the correctly matched displayed name")
socialFrame.OnEvent(socialFrame,"CHAT_MSG_SYSTEM","Saint Ramz is no longer being ignored.")

local grouped={name=name,current=true}
canGuild=false
canParty=false
assert(addon.ShowPlayerContextMenu("playerrow",grouped))
assert(currentMenu:Get("Invite to Party").enabled==false,"cannot invite someone already in party")
assert(currentMenu:Get("Invite to Guild").enabled==false,"guild invitation requires permission")
assert(addon.ShowPlayerContextMenu("playerrow",{name="Tester-Realm",current=false}))
for _,entry in ipairs(currentMenu.entries) do
    assert(entry.enabled==false,"should disable self-invites, whispers and ignore")
end

assert(not addon.ShowPlayerContextMenu("playerrow",{name="bad\n/macro",current=false}),
    "must refuse malformed player names")
local count=menuCalls
MenuUtil=nil
assert(not addon.ShowPlayerContextMenu("playerrow",player),"client without MenuUtil should fail safely")
assert(menuCalls==count,"fallback should not show invalid context menu")
assert(#partyInvites==1 and #guildInvites==1,"disabled actions must not send invitations")
SlashCmdList.FOREVERLOOTJOURNAL("ignorestatus Saint-Ramz")
local foundDiagnostic=false
for _,notice in ipairs(notices) do
    if notice:find("Ignore check Saint-Ramz",1,true) then foundDiagnostic=true end
end
assert(foundDiagnostic,"ignorestatus diagnostic should print the server status")
SlashCmdList.FOREVERLOOTJOURNAL("players")
assert(slashFallbackCalls==1,"previous /flj command handlers must remain intact")
io.write("Player social menu integration tests passed\n")
