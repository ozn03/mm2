-- ================================================================
--   MM2 HUB v4 — Delta Executor Uyumlu | 2026
--   Silent Aim: __namecall hook (Delta destekli yöntem)
--   Menü: Yatay geniş, sürüklenebilir, mobil dokunmatik uyumlu
-- ================================================================

-- Oyun MM2 mi kontrol et
if not game:IsLoaded() then game.Loaded:Wait() end

local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local UIS             = game:GetService("UserInputService")
local TweenService    = game:GetService("TweenService")
local Workspace       = game:GetService("Workspace")
local LocalPlayer     = Players.LocalPlayer

-- ================================================================
-- AYARLAR
-- ================================================================
local CFG = {
    SheriffSilentAim = false,
    KnifeSilentAim   = false,
    KnifeAura        = false,
    KnifeAuraRange   = 12,
    AutoShootMurd    = false,

    ESP              = false,
    ESP_Names        = true,
    ESP_Health       = true,
    ESP_Distance     = true,
    ESP_Box          = true,

    AutoCoinFarm     = false,
    AutoGrabGun      = false,

    SpeedHack        = false,
    SpeedValue       = 32,
    InfiniteJump     = false,
    NoClip           = false,
    AntiAFK          = true,
}

-- ================================================================
-- ROL TESPİTİ
-- ================================================================
local KNIFE_TAGS = {"knife","blade","saber","scythe","murd","dark","luger"}
local GUN_TAGS   = {"gun","sheriff","revolver","pistol"}

local function isKnife(name)
    name = name:lower()
    for _,k in ipairs(KNIFE_TAGS) do if name:find(k) then return true end end
    return false
end
local function isGun(name)
    name = name:lower()
    for _,k in ipairs(GUN_TAGS) do if name:find(k) then return true end end
    return false
end
local function getRole(p)
    local char = p.Character
    if not char then return "innocent" end
    local tool = char:FindFirstChildWhichIsA("Tool")
    if not tool then return "innocent" end
    if isKnife(tool.Name) then return "murderer" end
    if isGun(tool.Name)   then return "sheriff"  end
    return "innocent"
end
local function getMurderer()
    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and getRole(p) == "murderer" then return p end
    end
end
local function getNearestPlayer(ignoreSelf)
    local lhrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not lhrp then return nil end
    local best, bd = nil, math.huge
    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChild("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local d = (hrp.Position - lhrp.Position).Magnitude
                if d < bd then best = p; bd = d end
            end
        end
    end
    return best
end

-- ================================================================
-- SILENT AIM — Delta'da çalışan __namecall yöntemi
-- ================================================================
-- Yöntem: FireServer argümanlarını yakala ve CFrame yönlendir
local saHooked = false
pcall(function()
    if not (hookmetamethod and getrawmetatable and newcclosure and getnamecallmethod) then return end
    local mt = getrawmetatable(game)
    setreadonly(mt, false)
    local oldNc = mt.__namecall
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == "FireServer" then
            local args = {...}
            -- ŞERİF: ateş remote'u → katili hedef al
            if CFG.SheriffSilentAim and getRole(LocalPlayer) == "sheriff" then
                local murd = getMurderer()
                if murd and murd.Character then
                    local head = murd.Character:FindFirstChild("Head")
                    if head then
                        -- İlk argümanı pozisyona yönlendir
                        for i,v in ipairs(args) do
                            if typeof(v) == "CFrame" or typeof(v) == "Vector3" then
                                args[i] = typeof(v) == "CFrame" and CFrame.new(head.Position) or head.Position
                                break
                            end
                        end
                        -- Argüman yoksa ekle
                        if #args == 0 then args[1] = CFrame.new(head.Position) end
                        return oldNc(self, table.unpack(args))
                    end
                end
            end
            -- KATİL: bıçak fırlatma → en yakın oyuncuyu hedef al
            if CFG.KnifeSilentAim and getRole(LocalPlayer) == "murderer" then
                local target = getNearestPlayer()
                if target and target.Character then
                    local head = target.Character:FindFirstChild("Head")
                    if head then
                        for i,v in ipairs(args) do
                            if typeof(v) == "CFrame" or typeof(v) == "Vector3" then
                                args[i] = typeof(v) == "CFrame" and CFrame.new(head.Position) or head.Position
                                break
                            end
                        end
                        if #args == 0 then args[1] = CFrame.new(head.Position) end
                        return oldNc(self, table.unpack(args))
                    end
                end
            end
        end
        return oldNc(self, ...)
    end)
    setreadonly(mt, true)
    saHooked = true
end)

