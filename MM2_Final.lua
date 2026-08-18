--[[
    MM2 Final Script — Delta Mobile 2026
    ✅ Highlight ESP (Native Roblox — duvardan gösterir, her zaman çalışır)
    ✅ Box ESP — ince çizgi, role göre renk
    ✅ Silah Chams — yere düşünce mor renk
    ✅ Silahı alan kişi → Mavi highlight
    ✅ Sheriff Silent Aim — sadece katile kilitler
    ✅ Küçük sürüklenebilir menü
    
    Renkler:
      Katil   → Kırmızı
      Şerif   → Mavi  
      Masum   → Yeşil
      Silah   → Mor (chams)
      Silahı alan → Mavi
]]

local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local TweenService    = game:GetService("TweenService")
local Workspace       = game:GetService("Workspace")
local LocalPlayer     = Players.LocalPlayer

-- ============================================================
-- AYARLAR
-- ============================================================
local CFG = {
    ESP         = false,
    GunChams    = false,
    SilentAim   = false,
}

-- ============================================================
-- ROL TESPİTİ
-- ============================================================
local KNIFE_KEYS = {"knife","blade","saber","scythe","murd","dark","luger","machete","saw"}
local GUN_KEYS   = {"gun","sheriff","revolver","pistol","sniper","deagle"}

local function hasKey(name, keys)
    name = name:lower()
    for _,k in ipairs(keys) do
        if name:find(k,1,true) then return true end
    end
    return false
end

local function getRole(player)
    local char = player and player.Character
    if not char then return "innocent" end
    local tool = char:FindFirstChildWhichIsA("Tool")
    if not tool then return "innocent" end
    if hasKey(tool.Name, KNIFE_KEYS) then return "murderer" end
    if hasKey(tool.Name, GUN_KEYS)   then return "sheriff"  end
    -- Silahı taşıyan (dropped gun aldıysa) → sheriff muamelesi
    return "innocent"
end

local function getMurderer()
    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and getRole(p) == "murderer" then
            return p
        end
    end
    return nil
end

-- ============================================================
-- RENK TABLOSU
-- ============================================================
local COLORS = {
    murderer  = Color3.fromRGB(255, 50,  50),   -- Kırmızı
    sheriff   = Color3.fromRGB(60,  130, 255),  -- Mavi
    innocent  = Color3.fromRGB(55,  210, 80),   -- Yeşil
    gun       = Color3.fromRGB(180, 60,  255),  -- Mor (silah chams)
    gunholder = Color3.fromRGB(60,  130, 255),  -- Mavi (silahı alan)
}

-- ============================================================
-- HIGHLIGHT ESP SİSTEMİ
-- Native Roblox Highlight = duvardan gösterir, BillboardGui'den çok daha stabil
-- ============================================================
local highlights = {}  -- player → Highlight instance
local boxEsps    = {}  -- player → {bbg, stroke}

-- Oyuncu için Highlight oluştur
local function createHighlight(player)
    if player == LocalPlayer then return end
    if highlights[player] then return end

    local hl = Instance.new("Highlight")
    hl.Name          = "MM2_HL"
    hl.DepthMode     = Enum.HighlightDepthMode.AlwaysOnTop  -- duvardan göster
    hl.FillTransparency  = 1      -- içi boş (sadece kenar çizgisi)
    hl.OutlineTransparency = 0    -- ince çizgi kenar
    hl.OutlineColor  = COLORS.innocent
    hl.Enabled       = false
    -- Character'e parent'le
    if player.Character then
        hl.Adornee = player.Character
        hl.Parent  = player.Character
    end
    highlights[player] = hl

    player.CharacterAdded:Connect(function(char)
        hl.Adornee = char
        hl.Parent  = char
    end)
end

-- Tüm oyuncular için highlight kur
for _,p in ipairs(Players:GetPlayers()) do createHighlight(p) end
Players.PlayerAdded:Connect(function(p)
    task.wait(1)
    createHighlight(p)
end)
Players.PlayerRemoving:Connect(function(p)
    if highlights[p] then
        pcall(function() highlights[p]:Destroy() end)
        highlights[p] = nil
    end
end)

