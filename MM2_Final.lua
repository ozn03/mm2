--[[
    MM2 Hub — Delta Mobile | Agustos 2026
    Silent Aim: Tool.Activated hook (ateşe dokunmaz, sadece yön değiştirir)
    ESP: BillboardGui box + rol rengi
    Silah Chams: Highlight
]]

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LP           = Players.LocalPlayer

-- ============================================================
-- ROL TESPİTİ
-- ============================================================
local KNIFE_K = {"knife","blade","saber","scythe","murd","dark","luger","machete","saw"}
local GUN_K   = {"gun","sheriff","revolver","pistol","sniper","deagle"}

local function hasK(s, t)
    s = s:lower()
    for _,k in ipairs(t) do if s:find(k,1,true) then return true end end
    return false
end

local function getRole(p)
    local c = p and p.Character
    if not c then return "innocent" end
    local tool = c:FindFirstChildWhichIsA("Tool")
    if not tool then return "innocent" end
    if hasK(tool.Name, KNIFE_K) then return "murderer" end
    if hasK(tool.Name, GUN_K)   then return "sheriff"  end
    return "innocent"
end

local function getMurd()
    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= LP and getRole(p) == "murderer" then return p end
    end
end

-- ============================================================
-- RENKLER
-- ============================================================
local C = {
    murderer  = Color3.fromRGB(255,50,50),
    sheriff   = Color3.fromRGB(60,130,255),
    innocent  = Color3.fromRGB(55,210,80),
    gun       = Color3.fromRGB(180,60,255),
    gunholder = Color3.fromRGB(60,130,255),
}

-- ============================================================
-- AYARLAR
-- ============================================================
local CFG = {
    ESP       = false,
    GunChams  = false,
    SilentAim = false,
}

-- ============================================================
-- SILENT AIM
-- Yöntem: __namecall hook ile FireServer yakala
-- MM2 şerif silahı ateşlenince RemoteEvent:FireServer(mousePos) çağırır
-- Biz sadece o pozisyon argümanını katile yönlendiriyoruz
-- Ateş mekanizmasına dokunmuyoruz → silah normal ateş eder
-- ============================================================
local saOk = false

pcall(function()
    if not (hookmetamethod and getrawmetatable and newcclosure and getnamecallmethod) then
        error("hook yok")
    end

    local mt  = getrawmetatable(game)
    local old = mt.__namecall
    setreadonly(mt, false)

    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()

        if method == "FireServer" and CFG.SilentAim then
            if getRole(LP) == "sheriff" then
                local murd = getMurd()
                if murd and murd.Character then
                    local head = murd.Character:FindFirstChild("Head")
                    if head then
                        local args = {...}
                        local changed = false

                        -- Argümanları tara, CFrame veya Vector3 olanı değiştir
                        for i = 1, #args do
                            if typeof(args[i]) == "CFrame" then
                                args[i] = CFrame.new(head.Position)
                                changed = true
                            elseif typeof(args[i]) == "Vector3" then
                                args[i] = head.Position
                                changed = true
                            end
                        end

                        if changed then
                            return old(self, table.unpack(args))
                        end
                    end
                end
            end
        end

        return old(self, ...)
    end)

    setreadonly(mt, true)
    saOk = true
end)

-- Yedek: mouse.Hit hook (sadece saOk false ise)
if not saOk then
    pcall(function()
        if not (hookmetamethod and getrawmetatable and checkcaller and newcclosure) then
            error("hook yok")
        end

        local mt  = getrawmetatable(game)
        local old = mt.__index
        setreadonly(mt, false)

        mt.__index = newcclosure(function(self, key)
            if not checkcaller() and key == "Hit" and CFG.SilentAim then
                local ok, isMouse = pcall(function() return self:IsA("Mouse") end)
                if ok and isMouse and getRole(LP) == "sheriff" then
                    local murd = getMurd()
                    local head = murd and murd.Character and murd.Character:FindFirstChild("Head")
                    if head then
                        return CFrame.new(head.Position)
                    end
                end
            end
            return old(self, key)
        end)

        setreadonly(mt, true)
        saOk = true
    end)
end

-- ============================================================
-- BOX ESP
-- ============================================================
local espData = {}