-- Yedek: mouse.Hit hook
if not saHooked then
    pcall(function()
        if not (hookmetamethod and getrawmetatable and checkcaller and newcclosure) then return end
        local mt = getrawmetatable(game)
        setreadonly(mt, false)
        local old = mt.__index
        mt.__index = newcclosure(function(self, key)
            if not checkcaller() and key == "Hit" then
                local ok, r = pcall(function() return self:IsA("Mouse") end)
                if ok and r then
                    if CFG.SheriffSilentAim and getRole(LocalPlayer) == "sheriff" then
                        local m = getMurderer()
                        local h = m and m.Character and m.Character:FindFirstChild("Head")
                        if h then return CFrame.new(h.Position) end
                    end
                    if CFG.KnifeSilentAim and getRole(LocalPlayer) == "murderer" then
                        local t = getNearestPlayer()
                        local h = t and t.Character and t.Character:FindFirstChild("Head")
                        if h then return CFrame.new(h.Position) end
                    end
                end
            end
            return old(self, key)
        end)
        setreadonly(mt, true)
    end)
end

-- ================================================================
-- KNIFE AURA
-- ================================================================
local lastAura = 0
RunService.Heartbeat:Connect(function()
    if not CFG.KnifeAura then return end
    if getRole(LocalPlayer) ~= "murderer" then return end
    local now = tick()
    if now - lastAura < 0.25 then return end
    lastAura = now
    local lhrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not lhrp then return end
    local best, bd = nil, CFG.KnifeAuraRange
    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChild("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local d = (hrp.Position - lhrp.Position).Magnitude
                if d < bd then best = hrp; bd = d end
            end
        end
    end
    if best then
        lhrp.CFrame = CFrame.new(best.Position) * CFrame.new(0,0,1.5)
    end
end)

-- ================================================================
-- AUTO SHOOT MURDERER
-- ================================================================
local lastShoot = 0
RunService.Heartbeat:Connect(function()
    if not CFG.AutoShootMurd then return end
    if getRole(LocalPlayer) ~= "sheriff" then return end
    local now = tick()
    if now - lastShoot < 0.9 then return end
    lastShoot = now
    local murd = getMurderer()
    if not murd or not murd.Character then return end
    local lhrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local mhrp = murd.Character:FindFirstChild("HumanoidRootPart")
    if not lhrp or not mhrp then return end
    if (mhrp.Position - lhrp.Position).Magnitude > 80 then return end
    pcall(function()
        local vu = game:GetService("VirtualInputManager")
        vu:SendMouseButtonEvent(0,0,0,true,game,0)
        task.wait(0.05)
        vu:SendMouseButtonEvent(0,0,0,false,game,0)
    end)
end)

-- ================================================================
-- ESP
-- ================================================================
local espCache = {}
local roleColors = {
    murderer = Color3.fromRGB(255,55,55),
    sheriff  = Color3.fromRGB(55,140,255),
    innocent = Color3.fromRGB(55,210,100),
}
local roleLabel = {
    murderer = "🔪KATİL",
    sheriff  = "🔫ŞERİF",
    innocent = "👤Masum",
}

local function buildESP(p)
    if p == LocalPlayer then return end
    local function setup(char)
        task.wait(0.3)
        local head = char:WaitForChild("Head",8)
        local hrp  = char:WaitForChild("HumanoidRootPart",8)
        if not head or not hrp then return end
        for _,n in ipairs({"MM2ESP","MM2BOX"}) do
            local o = head:FindFirstChild(n) or hrp:FindFirstChild(n)
            if o then o:Destroy() end
        end
        -- Yazı
        local bbg = Instance.new("BillboardGui", head)
        bbg.Name="MM2ESP"; bbg.AlwaysOnTop=true
        bbg.Size=UDim2.new(0,200,0,50); bbg.StudsOffset=Vector3.new(0,3,0)
        local lbl = Instance.new("TextLabel",bbg)
        lbl.Name="L"; lbl.Size=UDim2.new(1,0,1,0)
        lbl.BackgroundTransparency=1; lbl.TextStrokeTransparency=0
        lbl.TextStrokeColor3=Color3.new(0,0,0)
        lbl.Font=Enum.Font.SourceSansBold; lbl.TextSize=13
        -- Kutu
        local box = Instance.new("BillboardGui", hrp)
        box.Name="MM2BOX"; box.AlwaysOnTop=true
        box.Size=UDim2.new(4.2,0,6,0); box.Adornee=hrp
        local frm = Instance.new("Frame",box)
        frm.Size=UDim2.new(1,0,1,0); frm.BackgroundTransparency=1
        local stk = Instance.new("UIStroke",frm); stk.Thickness=1.5
        espCache[p] = {bbg=bbg, lbl=lbl, box=box, stk=stk}
    end
    p.CharacterAdded:Connect(setup)
    if p.Character then setup(p.Character) end
end
local function destroyESP(p)
    if espCache[p] then
        pcall(function() espCache[p].bbg:Destroy() end)
        pcall(function() espCache[p].box:Destroy() end)
        espCache[p] = nil
    end
end

for _,p in ipairs(Players:GetPlayers()) do buildESP(p) end
Players.PlayerAdded:Connect(buildESP)
Players.PlayerRemoving:Connect(destroyESP)

RunService.RenderStepped:Connect(function()
    local lhrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    for _,p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        if not espCache[p] then buildESP(p) end
        local obj = espCache[p]; if not obj then continue end
        local on = CFG.ESP and p.Character ~= nil
        obj.bbg.Enabled = on
        obj.box.Enabled = on and CFG.ESP_Box
        if not on then continue end
        local role  = getRole(p)
        local color = roleColors[role]
        obj.stk.Color = color
        local hum = p.Character and p.Character:FindFirstChild("Humanoid")
        local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        local hp   = hum and math.round(hum.Health) or 0
        local dist = 0
        if lhrp and hrp then dist = math.round((hrp.Position-lhrp.Position).Magnitude) end
        local t1 = CFG.ESP_Names and (p.Name.." "..roleLabel[role]) or ""
        local t2 = ""
        if CFG.ESP_Health   then t2=t2.."❤"..hp.."  " end
        if CFG.ESP_Distance then t2=t2.."📍"..dist.."m" end
        obj.lbl.Text = t1..(t2~="" and ("\n"..t2) or "")
        obj.lbl.TextColor3 = color
        obj.lbl.Visible = (CFG.ESP_Names or CFG.ESP_Health or CFG.ESP_Distance)
    end
end)

-- ================================================================
-- COIN FARM
-- ================================================================
task.spawn(function()
    while true do
        task.wait(0.2)
        if not CFG.AutoCoinFarm then continue end
        local lhrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not lhrp then continue end
        local best,bd = nil,math.huge
        for _,o in ipairs(Workspace:GetDescendants()) do
            if o:IsA("BasePart") then
                local n = o.Name:lower()
                if n=="coin" or n=="gold" or n=="token" or n:find("coin") then
                    local d=(o.Position-lhrp.Position).Magnitude
                    if d<bd then best=o;bd=d end
                end
            end
        end
        if best then lhrp.CFrame=CFrame.new(best.Position+Vector3.new(0,3,0)) end
    end
end)

-- ================================================================
-- AUTO GRAB GUN
-- ================================================================
task.spawn(function()
    while true do
        task.wait(0.4)
        if not CFG.AutoGrabGun then continue end
        local lhrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not lhrp then continue end
        local best,bd = nil,math.huge
        for _,o in ipairs(Workspace:GetDescendants()) do
            if o:IsA("Tool") and isGun(o.Name) then
                local p = o:FindFirstChildWhichIsA("BasePart")
                if p then
                    local d=(p.Position-lhrp.Position).Magnitude
                    if d<bd then best=p;bd=d end
                end
            end
        end
        if best then lhrp.CFrame=CFrame.new(best.Position+Vector3.new(0,4,0)) end
    end
end)

-- ================================================================
-- SPEED + INF JUMP + NOCLIP + ANTI AFK
-- ================================================================
RunService.Heartbeat:Connect(function()
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
    if not hum then return end
    hum.WalkSpeed = CFG.SpeedHack and CFG.SpeedValue or 16
    hum.JumpPower = CFG.InfiniteJump and 80 or 50
end)
UIS.JumpRequest:Connect(function()
    if not CFG.InfiniteJump then return end
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)
RunService.Stepped:Connect(function()
    if not CFG.NoClip then return end
    local char = LocalPlayer.Character
    if not char then return end
    for _,p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide=false end
    end
end)
task.spawn(function()
    while true do
        task.wait(55)
        if not CFG.AntiAFK then continue end
        pcall(function()
            local vu=game:GetService("VirtualUser")
            vu:Button2Down(Vector2.new(0,0),Workspace.CurrentCamera.CFrame)
            task.wait(0.1)
            vu:Button2Up(Vector2.new(0,0),Workspace.CurrentCamera.CFrame)
        end)
    end
end)

-- ================================================================
-- TELEPORT
-- ================================================================
local function tpTo(hrp)
    local lhrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if lhrp and hrp then lhrp.CFrame = hrp.CFrame + Vector3.new(0,4,0) end
end

-- ================================================================
-- GUI — YATAY MENÜ (620x240), SÜRÜKLENEBILIR
-- ================================================================
local SG = Instance.new("ScreenGui")
SG.Name="MM2Hub"; SG.ResetOnSpawn=false
SG.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
SG.IgnoreGuiInset=true
pcall(function() SG.Parent=game:GetService("CoreGui") end)
if not SG.Parent then SG.Parent=LocalPlayer:WaitForChild("PlayerGui") end

-- Sürükleme (dokunmatik + mouse)
local function drag(frame, handle)
    local dragging, ds, sp
    local h = handle or frame
    h.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1
        or i.UserInputType==Enum.UserInputType.Touch then
            dragging=true; ds=i.Position; sp=frame.Position
            i.Changed:Connect(function()
                if i.UserInputState==Enum.UserInputState.End then dragging=false end
            end)
        end
    end)
    h.InputChanged:Connect(function(i)
        if not dragging then return end
        if i.UserInputType~=Enum.UserInputType.MouseMovement
        and i.UserInputType~=Enum.UserInputType.Touch then return end
        local d=i.Position-ds
        frame.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y)
    end)