-- Box ESP (BillboardGui — ince çizgi kutu, ayrıca overlay olarak)
local function createBoxESP(player)
    if player == LocalPlayer then return end
    if boxEsps[player] then return end

    local function setup(char)
        task.wait(0.3)
        local hrp = char:WaitForChild("HumanoidRootPart", 8)
        if not hrp then return end

        -- Eski temizle
        local old = hrp:FindFirstChild("MM2_BOX")
        if old then old:Destroy() end

        local bbg = Instance.new("BillboardGui", hrp)
        bbg.Name        = "MM2_BOX"
        bbg.AlwaysOnTop = true
        bbg.Size        = UDim2.new(4.4, 0, 6.2, 0)
        bbg.Adornee     = hrp
        bbg.Enabled     = false

        local frame = Instance.new("Frame", bbg)
        frame.Size                  = UDim2.new(1, 0, 1, 0)
        frame.BackgroundTransparency = 1

        local stroke = Instance.new("UIStroke", frame)
        stroke.Thickness = 1.2
        stroke.Color     = COLORS.innocent
        stroke.LineJoinMode = Enum.LineJoinMode.Round

        boxEsps[player] = { bbg = bbg, stroke = stroke }
    end

    player.CharacterAdded:Connect(setup)
    if player.Character then setup(player.Character) end
end

for _,p in ipairs(Players:GetPlayers()) do createBoxESP(p) end
Players.PlayerAdded:Connect(function(p)
    task.wait(1)
    createBoxESP(p)
end)
Players.PlayerRemoving:Connect(function(p)
    if boxEsps[p] then
        pcall(function() boxEsps[p].bbg:Destroy() end)
        boxEsps[p] = nil
    end
end)

-- ============================================================
-- ESP + CHAMS GÜNCELLEME DÖNGÜSÜ
-- ============================================================
RunService.RenderStepped:Connect(function()
    -- Silahı elinde tutan kişiyi bul
    local gunHolder = nil
    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local tool = p.Character:FindFirstChildWhichIsA("Tool")
            if tool and hasKey(tool.Name, GUN_KEYS) then
                gunHolder = p
                break
            end
        end
    end

    for _,p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end

        local hl  = highlights[p]
        local box = boxEsps[p]
        local role = getRole(p)

        -- Rengi belirle
        local color
        if p == gunHolder then
            color = COLORS.gunholder   -- silahı alan → mavi
        elseif role == "murderer" then
            color = COLORS.murderer
        elseif role == "sheriff" then
            color = COLORS.sheriff
        else
            color = COLORS.innocent
        end

        -- Highlight güncelle
        if hl then
            hl.Enabled      = CFG.ESP
            hl.OutlineColor = color
        end

        -- Box güncelle
        if box then
            box.bbg.Enabled  = CFG.ESP
            box.stroke.Color = color
        end
    end
end)

-- ============================================================
-- SİLAH CHAMS (Yere düşen silah → Mor Highlight)
-- ============================================================
local gunHighlights = {}   -- part → Highlight

local function applyGunChams(tool)
    -- Workspace'te bulunan tool (yerde duran)
    if not tool:IsA("Tool") then return end
    if not hasKey(tool.Name, GUN_KEYS) then return end
    -- Eğer bir oyuncunun character'inde değilse → yerde demektir
    if tool.Parent:IsA("Model") and Players:GetPlayerFromCharacter(tool.Parent) then
        -- Oyuncunun elinde, chams gerekmez
        if gunHighlights[tool] then
            gunHighlights[tool]:Destroy()
            gunHighlights[tool] = nil
        end
        return
    end

    if gunHighlights[tool] then return end

    local hl = Instance.new("Highlight", tool)
    hl.Name                = "MM2_GUN_HL"
    hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillColor           = COLORS.gun
    hl.FillTransparency    = 0.4
    hl.OutlineColor        = COLORS.gun
    hl.OutlineTransparency = 0
    hl.Enabled             = CFG.GunChams
    gunHighlights[tool] = hl

    -- Tool silinince temizle
    tool.AncestryChanged:Connect(function()
        if not tool.Parent then
            if gunHighlights[tool] then
                pcall(function() gunHighlights[tool]:Destroy() end)
                gunHighlights[tool] = nil
            end
        end
    end)
end

-- Workspace'e yeni gelen toolları izle
Workspace.DescendantAdded:Connect(function(obj)
    if CFG.GunChams then
        task.wait(0.1)
        applyGunChams(obj)
    end
end)