local function makeESP(p)
    if p == LP or espData[p] then return end

    local function build(char)
        task.wait(0.5)
        local hrp  = char:WaitForChild("HumanoidRootPart", 10)
        local head = char:WaitForChild("Head", 10)
        if not hrp or not head then return end

        -- Temizle
        for _, n in ipairs({"MM2_BOX","MM2_LBL"}) do
            local o = hrp:FindFirstChild(n) or head:FindFirstChild(n)
            if o then o:Destroy() end
        end

        -- Kutu
        local bbg = Instance.new("BillboardGui", hrp)
        bbg.Name = "MM2_BOX"; bbg.AlwaysOnTop = true
        bbg.Size = UDim2.new(4.6,0,6.4,0); bbg.Adornee = hrp; bbg.Enabled = false

        local f = Instance.new("Frame", bbg)
        f.Size = UDim2.new(1,0,1,0); f.BackgroundTransparency = 1

        local stk = Instance.new("UIStroke", f)
        stk.Thickness = 1.5; stk.Color = C.innocent

        -- İsim etiketi
        local lbg = Instance.new("BillboardGui", head)
        lbg.Name = "MM2_LBL"; lbg.AlwaysOnTop = true
        lbg.Size = UDim2.new(0,130,0,26); lbg.StudsOffset = Vector3.new(0,3.8,0)
        lbg.Adornee = head; lbg.Enabled = false

        local lbl = Instance.new("TextLabel", lbg)
        lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
        lbl.TextStrokeTransparency = 0; lbl.TextStrokeColor3 = Color3.new(0,0,0)
        lbl.Font = Enum.Font.SourceSansBold; lbl.TextSize = 13
        lbl.TextColor3 = C.innocent; lbl.Text = p.Name

        espData[p] = { bbg=bbg, stk=stk, lbg=lbg, lbl=lbl }
    end

    p.CharacterAdded:Connect(build)
    if p.Character then build(p.Character) end
end

local function removeESP(p)
    if not espData[p] then return end
    pcall(function() espData[p].bbg:Destroy() end)
    pcall(function() espData[p].lbg:Destroy() end)
    espData[p] = nil
end

for _,p in ipairs(Players:GetPlayers()) do makeESP(p) end
Players.PlayerAdded:Connect(function(p) task.wait(0.5); makeESP(p) end)
Players.PlayerRemoving:Connect(removeESP)

RunService.RenderStepped:Connect(function()
    local gunHolder = nil
    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local t = p.Character:FindFirstChildWhichIsA("Tool")
            if t and hasK(t.Name, GUN_K) then gunHolder = p; break end
        end
    end

    for _,p in ipairs(Players:GetPlayers()) do
        if p == LP then continue end
        local d = espData[p]; if not d then continue end
        local role = getRole(p)

        local color
        if p == gunHolder       then color = C.gunholder
        elseif role=="murderer" then color = C.murderer
        elseif role=="sheriff"  then color = C.sheriff
        else                         color = C.innocent end

        local tag = role=="murderer" and " [KATİL]" or role=="sheriff" and " [ŞERİF]" or ""

        d.bbg.Enabled    = CFG.ESP
        d.lbg.Enabled    = CFG.ESP
        d.stk.Color      = color
        d.lbl.TextColor3 = color
        d.lbl.Text       = p.Name .. tag
    end
end)

-- ============================================================
-- SİLAH CHAMS
-- ============================================================
local gunHLs = {}

local function applyGunHL(obj)
    if not obj:IsA("Tool") then return end
    if not hasK(obj.Name, GUN_K) then return end
    if gunHLs[obj] then return end
    if Players:GetPlayerFromCharacter(obj.Parent) then return end

    local hl = Instance.new("Highlight", obj)
    hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillColor           = C.gun
    hl.FillTransparency    = 0.35
    hl.OutlineColor        = C.gun
    hl.OutlineTransparency = 0
    hl.Enabled             = CFG.GunChams
    gunHLs[obj] = hl

    obj.AncestryChanged:Connect(function()
        if not obj.Parent then
            pcall(function() gunHLs[obj]:Destroy() end)
            gunHLs[obj] = nil
        end
    end)
end