end

-- ── AÇMA BUTONU ──────────────────────────────────────────────
local OpenBtn = Instance.new("TextButton",SG)
OpenBtn.Size=UDim2.new(0,46,0,46)
OpenBtn.Position=UDim2.new(0,10,0.5,-23)
OpenBtn.BackgroundColor3=Color3.fromRGB(16,16,18)
OpenBtn.Text="M2"; OpenBtn.TextColor3=Color3.fromRGB(255,60,60)
OpenBtn.Font=Enum.Font.SourceSansBold; OpenBtn.TextSize=15
Instance.new("UICorner",OpenBtn).CornerRadius=UDim.new(1,0)
local os2=Instance.new("UIStroke",OpenBtn)
os2.Color=Color3.fromRGB(255,60,60); os2.Thickness=1.5
drag(OpenBtn)

-- ── ANA PANEL (yatay: 640×230) ────────────────────────────
local Main = Instance.new("Frame",SG)
Main.Name="Main"
Main.Size=UDim2.new(0,640,0,230)
Main.Position=UDim2.new(0.5,-320,0.5,-115)
Main.BackgroundColor3=Color3.fromRGB(12,12,14)
Main.Visible=true; Main.ClipsDescendants=true
Instance.new("UICorner",Main).CornerRadius=UDim.new(0,12)
local ms=Instance.new("UIStroke",Main)
ms.Color=Color3.fromRGB(255,55,55); ms.Thickness=1.2
drag(Main)