-- Gun chams toggle
local function refreshGunChams()
    -- Mevcut workspace araçlarını tara
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Tool") and hasKey(obj.Name, GUN_KEYS) then
            applyGunChams(obj)
        end
    end
    -- Var olan highlight'ları güncelle
    for _, hl in pairs(gunHighlights) do
        hl.Enabled = CFG.GunChams
    end
end

-- ============================================================
-- SILENT AIM — Sadece Şerif için, sadece Katile hedefler
-- Delta'da çalışan: __namecall + mouse.Hit çift yöntem
-- ============================================================
local saActive = false

-- Yöntem 1: __namecall hook (FireServer yakala)
pcall(function()
    if not (hookmetamethod and getrawmetatable and newcclosure and getnamecallmethod) then return end
    local mt = getrawmetatable(game)
    local orig = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == "FireServer" and CFG.SilentAim then
            -- Sadece şerifsek
            if getRole(LocalPlayer) == "sheriff" then
                local murd = getMurderer()
                if murd and murd.Character then
                    local head = murd.Character:FindFirstChild("Head")
                    if head then
                        local args = {...}
                        -- İlk CFrame/Vector3 argümanını katile yönlendir
                        for i = 1, #args do
                            if typeof(args[i]) == "CFrame" then
                                args[i] = CFrame.new(head.Position)
                                return orig(self, table.unpack(args))
                            elseif typeof(args[i]) == "Vector3" then
                                args[i] = head.Position
                                return orig(self, table.unpack(args))
                            end
                        end
                        -- Argüman yoksa ekle
                        return orig(self, CFrame.new(head.Position), table.unpack({...}))
                    end
                end
            end
        end
        return orig(self, ...)
    end)
    setreadonly(mt, true)
    saActive = true
end)

-- Yöntem 2: mouse.Hit hook (yedek)
if not saActive then
    pcall(function()
        if not (hookmetamethod and getrawmetatable and checkcaller and newcclosure) then return end
        local mt = getrawmetatable(game)
        local orig = mt.__index
        setreadonly(mt, false)
        mt.__index = newcclosure(function(self, key)
            if not checkcaller() and key == "Hit" then
                local ok, isMouse = pcall(function() return self:IsA("Mouse") end)
                if ok and isMouse and CFG.SilentAim then
                    if getRole(LocalPlayer) == "sheriff" then
                        local murd = getMurderer()
                        local head = murd and murd.Character and murd.Character:FindFirstChild("Head")
                        if head then
                            return CFrame.new(head.Position)
                        end
                    end
                end
            end
            return orig(self, key)
        end)
        setreadonly(mt, true)
        saActive = true
    end)
end

-- ============================================================
-- GUI — KÜÇÜK SÜRÜKLENEBILIR MENÜ
-- ============================================================
local SG = Instance.new("ScreenGui")
SG.Name          = "MM2FinalHUB"
SG.ResetOnSpawn  = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.IgnoreGuiInset = true
pcall(function() SG.Parent = game:GetService("CoreGui") end)
if not SG.Parent then SG.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- Sürükleme fonksiyonu (dokunmatik + mouse)
local function makeDraggable(frame, handle)
    local dragging, ds, sp
    local h = handle or frame
    h.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            ds = i.Position
            sp = frame.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    h.InputChanged:Connect(function(i)
        if not dragging then return end
        if i.UserInputType ~= Enum.UserInputType.MouseMovement
        and i.UserInputType ~= Enum.UserInputType.Touch then return end
        local d = i.Position - ds
        frame.Position = UDim2.new(
            sp.X.Scale, sp.X.Offset + d.X,
            sp.Y.Scale, sp.Y.Offset + d.Y
        )
    end)
end

-- ── ANA PANEL ───────────────────────────────────────────────
local Panel = Instance.new("Frame", SG)
Panel.Name             = "Panel"
Panel.Size             = UDim2.new(0, 200, 0, 180)
Panel.Position         = UDim2.new(0, 20, 0.5, -90)
Panel.BackgroundColor3 = Color3.fromRGB(13, 13, 16)
Panel.Visible          = true
Instance.new("UICorner", Panel).CornerRadius = UDim.new(0, 10)
local panelStroke = Instance.new("UIStroke", Panel)
panelStroke.Color     = Color3.fromRGB(255, 50, 50)
panelStroke.Thickness = 1.2
makeDraggable(Panel)