workspace.DescendantAdded:Connect(function(obj)
    task.wait(0.05)
    if CFG.GunChams then applyGunHL(obj) end
end)

local function refreshGunChams(state)
    for _,obj in ipairs(workspace:GetDescendants()) do
        applyGunHL(obj)
    end
    for _,hl in pairs(gunHLs) do hl.Enabled = state end
end

-- ============================================================
-- GUI
-- ============================================================
pcall(function()
    local cg = game:GetService("CoreGui")
    local o  = cg:FindFirstChild("MM2FinalHUB")
    if o then o:Destroy() end
end)

local SG = Instance.new("ScreenGui")
SG.Name = "MM2FinalHUB"; SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.IgnoreGuiInset = true
pcall(function() SG.Parent = game:GetService("CoreGui") end)
if not SG.Parent then SG.Parent = LP:WaitForChild("PlayerGui") end

local function drag(frame, handle)
    local on, ds, sp
    local h = handle or frame
    h.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            on=true; ds=i.Position; sp=frame.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then on=false end
            end)
        end
    end)
    h.InputChanged:Connect(function(i)
        if not on then return end
        if i.UserInputType ~= Enum.UserInputType.MouseMovement
        and i.UserInputType ~= Enum.UserInputType.Touch then return end
        local d = i.Position - ds
        frame.Position = UDim2.new(sp.X.Scale, sp.X.Offset+d.X, sp.Y.Scale, sp.Y.Offset+d.Y)
    end)
end

local Panel = Instance.new("Frame", SG)
Panel.Size             = UDim2.new(0,210,0,195)
Panel.Position         = UDim2.new(0,16,0.5,-97)
Panel.BackgroundColor3 = Color3.fromRGB(13,13,16)
Instance.new("UICorner",Panel).CornerRadius = UDim.new(0,10)
local ps = Instance.new("UIStroke",Panel)
ps.Color=Color3.fromRGB(255,50,50); ps.Thickness=1.2
drag(Panel)

local tl = Instance.new("Frame",Panel)
tl.Size=UDim2.new(1,0,0,3)
tl.BackgroundColor3=Color3.fromRGB(255,50,50)
Instance.new("UICorner",tl).CornerRadius=UDim.new(0,10)
local tg = Instance.new("UIGradient",tl)
tg.Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.fromRGB(255,40,40)),
    ColorSequenceKeypoint.new(0.5,Color3.fromRGB(255,120,40)),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(255,40,40)),
})

local TB = Instance.new("Frame",Panel)
TB.Size=UDim2.new(1,0,0,38); TB.Position=UDim2.new(0,0,0,3)
TB.BackgroundColor3=Color3.fromRGB(18,18,22)

local TL = Instance.new("TextLabel",TB)
TL.Size=UDim2.new(1,-40,1,0); TL.Position=UDim2.new(0,10,0,0)
TL.BackgroundTransparency=1; TL.Text="🔪 MM2 Hub"
TL.TextColor3=Color3.fromRGB(230,230,230)
TL.Font=Enum.Font.SourceSansBold; TL.TextSize=14
TL.TextXAlignment=Enum.TextXAlignment.Left

local MB = Instance.new("TextButton",TB)
MB.Size=UDim2.new(0,26,0,26); MB.Position=UDim2.new(1,-32,0.5,-13)
MB.BackgroundColor3=Color3.fromRGB(38,38,50)
MB.Text="—"; MB.TextColor3=Color3.fromRGB(200,200,200)
MB.Font=Enum.Font.SourceSansBold; MB.TextSize=13
Instance.new("UICorner",MB).CornerRadius=UDim.new(1,0)

local Cont = Instance.new("Frame",Panel)
Cont.Size=UDim2.new(1,0,1,-41); Cont.Position=UDim2.new(0,0,0,41)
Cont.BackgroundTransparency=1
local CL = Instance.new("UIListLayout",Cont)
CL.HorizontalAlignment=Enum.HorizontalAlignment.Center
CL.Padding=UDim.new(0,5)
local CP = Instance.new("UIPadding",Cont)
CP.PaddingTop=UDim.new(0,7); CP.PaddingLeft=UDim.new(0,8); CP.PaddingRight=UDim.new(0,8)