-- Üst kırmızı gradient çizgi
local tl=Instance.new("Frame",Main)
tl.Size=UDim2.new(1,0,0,3)
tl.BackgroundColor3=Color3.fromRGB(255,55,55)
Instance.new("UICorner",tl).CornerRadius=UDim.new(0,12)
local tg=Instance.new("UIGradient",tl)
tg.Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.fromRGB(255,40,40)),
    ColorSequenceKeypoint.new(0.5,Color3.fromRGB(255,130,40)),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(255,40,40)),
})

-- ── BAŞLIK ────────────────────────────────────────────────
local TBar=Instance.new("Frame",Main)
TBar.Size=UDim2.new(1,0,0,38); TBar.Position=UDim2.new(0,0,0,3)
TBar.BackgroundColor3=Color3.fromRGB(16,16,18)

local TLbl=Instance.new("TextLabel",TBar)
TLbl.Size=UDim2.new(1,-90,1,0); TLbl.Position=UDim2.new(0,12,0,0)
TLbl.BackgroundTransparency=1; TLbl.TextXAlignment=Enum.TextXAlignment.Left
TLbl.Text="🔪  MM2 HUB  ·  Murder Mystery 2"
TLbl.TextColor3=Color3.fromRGB(230,230,230)
TLbl.Font=Enum.Font.SourceSansBold; TLbl.TextSize=13