-- Üst kırmızı çizgi
local topStripe = Instance.new("Frame", Panel)
topStripe.Size             = UDim2.new(1, 0, 0, 3)
topStripe.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
Instance.new("UICorner", topStripe).CornerRadius = UDim.new(0, 10)
local stripeGrad = Instance.new("UIGradient", topStripe)
stripeGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 40, 40)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 120, 40)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(255, 40, 40)),
})

-- Başlık satırı
local TitleBar = Instance.new("Frame", Panel)
TitleBar.Size             = UDim2.new(1, 0, 0, 36)
TitleBar.Position         = UDim2.new(0, 0, 0, 3)
TitleBar.BackgroundColor3 = Color3.fromRGB(18, 18, 22)

local TitleLbl = Instance.new("TextLabel", TitleBar)
TitleLbl.Size               = UDim2.new(1, -36, 1, 0)
TitleLbl.Position           = UDim2.new(0, 10, 0, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text               = "🔪 MM2 Hub"
TitleLbl.TextColor3         = Color3.fromRGB(230, 230, 230)
TitleLbl.Font               = Enum.Font.SourceSansBold
TitleLbl.TextSize           = 14
TitleLbl.TextXAlignment     = Enum.TextXAlignment.Left

-- Küçült butonu
local MinBtn = Instance.new("TextButton", TitleBar)
MinBtn.Size             = UDim2.new(0, 24, 0, 24)
MinBtn.Position         = UDim2.new(1, -30, 0.5, -12)
MinBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
MinBtn.Text             = "—"
MinBtn.TextColor3       = Color3.fromRGB(200, 200, 200)
MinBtn.Font             = Enum.Font.SourceSansBold
MinBtn.TextSize         = 12
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(1, 0)

-- İçerik alanı
local Content = Instance.new("Frame", Panel)
Content.Name             = "Content"
Content.Size             = UDim2.new(1, 0, 1, -39)
Content.Position         = UDim2.new(0, 0, 0, 39)
Content.BackgroundTransparency = 1

local ContentLayout = Instance.new("UIListLayout", Content)
ContentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
ContentLayout.VerticalAlignment   = Enum.VerticalAlignment.Top
ContentLayout.SortOrder           = Enum.SortOrder.LayoutOrder
ContentLayout.Padding             = UDim.new(0, 4)
local ContentPad = Instance.new("UIPadding", Content)
ContentPad.PaddingTop    = UDim.new(0, 6)
ContentPad.PaddingLeft   = UDim.new(0, 8)
ContentPad.PaddingRight  = UDim.new(0, 8)

-- ── TOGGLE OLUŞTURUCU ────────────────────────────────────────
local TI = TweenInfo.new(0.13, Enum.EasingStyle.Quad)
local ON_COLOR  = Color3.fromRGB(255, 50, 50)
local OFF_COLOR = Color3.fromRGB(38, 38, 48)

local toggleOrder = 0
local function addToggle(label, icon, cfgKey, onCallback, offCallback)
    toggleOrder = toggleOrder + 1

    local row = Instance.new("Frame", Content)
    row.Size             = UDim2.new(1, 0, 0, 38)
    row.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    row.LayoutOrder      = toggleOrder
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 7)
    local rowStroke = Instance.new("UIStroke", row)
    rowStroke.Color = Color3.fromRGB(38, 38, 50); rowStroke.Thickness = 1

    -- Aktif şerit
    local activeStripe = Instance.new("Frame", row)
    activeStripe.Size             = UDim2.new(0, 3, 0.6, 0)
    activeStripe.Position         = UDim2.new(0, 0, 0.2, 0)
    activeStripe.BackgroundColor3 = CFG[cfgKey] and ON_COLOR or Color3.fromRGB(50, 50, 60)
    Instance.new("UICorner", activeStripe).CornerRadius = UDim.new(0, 2)

    -- İkon
    local iconLbl = Instance.new("TextLabel", row)
    iconLbl.Size               = UDim2.new(0, 28, 1, 0)
    iconLbl.Position           = UDim2.new(0, 6, 0, 0)
    iconLbl.BackgroundTransparency = 1
    iconLbl.Text               = icon
    iconLbl.TextSize           = 16

    -- Etiket
    local nameLbl = Instance.new("TextLabel", row)
    nameLbl.Size               = UDim2.new(1, -80, 1, 0)
    nameLbl.Position           = UDim2.new(0, 36, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text               = label
    nameLbl.TextColor3         = Color3.fromRGB(210, 210, 210)
    nameLbl.Font               = Enum.Font.SourceSansBold
    nameLbl.TextSize           = 12
    nameLbl.TextXAlignment     = Enum.TextXAlignment.Left

    -- Switch arkaplanı
    local swBg = Instance.new("TextButton", row)
    swBg.Size             = UDim2.new(0, 40, 0, 20)
    swBg.Position         = UDim2.new(1, -46, 0.5, -10)
    swBg.BackgroundColor3 = CFG[cfgKey] and ON_COLOR or OFF_COLOR
    swBg.Text             = ""
    Instance.new("UICorner", swBg).CornerRadius = UDim.new(1, 0)

    -- Switch topu
    local knob = Instance.new("Frame", swBg)
    knob.Size             = UDim2.new(0, 14, 0, 14)
    knob.Position         = CFG[cfgKey]
        and UDim2.new(1, -17, 0.5, -7)
        or  UDim2.new(0, 3,  0.5, -7)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local function toggle()
        CFG[cfgKey] = not CFG[cfgKey]
        local on = CFG[cfgKey]

        TweenService:Create(swBg,     TI, { BackgroundColor3 = on and ON_COLOR or OFF_COLOR }):Play()
        TweenService:Create(activeStripe, TI, { BackgroundColor3 = on and ON_COLOR or Color3.fromRGB(50,50,60) }):Play()
        TweenService:Create(knob,     TI, {
            Position = on and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7)
        }):Play()

        if on and onCallback  then onCallback()  end
        if not on and offCallback then offCallback() end
    end

    -- Hem butona hem satıra tıklanabilir
    swBg.MouseButton1Click:Connect(toggle)
    row.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            toggle()
        end
    end)
