-- Option D: charcoal metal, restrained gold trim, and beveled controls.
local _,FLJ=...
local T={}
FLJ.Theme=T
local media="Interface\\AddOns\\ForeverLootJournal\\Media\\"
function T.Paint(parent,name,layer,corner)
    local c=corner or 10
    local uv=c/256
    local regions={}
    local function Part(point,relative,w,h,l,r,t,b)
        local x=parent:CreateTexture(nil,layer or "BORDER")
        x:SetTexture(media..name)
        x:SetTexCoord(l,r,t,b)
        for _,p in ipairs(relative) do x:SetPoint(unpack(p)) end
        if w then x:SetWidth(w) end
        if h then x:SetHeight(h) end
        regions[#regions+1]=x
    end
    Part("TL",{{"TOPLEFT",parent,"TOPLEFT",0,0}},c,c,0,uv,0,uv)
    Part("TR",{{"TOPRIGHT",parent,"TOPRIGHT",0,0}},c,c,1-uv,1,0,uv)
    Part("BL",{{"BOTTOMLEFT",parent,"BOTTOMLEFT",0,0}},c,c,0,uv,1-uv,1)
    Part("BR",{{"BOTTOMRIGHT",parent,"BOTTOMRIGHT",0,0}},c,c,1-uv,1,1-uv,1)
    Part("T",{{"TOPLEFT",parent,"TOPLEFT",c,0},{"TOPRIGHT",parent,"TOPRIGHT",-c,0}},nil,c,uv,1-uv,0,uv)
    Part("B",{{"BOTTOMLEFT",parent,"BOTTOMLEFT",c,0},{"BOTTOMRIGHT",parent,"BOTTOMRIGHT",-c,0}},nil,c,uv,1-uv,1-uv,1)
    Part("L",{{"TOPLEFT",parent,"TOPLEFT",0,-c},{"BOTTOMLEFT",parent,"BOTTOMLEFT",0,c}},c,nil,0,uv,uv,1-uv)
    Part("R",{{"TOPRIGHT",parent,"TOPRIGHT",0,-c},{"BOTTOMRIGHT",parent,"BOTTOMRIGHT",0,c}},c,nil,1-uv,1,uv,1-uv)
    Part("C",{{"TOPLEFT",parent,"TOPLEFT",c,-c},{"BOTTOMRIGHT",parent,"BOTTOMRIGHT",-c,c}},nil,nil,uv,1-uv,uv,1-uv)
    function regions:SetShown(on)
        for _,x in ipairs(self) do x:SetShown(on) end
    end
    function regions:SetTint(r,g,b,a)
        for _,x in ipairs(self) do x:SetVertexColor(r,g,b,a or 1) end
    end
    return regions
end
