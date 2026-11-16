-- Forever Loot Journal: cross-zone armor and weapon sharing (v1.1.9).
-- Both characters must run this addon. No addon message is relayed onward.
local addonName, FLJ = ...
local PREFIX="FLJLoot1" -- 8 bytes; WoW allows up to 16
local peers={}
local registered=false
local lastHello=0
local clock=time or function() return 0 end

local function Settings()
    local db=FLJ.GetDB and FLJ.GetDB()
    if type(db)~="table" then return nil end
    if type(db.ui)~="table" then db.ui={} end
    local ui=db.ui
    if ui.syncEnabled==nil then ui.syncEnabled=true end
    return ui,db
end

local function Channel()
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup() then return "PARTY" end
    return nil
end

local function OwnName()
    local name,realm
    if UnitFullName then name,realm=UnitFullName("player") end
    if not name and UnitName then name=UnitName("player") end
    if not name then return nil end
    if realm and realm~="" then return name.."-"..realm end
    return name
end

local function Lower(s)
    return type(s)=="string" and s:lower() or ""
end

local function Short(s)
    return (s or ""):match("^([^-]+)") or ""
end

local function SamePlayer(a,b)
    if FLJ.SamePlayer then return FLJ.SamePlayer(a,b) end
    a,b=Lower(a),Lower(b)
    if a==b then return true end
    local ar,br=a:find("-",1,true),b:find("-",1,true)
    return (not ar or not br) and Short(a)==Short(b)
end

-- Use the server-owned CHAT_MSG_ADDON sender field, never an identity supplied
-- within the payload. Reject messages from outside the current party/raid.
local function CurrentMember(sender)
    if type(sender)~="string" or sender=="" or not FLJ.GetPlayers then return nil end
    if SamePlayer(sender,OwnName()) then return nil end
    local matched
    for _,p in ipairs(FLJ.GetPlayers()) do
        if p.current and SamePlayer(sender,p.name) then
            if matched and matched~=p.name then return nil end
            matched=p.name
        end
    end
    return matched
end

local function Send(message)
    local ui=Settings()
    local channel=Channel()
    if not (registered and ui and ui.syncEnabled and channel) then return false end
    if type(message)~="string" or #message>255 then return false end
    local sender=C_ChatInfo and C_ChatInfo.SendAddonMessage
    if type(sender)~="function" then return false end
    local ok,result=pcall(sender,PREFIX,message,channel)
    -- Forever returns Enum.SendAddonMessageResult.Success == 0.
    return ok and (result==0 or result==true or result==nil)
end

local function Hello(force)
    if not registered then return end
    local now=clock()
    if force or now-lastHello>=18 then
        if Send("H1") then lastHello=now end
    end
end

local function Register()
    if registered then return true end
    local register=C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix
    if type(register)~="function" then return false end
    local ok,result=pcall(register,PREFIX)
    registered=ok and (result==0 or result==1 or result==true or result==nil)
    return registered
end

function FLJ.SendSelfLoot(rec)
    local ui,db=Settings()
    if not (ui and db and ui.syncEnabled and Channel()) or type(rec)~="table" then return false end
    if rec.syncSent then return false end
    local cls=tonumber(rec.classID)
    if cls~=2 and cls~=4 and not (FLJ.IsCraftingItem and FLJ.IsCraftingItem(cls)) then return false end
    local link=rec.link
    if type(link)~="string" then
        if not rec.itemID then return false end
        link="item:"..tostring(rec.itemID)
    end
    -- Preserve unique enchants, random bonuses and stats in the item string.
    local itemString=link:match("|H(item:[^|]+)|h") or link:match("(item:[^|%s]+)")
    if type(itemString)~="string" or not itemString:match("^item:%d+") then return false end
    if itemString:find("[%c]") or #itemString>176 then return false end
    local zone=tostring(rec.zone or ""):gsub("[%c]", " "):sub(1,48)
    local serial=(tonumber(db.syncSerial) or 0)+1
    local payload=table.concat({"L1",serial,cls,itemString,zone},"\t")
    if #payload>255 then return false end
    if Send(payload) then
        db.syncSerial=serial
        rec.syncSent=true
        return true
    end
    return false
end

local function HandleMessage(prefix,message,channel,sender)
    if prefix~=PREFIX or type(message)~="string" or #message>255 then return end
    if channel~="PARTY" and channel~="RAID" and channel~="INSTANCE_CHAT" then return end
    local ui=Settings()
    if not ui or not ui.syncEnabled then return end
    local member=CurrentMember(sender)
    if not member then return end
    if message=="H1" then
        peers[member]=clock()
        Hello(false)
        return
    end
    -- A small message without dynamic code execution or external libraries.
    local serial,cls,itemString,zone=message:match("^L1\t(%d+)\t(%d+)\t([^\t]+)\t(.*)$")
    if not serial or #serial>15 or #itemString>176 then return end
    if itemString:find("[%c|]") or not itemString:match("^item:%d+") then return end
    if type(zone)~="string" or #zone>48 or zone:find("[%c]") then return end
    peers[member]=clock()
    if FLJ.ReceiveSharedLoot then
        FLJ.ReceiveSharedLoot(member,serial,itemString,tonumber(cls),zone)
    end
end

local function PeerCount()
    local now=clock()
    local count=0
    for name,last in pairs(peers) do
        if now-last<3600 and CurrentMember(name) then count=count+1 end
    end
    return count
end

local function Status()
    local ui=Settings()
    local enabled=ui and ui.syncEnabled
    print("|cffffd76aForever Loot Journal Sync:|r "..(enabled and "ON" or "OFF")..
          ", channel="..tostring(Channel() or "not grouped")..
          ", addon communications="..(registered and "ready" or "unavailable")..
          ", detected peers="..PeerCount()..
          ". All distant members must install the addon too.")
end

-- Minimap.lua wraps /flj before this module, so keep its icon commands intact.
local previousSlash=SlashCmdList and SlashCmdList.FOREVERLOOTJOURNAL
if previousSlash then
    SlashCmdList.FOREVERLOOTJOURNAL=function(message)
        local cmd=tostring(message or ""):lower():match("^%s*(.-)%s*$")
        local action=cmd:match("^sync%s*(.-)%s*$")
        if action~=nil then
            local ui=Settings()
            if not ui then
                print("|cffffd76aForever Loot Journal:|r Synchronization not initialized.")
                return
            end
            if action=="on" then
                ui.syncEnabled=true
                Hello(true)
                Status()
            elseif action=="off" then
                ui.syncEnabled=false
                Status()
            elseif action=="check" then
                Hello(true)
                Status()
            elseif action=="" or action=="status" then
                Status()
            else
                print("|cffffd76aSync commands:|r /flj sync [on|off|check|status]")
            end
        else
            previousSlash(message)
            if cmd=="help" then
                print("|cffffd76aCross-zone loot sharing:|r /flj sync, /flj sync on, /flj sync off, /flj sync check")
            end
        end
    end
end

local eventFrame=CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:SetScript("OnEvent",function(_,event,...)
    if event=="ADDON_LOADED" then
        if ...==addonName then Register() end
    elseif event=="PLAYER_LOGIN" then
        Register()
        Hello(true)
    elseif event=="PLAYER_ENTERING_WORLD" or event=="GROUP_ROSTER_UPDATE" then
        Register()
        Hello(false)
    elseif event=="CHAT_MSG_ADDON" then
        HandleMessage(...)
    end
end)