end

-- ── MENÜ TOGGLE'LARI ─────────────────────────────────────────
addToggle("Box ESP",      "👁",  "ESP",       nil, nil)
addToggle("Silah Chams",  "🔫", "GunChams",
    function() refreshGunChams() end,
    function()
        for _,hl in pairs(gunHighlights) do hl.Enabled = false end
    end
)
addToggle("Silent Aim",   "🎯", "SilentAim", nil, nil)

-- Renk efsanesi (bilgi satırı)
local legendRow = Instance.new("Frame", Content)
legendRow.Size             = UDim2.new(1, 0, 0, 24)
legendRow.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
legendRow.LayoutOrder      = 99
Instance.new("UICorner", legendRow).CornerRadius = UDim.new(0, 6)

local legendLbl = Instance.new("TextLabel", legendRow)
legendLbl.Size               = UDim2.new(1, -8, 1, 0)
legendLbl.Position           = UDim2.new(0, 4, 0, 0)
legendLbl.BackgroundTransparency = 1
legendLbl.Text               = "🔴Katil  🔵Şerif  🟢Masum"
legendLbl.TextColor3         = Color3.fromRGB(160, 160, 160)
legendLbl.Font               = Enum.Font.SourceSans
legendLbl.TextSize           = 10
legendLbl.TextXAlignment     = Enum.TextXAlignment.Center

-- ── KÜÇÜLT / AÇ ─────────────────────────────────────────────
local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        TweenService:Create(Panel, TweenInfo.new(0.2), {
            Size = UDim2.new(0, 200, 0, 39)
        }):Play()
        Content.Visible  = false
        MinBtn.Text = "+"
    else
        Content.Visible  = true
        TweenService:Create(Panel, TweenInfo.new(0.2), {
            Size = UDim2.new(0, 200, 0, 180)
        }):Play()
        MinBtn.Text = "—"
    end
end)

-- ============================================================
-- BİLDİRİM
-- ============================================================
task.wait(0.5)
pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title    = "MM2 Hub";
        Text     = saActive
            and "✅ Yüklendi! Silent Aim aktif."
            or  "✅ Yüklendi! (Silent Aim = executor hookmetamethod gerektiriyor)";
        Duration = 4;
    })
end)