local CloseX=Instance.new("TextButton",TBar)
CloseX.Size=UDim2.new(0,26,0,26); CloseX.Position=UDim2.new(1,-34,0.5,-13)
CloseX.BackgroundColor3=Color3.fromRGB(190,40,40)
CloseX.Text="✕"; CloseX.TextColor3=Color3.fromRGB(255,255,255)
CloseX.Font=Enum.Font.SourceSansBold; CloseX.TextSize=13
Instance.new("UICorner",CloseX).CornerRadius=UDim.new(1,0)

-- ── TAB ÇUBUĞU ────────────────────────────────────────────
local TabRow=Instance.new("Frame",Main)
TabRow.Size=UDim2.new(1,-14,0,26); TabRow.Position=UDim2.new(0,7,0,44)
TabRow.BackgroundColor3=Color3.fromRGB(19,19,22)
Instance.new("UICorner",TabRow).CornerRadius=UDim.new(0,7)

local TabLayout=Instance.new("UIListLayout",TabRow)
TabLayout.FillDirection=Enum.FillDirection.Horizontal
TabLayout.VerticalAlignment=Enum.VerticalAlignment.Center
TabLayout.Padding=UDim.new(0,3)
local tp=Instance.new("UIPadding",TabRow)
tp.PaddingLeft=UDim.new(0,4); tp.PaddingRight=UDim.new(0,4)

-- ── İÇERİK ALANI ──────────────────────────────────────────
local ContentArea=Instance.new("Frame",Main)
ContentArea.Size=UDim2.new(1,-14,0,152)
ContentArea.Position=UDim2.new(0,7,0,74)
ContentArea.BackgroundTransparency=1

local TAB_NAMES={"⚔ Savaş","👁 ESP","🌐 Hareket","💰 Farm"}
local ACT=Color3.fromRGB(255,55,55)
local INACT=Color3.fromRGB(26,26,30)

local tabBtns,tabPages={},{}

local function switchTab(idx)
    for i,b in ipairs(tabBtns) do
        b.BackgroundColor3=(i==idx) and ACT or INACT
    end
    for i,p in ipairs(tabPages) do
        p.Visible=(i==idx)
    end
end

for i,name in ipairs(TAB_NAMES) do
    -- Buton
    local tb=Instance.new("TextButton",TabRow)
    tb.Size=UDim2.new(0,136,0,20)
    tb.BackgroundColor3=(i==1) and ACT or INACT
    tb.Text=name; tb.TextColor3=Color3.fromRGB(235,235,235)
    tb.Font=Enum.Font.SourceSansBold; tb.TextSize=11
    Instance.new("UICorner",tb).CornerRadius=UDim.new(0,5)
    tabBtns[i]=tb
    tb.MouseButton1Click:Connect(function() switchTab(i) end)

    -- Sayfa (yatay scroll)
    local sf=Instance.new("ScrollingFrame",ContentArea)
    sf.Size=UDim2.new(1,0,1,0)
    sf.BackgroundTransparency=1
    sf.ScrollBarThickness=2
    sf.ScrollBarImageColor3=Color3.fromRGB(255,55,55)
    sf.CanvasSize=UDim2.new(0,0,0,0)
    sf.AutomaticCanvasSize=Enum.AutomaticSize.X
    sf.ScrollingDirection=Enum.ScrollingDirection.X
    sf.Visible=(i==1)
    tabPages[i]=sf

    local layout=Instance.new("UIListLayout",sf)
    layout.FillDirection=Enum.FillDirection.Horizontal
    layout.VerticalAlignment=Enum.VerticalAlignment.Center
    layout.Padding=UDim.new(0,6)
    local pad=Instance.new("UIPadding",sf)
    pad.PaddingLeft=UDim.new(0,4); pad.PaddingRight=UDim.new(0,4)