local TI  = TweenInfo.new(0.13,Enum.EasingStyle.Quad)
local ON  = Color3.fromRGB(255,50,50)
local OFF = Color3.fromRGB(38,38,50)

local function addToggle(label, ico, key, onCb, offCb)
    local row = Instance.new("Frame",Cont)
    row.Size=UDim2.new(1,0,0,44)
    row.BackgroundColor3=Color3.fromRGB(20,20,26)
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,8)
    local rs=Instance.new("UIStroke",row); rs.Color=Color3.fromRGB(35,35,46); rs.Thickness=1

    local stripe = Instance.new("Frame",row)
    stripe.Size=UDim2.new(0,3,0.6,0); stripe.Position=UDim2.new(0,0,0.2,0)
    stripe.BackgroundColor3=OFF
    Instance.new("UICorner",stripe).CornerRadius=UDim.new(0,2)

    local ic = Instance.new("TextLabel",row)
    ic.Size=UDim2.new(0,30,1,0); ic.Position=UDim2.new(0,6,0,0)
    ic.BackgroundTransparency=1; ic.Text=ico; ic.TextSize=18

    local nl = Instance.new("TextLabel",row)
    nl.Size=UDim2.new(1,-82,1,0); nl.Position=UDim2.new(0,38,0,0)
    nl.BackgroundTransparency=1; nl.Text=label
    nl.TextColor3=Color3.fromRGB(215,215,215)
    nl.Font=Enum.Font.SourceSansBold; nl.TextSize=13
    nl.TextXAlignment=Enum.TextXAlignment.Left

    local sw = Instance.new("TextButton",row)
    sw.Size=UDim2.new(0,44,0,22); sw.Position=UDim2.new(1,-50,0.5,-11)
    sw.BackgroundColor3=OFF; sw.Text=""
    Instance.new("UICorner",sw).CornerRadius=UDim.new(1,0)

    local kn = Instance.new("Frame",sw)
    kn.Size=UDim2.new(0,16,0,16); kn.Position=UDim2.new(0,3,0.5,-8)
    kn.BackgroundColor3=Color3.fromRGB(255,255,255)
    Instance.new("UICorner",kn).CornerRadius=UDim.new(1,0)

    local function toggle()
        CFG[key] = not CFG[key]
        local v = CFG[key]
        TweenService:Create(sw,TI,{BackgroundColor3=v and ON or OFF}):Play()
        TweenService:Create(stripe,TI,{BackgroundColor3=v and ON or Color3.fromRGB(38,38,50)}):Play()
        TweenService:Create(kn,TI,{Position=v and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)}):Play()
        if v and onCb   then onCb()  end
        if not v and offCb then offCb() end
    end

    sw.MouseButton1Click:Connect(toggle)
    row.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1
        or i.UserInputType==Enum.UserInputType.Touch then toggle() end
    end)
end

addToggle("Box ESP",     "👁",  "ESP",       nil, nil)
addToggle("Silah Chams", "🔫", "GunChams",
    function() refreshGunChams(true)  end,
    function() refreshGunChams(false) end
)
addToggle("Silent Aim",  "🎯", "SilentAim", nil, nil)

local leg = Instance.new("TextLabel",Cont)
leg.Size=UDim2.new(1,0,0,22)
leg.BackgroundColor3=Color3.fromRGB(18,18,22)
leg.Text="🔴Katil  🔵Şerif  🟢Masum"
leg.TextColor3=Color3.fromRGB(150,150,150)
leg.Font=Enum.Font.SourceSans; leg.TextSize=10
Instance.new("UICorner",leg).CornerRadius=UDim.new(0,5)

local mini = false
MB.MouseButton1Click:Connect(function()
    mini = not mini
    Cont.Visible = not mini
    MB.Text = mini and "+" or "—"
    TweenService:Create(Panel,TweenInfo.new(0.18),{
        Size = mini and UDim2.new(0,210,0,41) or UDim2.new(0,210,0,195)
    }):Play()
end)

task.wait(0.8)
pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification",{
        Title="MM2 Hub";
        Text= "✅ Yüklendi! Aim Hook: " .. (saOk and "✅ Aktif" or "❌ Hook yok");
        Duration=5;
    })
end)