end

-- ================================================================
-- WIDGET FONKSİYONLARI
-- ================================================================
local TI=TweenInfo.new(0.12,Enum.EasingStyle.Quad)

-- Toggle kart (128×148)
local function addToggle(tabIdx, icon, label, cfgKey, cb)
    local sf=tabPages[tabIdx]
    local card=Instance.new("Frame",sf)
    card.Size=UDim2.new(0,128,0,148)
    card.BackgroundColor3=Color3.fromRGB(20,20,23)
    Instance.new("UICorner",card).CornerRadius=UDim.new(0,10)
    local cs=Instance.new("UIStroke",card)
    cs.Color=Color3.fromRGB(38,38,44); cs.Thickness=1

    -- Sol şerit (aktif göstergesi)
    local stripe=Instance.new("Frame",card)
    stripe.Size=UDim2.new(0,3,0.65,0); stripe.Position=UDim2.new(0,0,0.175,0)
    stripe.BackgroundColor3=CFG[cfgKey] and ACT or Color3.fromRGB(48,48,55)
    Instance.new("UICorner",stripe).CornerRadius=UDim.new(0,2)

    local iLbl=Instance.new("TextLabel",card)
    iLbl.Size=UDim2.new(1,0,0,42); iLbl.Position=UDim2.new(0,0,0,6)
    iLbl.BackgroundTransparency=1; iLbl.Text=icon; iLbl.TextSize=26

    local nLbl=Instance.new("TextLabel",card)
    nLbl.Size=UDim2.new(1,-8,0,40); nLbl.Position=UDim2.new(0,4,0,50)
    nLbl.BackgroundTransparency=1; nLbl.Text=label
    nLbl.TextColor3=Color3.fromRGB(205,205,205)
    nLbl.Font=Enum.Font.SourceSansBold; nLbl.TextSize=12
    nLbl.TextWrapped=true

    -- Switch
    local swBg=Instance.new("TextButton",card)
    swBg.Size=UDim2.new(0,46,0,22); swBg.Position=UDim2.new(0.5,-23,1,-32)
    swBg.BackgroundColor3=CFG[cfgKey] and ACT or Color3.fromRGB(42,42,48)
    swBg.Text=""
    Instance.new("UICorner",swBg).CornerRadius=UDim.new(1,0)

    local knob=Instance.new("Frame",swBg)
    knob.Size=UDim2.new(0,16,0,16)
    knob.Position=CFG[cfgKey] and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)
    knob.BackgroundColor3=Color3.fromRGB(255,255,255)
    Instance.new("UICorner",knob).CornerRadius=UDim.new(1,0)

    swBg.MouseButton1Click:Connect(function()
        if cfgKey then CFG[cfgKey]=not CFG[cfgKey] end
        local on=cfgKey and CFG[cfgKey] or false
        if cb then cb(on) end
        TweenService:Create(swBg,TI,{BackgroundColor3=on and ACT or Color3.fromRGB(42,42,48)}):Play()
        TweenService:Create(stripe,TI,{BackgroundColor3=on and ACT or Color3.fromRGB(48,48,55)}):Play()
        TweenService:Create(knob,TI,{Position=on and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)}):Play()
    end)
end

-- Aksiyon butonu (teleport vb.)
local function addButton(tabIdx, icon, label, fn)
    local sf=tabPages[tabIdx]
    local card=Instance.new("TextButton",sf)
    card.Size=UDim2.new(0,128,0,148)
    card.BackgroundColor3=Color3.fromRGB(20,20,23)
    card.Text=""
    Instance.new("UICorner",card).CornerRadius=UDim.new(0,10)
    local cs=Instance.new("UIStroke",card)
    cs.Color=Color3.fromRGB(38,38,44); cs.Thickness=1

    local iLbl=Instance.new("TextLabel",card)
    iLbl.Size=UDim2.new(1,0,0,52); iLbl.Position=UDim2.new(0,0,0,16)
    iLbl.BackgroundTransparency=1; iLbl.Text=icon; iLbl.TextSize=30

    local nLbl=Instance.new("TextLabel",card)
    nLbl.Size=UDim2.new(1,-8,0,52); nLbl.Position=UDim2.new(0,4,0,72)
    nLbl.BackgroundTransparency=1; nLbl.Text=label
    nLbl.TextColor3=Color3.fromRGB(200,200,200)
    nLbl.Font=Enum.Font.SourceSansBold; nLbl.TextSize=12
    nLbl.TextWrapped=true

    card.MouseButton1Click:Connect(function()
        TweenService:Create(card,TI,{BackgroundColor3=Color3.fromRGB(200,40,40)}):Play()
        task.delay(0.22,function()
            TweenService:Create(card,TI,{BackgroundColor3=Color3.fromRGB(20,20,23)}):Play()
        end)
        pcall(fn)
    end)
end

-- ================================================================
-- SEKMELER DOLDUR
-- ================================================================

-- TAB 1 — SAVAŞ
addToggle(1,"🎯","Şerif\nSilent Aim","SheriffSilentAim")
addToggle(1,"🔪","Katil\nSilent Aim","KnifeSilentAim")
addToggle(1,"⚔️","Knife\nAura","KnifeAura")
addToggle(1,"🔫","Auto Shoot\nMurderer","AutoShootMurd")

-- TAB 2 — ESP
addToggle(2,"👁","ESP\nAç/Kapat","ESP")
addToggle(2,"👤","İsim +\nRol","ESP_Names")
addToggle(2,"❤","Can\nGöster","ESP_Health")
addToggle(2,"📍","Mesafe\nGöster","ESP_Distance")
addToggle(2,"📦","Kutu\nESP","ESP_Box")

-- TAB 3 — HAREKET
addToggle(3,"💨","Speed\nHack","SpeedHack")
addToggle(3,"🦘","Sonsuz\nZıplama","InfiniteJump")
addToggle(3,"👻","No\nClip","NoClip")
addToggle(3,"🛡","Anti\nAFK","AntiAFK")
addButton(3,"🎯","Katile\nTP", function()
    local m=getMurderer()
    local hrp=m and m.Character and m.Character:FindFirstChild("HumanoidRootPart")
    tpTo(hrp)
end)
addButton(3,"🔫","Şerife\nTP", function()
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and getRole(p)=="sheriff" then
            local hrp=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
            tpTo(hrp); return
        end
    end
end)
addButton(3,"🔫","Silaha\nTP", function()
    local lhrp=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not lhrp then return end
    for _,o in ipairs(Workspace:GetDescendants()) do
        if o:IsA("Tool") and isGun(o.Name) then
            local p=o:FindFirstChildWhichIsA("BasePart")
            if p then lhrp.CFrame=CFrame.new(p.Position+Vector3.new(0,5,0)); return end
        end
    end
end)
addButton(3,"🏃","Rastgele\nOyuncu", function()
    local list={}
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Character then
            local hrp=p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then table.insert(list,hrp) end
        end
    end
    if #list>0 then tpTo(list[math.random(1,#list)]) end
end)

-- TAB 4 — FARM
addToggle(4,"💰","Auto\nCoin Farm","AutoCoinFarm")
addToggle(4,"🔫","Auto\nGrab Gun","AutoGrabGun")

-- ================================================================
-- AÇMA / KAPATMA
-- ================================================================
OpenBtn.MouseButton1Click:Connect(function()
    Main.Visible=not Main.Visible
end)
CloseX.MouseButton1Click:Connect(function()
    Main.Visible=false
end)

-- ================================================================
-- BİLDİRİM
-- ================================================================
local function notify(msg)
    local StarterGui = game:GetService("StarterGui")
    pcall(function()
        StarterGui:SetCore("SendNotification",{
            Title="MM2 Hub"; Text=msg; Duration=3
        })
    end)
end

if saHooked then
    notify("✅ Silent Aim hook başarılı!")
else
    notify("⚠️ Silent Aim hook desteklenmiyor. Diğer özellikler çalışıyor.")
end
