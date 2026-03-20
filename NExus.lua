--[[
    NEXUS OMEGA - Murder Mystery 2
    Versão Otimizada com ESP Profissional e Menu Funcional
]]

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- Verifica se pode escrever arquivos (para salvar configurações)
local canWrite = pcall(function() writefile("test.txt", "test") end)
if canWrite then writefile("test.txt", "") end

-- ==================== CONFIGURAÇÕES ====================
local Settings = {
    Aimbot = { Enabled = false, Silent = false, FOV = 150, Target = "Murderer", Smoothness = 50 },
    ESP = { 
        Enabled = true, 
        Players = true, 
        Items = false, 
        Tracers = true, 
        Aura = true,
        ShowNames = true,
        Colors = { 
            Murderer = Color3.fromRGB(255,0,0), 
            Sheriff = Color3.fromRGB(0,100,255), 
            Innocent = Color3.fromRGB(0,255,0), 
            Knife = Color3.fromRGB(255,165,0), 
            Coin = Color3.fromRGB(255,255,0) 
        } 
    },
    AutoFarm = { Collect = false, Reset = false, AutoPlay = false },
    Movement = { Fly = false, Speed = 16, AntiAFK = true },
    Combat = { KillAll = false, InstantWin = false, AutoParry = false },
    Protection = { AntiBan = true, Webhook = "", CheckUpdates = false },
    Misc = { AutoBuy = false, Stealth = false },
    UI = { Opacity = 0.9, PrimaryColor = "Purple", Sounds = false }
}

local ColorSchemes = { Purple = Color3.fromRGB(138,43,226), Blue = Color3.fromRGB(0,100,255), Red = Color3.fromRGB(255,50,50) }
local PrimaryColor = ColorSchemes[Settings.UI.PrimaryColor]

-- ==================== VARIÁVEIS GLOBAIS ====================
local Gui = nil
local FloatingButton = nil
local MainMenu = nil
local MenuOpen = false
local Dragging = false
local DragStart, DragStartPos
local ESPObjects = {}
local RadarFrame = nil
local CurrentCategory = "Aimbot"
local Flying = false
local FlyBodyVelocity = nil
local FlyConnection = nil
local LastRemoteCall = 0
local AttackRemote = nil
local KillAllRemote = nil
local InstantWinRemote = nil
local originalFire = nil

-- ==================== FUNÇÕES AUXILIARES ====================
function SaveSettings()
    if not canWrite then return end
    local data = HttpService:JSONEncode(Settings)
    writefile("NexusOmega.json", data)
end

function LoadSettings()
    if not canWrite or not isfile("NexusOmega.json") then return end
    local data = readfile("NexusOmega.json")
    if data and data ~= "" then
        local loaded = HttpService:JSONDecode(data)
        for cat, vals in pairs(loaded) do
            if Settings[cat] then
                for k, v in pairs(vals) do
                    Settings[cat][k] = v
                end
            end
        end
    end
    PrimaryColor = ColorSchemes[Settings.UI.PrimaryColor] or ColorSchemes.Purple
end

function Notify(text)
    if not Gui then return end
    local notif = Instance.new("Frame")
    notif.Size = UDim2.new(0, 250, 0, 40)
    notif.Position = UDim2.new(1, -270, 0, 10)
    notif.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    notif.BackgroundTransparency = 0.2
    notif.BorderSizePixel = 0
    notif.Parent = Gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = notif
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 1, 0)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(255,255,255)
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = notif
    TweenService:Create(notif, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Position = UDim2.new(1, -270, 0, 10) }):Play()
    wait(2)
    TweenService:Create(notif, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Position = UDim2.new(1, -10, 0, 10) }):Play()
    wait(0.5)
    notif:Destroy()
end

local function SafeFireRemote(remote, ...)
    if Settings.Protection.AntiBan then
        local now = tick()
        if now - LastRemoteCall < 0.5 then wait(0.5 - (now - LastRemoteCall)) end
        LastRemoteCall = tick()
        wait(math.random(2,6)/10)
    end
    if remote then remote:FireServer(...) end
end

-- ==================== ESP PROFISSIONAL (DRAWING) ====================
local function CreateESP()
    -- Limpar objetos antigos
    for _, obj in pairs(ESPObjects) do
        if obj.box then obj.box:Remove() end
        if obj.name then obj.name:Remove() end
        if obj.tracer then obj.tracer:Remove() end
        if obj.aura then obj.aura:Remove() end
    end
    ESPObjects = {}
    if not Settings.ESP.Enabled or not Settings.ESP.Players then return end

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local role = player:GetAttribute("Role") or (player.Team and player.Team.Name) or ""
            local color = Settings.ESP.Colors.Innocent
            if role == "Murderer" then color = Settings.ESP.Colors.Murderer
            elseif role == "Sheriff" then color = Settings.ESP.Colors.Sheriff end

            -- Caixa (Box)
            local box = Drawing.new("Square")
            box.Thickness = 2
            box.Color = color
            box.Visible = false
            box.Filled = false

            -- Nome
            local name = Drawing.new("Text")
            name.Text = player.Name
            name.Size = 14
            name.Center = true
            name.Outline = true
            name.Color = color
            name.Visible = false

            -- Tracer (linha do pé até o chão)
            local tracer = Drawing.new("Line")
            tracer.Thickness = 1.5
            tracer.Color = color
            tracer.Visible = false

            -- Aura (círculo difuso ao redor)
            local aura = Drawing.new("Circle")
            aura.Thickness = 1
            aura.NumSides = 32
            aura.Filled = true
            aura.Transparency = 0.6
            aura.Color = color
            aura.Visible = false

            ESPObjects[player] = { box = box, name = name, tracer = tracer, aura = aura }
        end
    end
end

local function UpdateESP()
    if not Settings.ESP.Enabled or not Settings.ESP.Players then return end

    local localPos = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position or Vector3.new()
    local screenSize = Camera.ViewportSize

    for player, objs in pairs(ESPObjects) do
        if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local root = player.Character.HumanoidRootPart
            local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
            local footPos = root.Position - Vector3.new(0, 3, 0)
            local footScreen, footOn = Camera:WorldToViewportPoint(footPos)

            if onScreen then
                -- Caixa
                if objs.box then
                    local size = player.Character:GetExtentsSize()
                    local width = size.X * 5
                    local height = size.Y * 5
                    local boxPos = Vector2.new(pos.X - width/2, pos.Y - height/2)
                    objs.box.Size = Vector2.new(width, height)
                    objs.box.Position = boxPos
                    objs.box.Visible = true
                end

                -- Nome
                if objs.name and Settings.ESP.ShowNames then
                    objs.name.Position = Vector2.new(pos.X, pos.Y - 20)
                    objs.name.Visible = true
                end

                -- Aura (círculo ao redor)
                if objs.aura and Settings.ESP.Aura then
                    local size = player.Character:GetExtentsSize()
                    local radius = math.max(size.X, size.Y) * 3
                    objs.aura.Radius = radius
                    objs.aura.Position = Vector2.new(pos.X, pos.Y)
                    objs.aura.Visible = true
                end

                -- Tracer (linha do pé até a base da tela)
                if objs.tracer and Settings.ESP.Tracers and footOn then
                    objs.tracer.From = Vector2.new(footScreen.X, footScreen.Y)
                    objs.tracer.To = Vector2.new(footScreen.X, screenSize.Y)
                    objs.tracer.Visible = true
                elseif objs.tracer then
                    objs.tracer.Visible = false
                end
            else
                if objs.box then objs.box.Visible = false end
                if objs.name then objs.name.Visible = false end
                if objs.tracer then objs.tracer.Visible = false end
                if objs.aura then objs.aura.Visible = false end
            end
        else
            if objs.box then objs.box.Visible = false end
            if objs.name then objs.name.Visible = false end
            if objs.tracer then objs.tracer.Visible = false end
            if objs.aura then objs.aura.Visible = false end
        end
    end
end

function ClearESP()
    for _, obj in pairs(ESPObjects) do
        if obj.box then obj.box:Remove() end
        if obj.name then obj.name:Remove() end
        if obj.tracer then obj.tracer:Remove() end
        if obj.aura then obj.aura:Remove() end
    end
    ESPObjects = {}
end

-- ==================== RADAR (opcional) ====================
local function CreateRadar()
    if RadarFrame then RadarFrame:Destroy() end
    RadarFrame = Instance.new("Frame")
    RadarFrame.Size = UDim2.new(0, 150, 0, 150)
    RadarFrame.Position = UDim2.new(1, -160, 1, -160)
    RadarFrame.BackgroundColor3 = Color3.fromRGB(0,0,0)
    RadarFrame.BackgroundTransparency = 0.5
    RadarFrame.BorderSizePixel = 0
    RadarFrame.Parent = Gui
    local radarCorner = Instance.new("UICorner")
    radarCorner.CornerRadius = UDim.new(0,75)
    radarCorner.Parent = RadarFrame
    RunService.RenderStepped:Connect(function()
        if not Settings.ESP.Radar then return end
        for _, child in pairs(RadarFrame:GetChildren()) do
            if child:IsA("ImageLabel") then child:Destroy() end
        end
        local center = RadarFrame.AbsoluteSize / 2
        local localPos = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position or Vector3.new()
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                local relative = player.Character.HumanoidRootPart.Position - localPos
                local angle = math.atan2(relative.X, relative.Z)
                local dist = relative.Magnitude / 10
                local x = center.X + math.sin(angle) * dist
                local z = center.Y + math.cos(angle) * dist
                if x > 0 and x < RadarFrame.AbsoluteSize.X and z > 0 and z < RadarFrame.AbsoluteSize.Y then
                    local dot = Instance.new("ImageLabel")
                    dot.Size = UDim2.new(0,4,0,4)
                    dot.Position = UDim2.new(0,x,0,z)
                    dot.BackgroundColor3 = Settings.ESP.Colors[player:GetAttribute("Role")] or Settings.ESP.Colors.Innocent
                    dot.BackgroundTransparency = 0
                    dot.Image = ""
                    dot.Parent = RadarFrame
                end
            end
        end
    end)
end

-- ==================== FLY ====================
local function EnableFly()
    if not Settings.Movement.Fly or Flying then return end
    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end
    Flying = true
    humanoid.PlatformStand = true
    FlyBodyVelocity = Instance.new("BodyVelocity")
    FlyBodyVelocity.MaxForce = Vector3.new(100000,100000,100000)
    FlyBodyVelocity.Velocity = Vector3.new(0,0,0)
    FlyBodyVelocity.Parent = character:FindFirstChild("HumanoidRootPart")
    local moveVector = Vector3.new(0,0,0)
    local speed = 50
    local function updateFly()
        if not Flying or not FlyBodyVelocity then return end
        local root = character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local camCFrame = Camera.CFrame
        local forward = camCFrame.LookVector
        local right = camCFrame.RightVector
        local up = Vector3.new(0,1,0)
        local velocity = (forward * moveVector.Z + right * moveVector.X + up * moveVector.Y) * speed
        FlyBodyVelocity.Velocity = velocity
    end
    FlyConnection = RunService.RenderStepped:Connect(updateFly)
    local function onInputBegan(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.W then moveVector = moveVector + Vector3.new(0,0,1) end
        if input.KeyCode == Enum.KeyCode.S then moveVector = moveVector + Vector3.new(0,0,-1) end
        if input.KeyCode == Enum.KeyCode.A then moveVector = moveVector + Vector3.new(-1,0,0) end
        if input.KeyCode == Enum.KeyCode.D then moveVector = moveVector + Vector3.new(1,0,0) end
        if input.KeyCode == Enum.KeyCode.Space then moveVector = moveVector + Vector3.new(0,1,0) end
        if input.KeyCode == Enum.KeyCode.LeftControl then moveVector = moveVector + Vector3.new(0,-1,0) end
    end
    local function onInputEnded(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.W then moveVector = moveVector - Vector3.new(0,0,1) end
        if input.KeyCode == Enum.KeyCode.S then moveVector = moveVector - Vector3.new(0,0,-1) end
        if input.KeyCode == Enum.KeyCode.A then moveVector = moveVector - Vector3.new(-1,0,0) end
        if input.KeyCode == Enum.KeyCode.D then moveVector = moveVector - Vector3.new(1,0,0) end
        if input.KeyCode == Enum.KeyCode.Space then moveVector = moveVector - Vector3.new(0,1,0) end
        if input.KeyCode == Enum.KeyCode.LeftControl then moveVector = moveVector - Vector3.new(0,-1,0) end
    end
    UserInputService.InputBegan:Connect(onInputBegan)
    UserInputService.InputEnded:Connect(onInputEnded)
end

local function DisableFly()
    if not Flying then return end
    Flying = false
    local character = LocalPlayer.Character
    if character then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then humanoid.PlatformStand = false end
        if FlyBodyVelocity then FlyBodyVelocity:Destroy() end
    end
    if FlyConnection then FlyConnection:Disconnect() end
    FlyBodyVelocity = nil
    FlyConnection = nil
end

-- ==================== FUNCIONALIDADES ====================
local function AutoCollect()
    if not Settings.AutoFarm.Collect then return end
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and (obj.Name:find("Coin") or obj.Name:find("Knife")) then
            local click = obj:FindFirstChildOfClass("ClickDetector")
            if click then click:FireClick() end
        end
    end
end

local function AutoReset()
    if not Settings.AutoFarm.Reset then return end
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("Humanoid") or character.Humanoid.Health <= 0 then
        wait(3)
        local respawnButton = game:GetService("StarterGui"):FindFirstChild("RespawnButton")
        if respawnButton then respawnButton:FireClick() end
        local remote = ReplicatedStorage:FindFirstChild("RespawnEvent")
        if remote then SafeFireRemote(remote) end
    end
end

local function AutoPlay()
    if not Settings.AutoFarm.AutoPlay then return end
    local screenGui = LocalPlayer:FindFirstChild("PlayerGui")
    if screenGui then
        local endScreen = screenGui:FindFirstChild("RoundEndScreen")
        if endScreen and endScreen.Visible then
            local nextButton = endScreen:FindFirstChild("NextButton")
            if nextButton then nextButton:FireClick() end
        end
    end
end

local function KillAll()
    if KillAllRemote then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                SafeFireRemote(KillAllRemote, player)
            end
        end
        Notify("Kill All")
    else
        Notify("Remote de kill não encontrado")
    end
end

local function InstantWin()
    if InstantWinRemote then
        SafeFireRemote(InstantWinRemote)
        Notify("Instant Win")
    else
        Notify("Remote de win não encontrado")
    end
end

local function AntiAFK()
    if not Settings.Movement.AntiAFK then return end
    local mouse = LocalPlayer:GetMouse()
    local pos = mouse.X
    mouse.Move(Vector2.new(pos + 1, mouse.Y))
    wait(0.1)
    mouse.Move(Vector2.new(pos, mouse.Y))
end

local function AutoBuy()
    if not Settings.Misc.AutoBuy then return end
    local shopGui = LocalPlayer.PlayerGui:FindFirstChild("Shop")
    if shopGui then
        local buyButton = shopGui:FindFirstChild("BuyKnife")
        if buyButton then buyButton:FireClick() end
    end
end

local function FindRemoteEvents()
    for _, obj in pairs(ReplicatedStorage:GetChildren()) do
        if obj:IsA("RemoteEvent") then
            local name = obj.Name:lower()
            if name:find("kill") or name:find("murder") then KillAllRemote = obj
            elseif name:find("win") or name:find("victory") then InstantWinRemote = obj
            elseif name:find("attack") or name:find("stab") then AttackRemote = obj end
        end
    end
    if not KillAllRemote then KillAllRemote = ReplicatedStorage:FindFirstChild("KillEvent") or ReplicatedStorage:FindFirstChild("MurdererKill") end
    if not InstantWinRemote then InstantWinRemote = ReplicatedStorage:FindFirstChild("WinEvent") or ReplicatedStorage:FindFirstChild("Victory") end
    if not AttackRemote then AttackRemote = ReplicatedStorage:FindFirstChild("AttackEvent") or ReplicatedStorage:FindFirstChild("Stab") end
end

local function SetupSilentAim()
    if not Settings.Aimbot.Silent or not AttackRemote then return end
    if not originalFire then originalFire = AttackRemote.FireServer end
    AttackRemote.FireServer = function(self, ...)
        local args = {...}
        local target = nil
        if Settings.Aimbot.Target == "Murderer" then
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player:GetAttribute("Role") == "Murderer" then target = player; break end
            end
        elseif Settings.Aimbot.Target == "Sheriff" then
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player:GetAttribute("Role") == "Sheriff" then target = player; break end
            end
        elseif Settings.Aimbot.Target == "All" then
            local nearest, nearestDist = nil, math.huge
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    local dist = (LocalPlayer.Character.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).magnitude
                    if dist < nearestDist then nearestDist = dist; nearest = player end
                end
            end
            target = nearest
        end
        if target then args[1] = target end
        return originalFire(self, unpack(args))
    end
end

local function DisableSilentAim()
    if AttackRemote and originalFire then
        AttackRemote.FireServer = originalFire
        originalFire = nil
    end
end

-- ==================== CRIAÇÃO DA GUI (CORRIGIDA) ====================
local function CreateFloatingButton()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "NexusOmega"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    local button = Instance.new("ImageButton")
    button.Size = UDim2.new(0, 50, 0, 50)
    button.Position = UDim2.new(0, 10, 0, 100)
    button.BackgroundColor3 = PrimaryColor
    button.BackgroundTransparency = 0.3
    button.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
    button.ImageColor3 = PrimaryColor
    button.ImageTransparency = 0.5
    button.Parent = screenGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1,0)
    corner.Parent = button
    -- Carregar posição
    if isfile("NexusButtonPos.txt") then
        local pos = readfile("NexusButtonPos.txt")
        local x, y = pos:match("(%d+),(%d+)")
        if x and y then button.Position = UDim2.new(0, tonumber(x), 0, tonumber(y)) end
    end
    local dragging = false
    local dragStart, startPos
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = button.Position
        end
    end)
    button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
            if canWrite then writefile("NexusButtonPos.txt", tostring(button.Position.X.Offset) .. "," .. tostring(button.Position.Y.Offset)) end
        end
    end)
    button.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - dragStart
            button.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    button.MouseButton1Click:Connect(function()
        MenuOpen = not MenuOpen
        if MenuOpen then
            MainMenu.Visible = true
            TweenService:Create(MainMenu, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { BackgroundTransparency = 0.1 }):Play()
        else
            TweenService:Create(MainMenu, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
            wait(0.2)
            MainMenu.Visible = false
        end
    end)
    return screenGui, button
end

-- Funções de UI (Toggle, Slider, etc.) – permanecem iguais
local function CreateToggle(parent, text, defaultValue, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 40)
    frame.BackgroundTransparency = 1
    frame.Parent = parent
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 1, 0)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.Text = text
    label.TextColor3 = Color3.fromRGB(255,255,255)
    label.BackgroundTransparency = 1
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    local toggleBg = Instance.new("Frame")
    toggleBg.Size = UDim2.new(0, 50, 0, 24)
    toggleBg.Position = UDim2.new(1, -60, 0.5, -12)
    toggleBg.BackgroundColor3 = defaultValue and Color3.fromRGB(0,200,0) or Color3.fromRGB(80,80,100)
    toggleBg.BorderSizePixel = 0
    toggleBg.Parent = frame
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(1,0)
    toggleCorner.Parent = toggleBg
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 20, 0, 20)
    knob.Position = defaultValue and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    knob.BorderSizePixel = 0
    knob.Parent = toggleBg
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1,0)
    knobCorner.Parent = knob
    local active = defaultValue
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,1,0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = frame
    btn.MouseButton1Click:Connect(function()
        active = not active
        toggleBg.BackgroundColor3 = active and Color3.fromRGB(0,200,0) or Color3.fromRGB(80,80,100)
        knob.Position = active and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
        callback(active)
    end)
    return frame
end

local function CreateSlider(parent, text, min, max, defaultValue, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 50)
    frame.BackgroundTransparency = 1
    frame.Parent = parent
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 20)
    label.Text = text .. ": " .. tostring(defaultValue)
    label.TextColor3 = Color3.fromRGB(255,255,255)
    label.BackgroundTransparency = 1
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(1, 0, 0, 4)
    sliderBg.Position = UDim2.new(0, 0, 0, 30)
    sliderBg.BackgroundColor3 = Color3.fromRGB(80,80,100)
    sliderBg.BorderSizePixel = 0
    sliderBg.Parent = frame
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((defaultValue - min)/(max - min), 0, 1, 0)
    fill.BackgroundColor3 = PrimaryColor
    fill.BorderSizePixel = 0
    fill.Parent = sliderBg
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 12, 0, 12)
    knob.Position = UDim2.new((defaultValue - min)/(max - min), -6, 0.5, -6)
    knob.BackgroundColor3 = PrimaryColor
    knob.BorderSizePixel = 0
    knob.Parent = sliderBg
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1,0)
    knobCorner.Parent = knob
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0, 40, 0, 20)
    valueLabel.Position = UDim2.new(1, -50, 0, 30)
    valueLabel.Text = tostring(defaultValue)
    valueLabel.TextColor3 = Color3.fromRGB(255,255,255)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Parent = frame
    local dragging = false
    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
        end
    end)
    knob.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    knob.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local pos = input.Position.X - sliderBg.AbsolutePosition.X
            local percent = math.clamp(pos / sliderBg.AbsoluteSize.X, 0, 1)
            local value = min + percent * (max - min)
            fill.Size = UDim2.new(percent, 0, 1, 0)
            knob.Position = UDim2.new(percent, -6, 0.5, -6)
            valueLabel.Text = string.format("%.0f", value)
            callback(value)
        end
    end)
    return frame
end

local function CreateButton(parent, text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 40)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.BackgroundColor3 = Color3.fromRGB(30,30,40)
    btn.BorderSizePixel = 0
    btn.Parent = parent
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0,8)
    btnCorner.Parent = btn
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local function CreateDropdown(parent, text, options, defaultValue, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 50)
    frame.BackgroundTransparency = 1
    frame.Parent = parent
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 20)
    label.Text = text
    label.TextColor3 = Color3.fromRGB(255,255,255)
    label.BackgroundTransparency = 1
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    local dropdownBtn = Instance.new("TextButton")
    dropdownBtn.Size = UDim2.new(1, 0, 0, 30)
    dropdownBtn.Position = UDim2.new(0, 0, 0, 25)
    dropdownBtn.Text = defaultValue
    dropdownBtn.TextColor3 = Color3.fromRGB(255,255,255)
    dropdownBtn.BackgroundColor3 = Color3.fromRGB(30,30,40)
    dropdownBtn.BorderSizePixel = 0
    dropdownBtn.Parent = frame
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0,8)
    btnCorner.Parent = dropdownBtn
    local dropdownList = Instance.new("Frame")
    dropdownList.Size = UDim2.new(1, 0, 0, 0)
    dropdownList.Position = UDim2.new(0, 0, 0, 55)
    dropdownList.BackgroundColor3 = Color3.fromRGB(30,30,40)
    dropdownList.ClipsDescendants = true
    dropdownList.Visible = false
    dropdownList.Parent = frame
    local listCorner = Instance.new("UICorner")
    listCorner.CornerRadius = UDim.new(0,8)
    listCorner.Parent = dropdownList
    for i, opt in ipairs(options) do
        local optBtn = Instance.new("TextButton")
        optBtn.Size = UDim2.new(1, 0, 0, 30)
        optBtn.Position = UDim2.new(0, 0, 0, (i-1)*30)
        optBtn.Text = opt
        optBtn.TextColor3 = Color3.fromRGB(255,255,255)
        optBtn.BackgroundColor3 = Color3.fromRGB(40,40,50)
        optBtn.BorderSizePixel = 0
        optBtn.Parent = dropdownList
        local optCorner = Instance.new("UICorner")
        optCorner.CornerRadius = UDim.new(0,6)
        optCorner.Parent = optBtn
        optBtn.MouseButton1Click:Connect(function()
            dropdownBtn.Text = opt
            dropdownList.Visible = false
            dropdownList.Size = UDim2.new(1, 0, 0, 0)
            callback(opt)
        end)
    end
    dropdownBtn.MouseButton1Click:Connect(function()
        dropdownList.Visible = not dropdownList.Visible
        if dropdownList.Visible then
            dropdownList.Size = UDim2.new(1, 0, 0, #options * 30)
        else
            dropdownList.Size = UDim2.new(1, 0, 0, 0)
        end
    end)
    return frame
end

-- ==================== CRIAÇÃO DO MENU PRINCIPAL (CORRIGIDO) ====================
local function CreateMainMenu()
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 400, 0, 500)
    mainFrame.Position = UDim2.new(0.5, -200, 0.5, -250)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20,20,30)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.Visible = false
    mainFrame.Parent = Gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 20)
    corner.Parent = mainFrame
    local shadow = Instance.new("UIShadow")
    shadow.Parent = mainFrame
    -- Categorias laterais
    local categoriesFrame = Instance.new("Frame")
    categoriesFrame.Size = UDim2.new(0, 100, 1, 0)
    categoriesFrame.BackgroundColor3 = Color3.fromRGB(0,0,0)
    categoriesFrame.BackgroundTransparency = 0.5
    categoriesFrame.Parent = mainFrame
    local categories = {"Aimbot","ESP","Auto Farm","Movimentação","Combate","Proteção","Misc","Configurações"}
    local categoryButtons = {}
    for i, cat in ipairs(categories) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 45)
        btn.Position = UDim2.new(0, 0, 0, (i-1)*50)
        btn.Text = cat
        btn.TextColor3 = Color3.fromRGB(255,255,255)
        btn.BackgroundColor3 = Color3.fromRGB(30,30,40)
        btn.BackgroundTransparency = 0.5
        btn.Parent = categoriesFrame
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 12)
        btnCorner.Parent = btn
        btn.MouseButton1Click:Connect(function()
            CurrentCategory = cat
            UpdateContentFrame()
        end)
        categoryButtons[cat] = btn
    end
    -- Área de conteúdo
    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, -110, 1, -20)
    contentFrame.Position = UDim2.new(0, 105, 0, 10)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = mainFrame
    -- Imagem de perfil
    local profileImage = Instance.new("ImageLabel")
    profileImage.Size = UDim2.new(0, 40, 0, 40)
    profileImage.Position = UDim2.new(1, -50, 0, 10)
    profileImage.Image = "https://play-lh.googleusercontent.com/5jcAEbmAQ-4XAYIlHGl_ZW9X9GJlTImrA4EBYBztutHPou2W3DB-w2FR7oOOE22_FPSv=w240-h480-rw"
    profileImage.BackgroundTransparency = 1
    profileImage.Parent = mainFrame
    local profileCorner = Instance.new("UICorner")
    profileCorner.CornerRadius = UDim.new(1,0)
    profileCorner.Parent = profileImage
    -- ScrollView
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, 0, 1, 0)
    scroll.BackgroundTransparency = 1
    scroll.CanvasSize = UDim2.new(0,0,0,0)
    scroll.ScrollBarThickness = 4
    scroll.Parent = contentFrame
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scroll
    local function updateCanvas()
        local total = 0
        for _, child in pairs(scroll:GetChildren()) do
            if child:IsA("Frame") or child:IsA("TextButton") then
                total = total + child.Size.Y.Offset + layout.Padding.Offset
            end
        end
        scroll.CanvasSize = UDim2.new(0,0,0,total+10)
    end
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)

    local function UpdateContentFrame()
        for _, child in pairs(scroll:GetChildren()) do
            if child:IsA("Frame") or child:IsA("TextButton") then
                child:Destroy()
            end
        end
        if CurrentCategory == "Aimbot" then
            CreateToggle(scroll, "Ativar Aimbot", Settings.Aimbot.Enabled, function(v)
                Settings.Aimbot.Enabled = v
                SaveSettings()
                Notify("Aimbot " .. (v and "ativado" or "desativado"))
            end)
            CreateToggle(scroll, "Silent Aim", Settings.Aimbot.Silent, function(v)
                Settings.Aimbot.Silent = v
                if v then SetupSilentAim() else DisableSilentAim() end
                SaveSettings()
            end)
            CreateSlider(scroll, "Campo de mira", 50, 300, Settings.Aimbot.FOV, function(v)
                Settings.Aimbot.FOV = v
                SaveSettings()
            end)
            CreateDropdown(scroll, "Alvo preferencial", {"Murderer","Sheriff","Innocent","All"}, Settings.Aimbot.Target, function(v)
                Settings.Aimbot.Target = v
                SaveSettings()
            end)
            CreateSlider(scroll, "Smoothness", 0, 100, Settings.Aimbot.Smoothness, function(v)
                Settings.Aimbot.Smoothness = v
                SaveSettings()
            end)
        elseif CurrentCategory == "ESP" then
            CreateToggle(scroll, "Ativar ESP", Settings.ESP.Enabled, function(v)
                Settings.ESP.Enabled = v
                if v then CreateESP() else ClearESP() end
                SaveSettings()
            end)
            CreateToggle(scroll, "ESP Jogadores", Settings.ESP.Players, function(v)
                Settings.ESP.Players = v
                SaveSettings()
            end)
            CreateToggle(scroll, "Mostrar Nomes", Settings.ESP.ShowNames, function(v)
                Settings.ESP.ShowNames = v
                SaveSettings()
            end)
            CreateToggle(scroll, "Traçadores (Tracers)", Settings.ESP.Tracers, function(v)
                Settings.ESP.Tracers = v
                SaveSettings()
            end)
            CreateToggle(scroll, "Aura (Glow)", Settings.ESP.Aura, function(v)
                Settings.ESP.Aura = v
                SaveSettings()
            end)
            CreateToggle(scroll, "Radar 2D", Settings.ESP.Radar, function(v)
                Settings.ESP.Radar = v
                if v then CreateRadar() else if RadarFrame then RadarFrame:Destroy() end end
                SaveSettings()
            end)
        elseif CurrentCategory == "Auto Farm" then
            CreateToggle(scroll, "Auto Collect", Settings.AutoFarm.Collect, function(v)
                Settings.AutoFarm.Collect = v
                SaveSettings()
            end)
            CreateToggle(scroll, "Auto Reset", Settings.AutoFarm.Reset, function(v)
                Settings.AutoFarm.Reset = v
                SaveSettings()
            end)
            CreateToggle(scroll, "Auto Play", Settings.AutoFarm.AutoPlay, function(v)
                Settings.AutoFarm.AutoPlay = v
                SaveSettings()
            end)
        elseif CurrentCategory == "Movimentação" then
            CreateToggle(scroll, "Fly / NoClip", Settings.Movement.Fly, function(v)
                Settings.Movement.Fly = v
                if v then EnableFly() else DisableFly() end
                SaveSettings()
            end)
            CreateSlider(scroll, "Speed Hack", 16, 100, Settings.Movement.Speed, function(v)
                Settings.Movement.Speed = v
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                    LocalPlayer.Character.Humanoid.WalkSpeed = v
                end
                SaveSettings()
            end)
            CreateToggle(scroll, "Anti-AFK", Settings.Movement.AntiAFK, function(v)
                Settings.Movement.AntiAFK = v
                SaveSettings()
            end)
        elseif CurrentCategory == "Combate" then
            CreateButton(scroll, "Kill All", function()
                KillAll()
            end)
            CreateButton(scroll, "Instant Win", function()
                InstantWin()
            end)
            CreateToggle(scroll, "Auto Parry", Settings.Combat.AutoParry, function(v)
                Settings.Combat.AutoParry = v
                SaveSettings()
            end)
        elseif CurrentCategory == "Proteção" then
            CreateToggle(scroll, "Anti-Ban", Settings.Protection.AntiBan, function(v)
                Settings.Protection.AntiBan = v
                SaveSettings()
            end)
            local webhookFrame = Instance.new("Frame")
            webhookFrame.Size = UDim2.new(1, -20, 0, 80)
            webhookFrame.BackgroundTransparency = 1
            webhookFrame.Parent = scroll
            local webhookLabel = Instance.new("TextLabel")
            webhookLabel.Size = UDim2.new(1, 0, 0, 20)
            webhookLabel.Text = "Webhook URL:"
            webhookLabel.TextColor3 = Color3.fromRGB(255,255,255)
            webhookLabel.BackgroundTransparency = 1
            webhookLabel.TextXAlignment = Enum.TextXAlignment.Left
            webhookLabel.Parent = webhookFrame
            local webhookInput = Instance.new("TextBox")
            webhookInput.Size = UDim2.new(1, 0, 0, 30)
            webhookInput.Position = UDim2.new(0, 0, 0, 25)
            webhookInput.PlaceholderText = "https://discord.com/api/webhooks/..."
            webhookInput.Text = Settings.Protection.Webhook or ""
            webhookInput.TextColor3 = Color3.fromRGB(255,255,255)
            webhookInput.BackgroundColor3 = Color3.fromRGB(30,30,40)
            webhookInput.BorderSizePixel = 0
            webhookInput.Parent = webhookFrame
            local webhookCorner = Instance.new("UICorner")
            webhookCorner.CornerRadius = UDim.new(0,8)
            webhookCorner.Parent = webhookInput
            webhookInput:GetPropertyChangedSignal("Text"):Connect(function()
                Settings.Protection.Webhook = webhookInput.Text
                SaveSettings()
            end)
            CreateButton(scroll, "Testar Webhook", function()
                if Settings.Protection.Webhook and Settings.Protection.Webhook ~= "" then
                    local success, err = pcall(function()
                        HttpService:PostAsync(Settings.Protection.Webhook, HttpService:JSONEncode({content = "NEXUS Omega: Teste de notificação!"}))
                    end)
                    if success then Notify("Webhook enviado") else Notify("Erro: " .. tostring(err)) end
                else
                    Notify("Insira uma URL válida")
                end
            end)
        elseif CurrentCategory == "Misc" then
            CreateToggle(scroll, "Auto Buy", Settings.Misc.AutoBuy, function(v)
                Settings.Misc.AutoBuy = v
                SaveSettings()
            end)
            CreateButton(scroll, "Recolher Todas Moedas", function()
                for _, obj in pairs(Workspace:GetDescendants()) do
                    if obj:IsA("BasePart") and obj.Name:find("Coin") then
                        local click = obj:FindFirstChildOfClass("ClickDetector")
                        if click then click:FireClick() end
                    end
                end
                Notify("Moedas recolhidas")
            end)
            CreateToggle(scroll, "Modo Stealth", Settings.Misc.Stealth, function(v)
                Settings.Misc.Stealth = v
                SaveSettings()
            end)
        elseif CurrentCategory == "Configurações" then
            CreateButton(scroll, "Salvar Configurações", function()
                SaveSettings()
                Notify("Configurações salvas")
            end)
            CreateButton(scroll, "Carregar Configurações", function()
                LoadSettings()
                Notify("Configurações carregadas")
                UpdateContentFrame()
            end)
            CreateSlider(scroll, "Opacidade do Menu", 0.5, 1, Settings.UI.Opacity, function(v)
                Settings.UI.Opacity = v
                mainFrame.BackgroundTransparency = 1 - v
                SaveSettings()
            end)
            CreateDropdown(scroll, "Cor Primária", {"Purple","Blue","Red"}, Settings.UI.PrimaryColor, function(v)
                Settings.UI.PrimaryColor = v
                PrimaryColor = ColorSchemes[v]
                SaveSettings()
                UpdateContentFrame()
            end)
            CreateToggle(scroll, "Sons de Ativação", Settings.UI.Sounds, function(v)
                Settings.UI.Sounds = v
                SaveSettings()
            end)
        end
        updateCanvas()
    end
    UpdateContentFrame()
    return mainFrame
end

-- ==================== INICIALIZAÇÃO ====================
LoadSettings()
Gui, FloatingButton = CreateFloatingButton()
MainMenu = CreateMainMenu()
FindRemoteEvents()
if Settings.Aimbot.Silent then SetupSilentAim() end

if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
    LocalPlayer.Character.Humanoid.WalkSpeed = Settings.Movement.Speed
end

-- Loop de atualização (otimizado)
RunService.RenderStepped:Connect(function()
    if Settings.ESP.Enabled and Settings.ESP.Players then
        if not ESPObjects[next(ESPObjects)] then CreateESP() end
        UpdateESP()
    elseif not Settings.ESP.Enabled then
        ClearESP()
    end
    if Settings.ESP.Radar and not RadarFrame then
        CreateRadar()
    elseif not Settings.ESP.Radar and RadarFrame then
        RadarFrame:Destroy()
        RadarFrame = nil
    end
    if Settings.AutoFarm.Collect then AutoCollect() end
    if Settings.AutoFarm.Reset then AutoReset() end
    if Settings.AutoFarm.AutoPlay then AutoPlay() end
    if Settings.Movement.AntiAFK then AntiAFK() end
    if Settings.Movement.Fly and not Flying then
        EnableFly()
    elseif not Settings.Movement.Fly and Flying then
        DisableFly()
    end
    if Settings.Misc.AutoBuy then AutoBuy() end
    if Settings.Misc.Stealth then
        if FloatingButton then FloatingButton.Visible = false end
        if MainMenu then MainMenu.Visible = false end
        ClearESP()
        if RadarFrame then RadarFrame.Visible = false end
    else
        if FloatingButton then FloatingButton.Visible = true end
        if RadarFrame then RadarFrame.Visible = true end
    end
    if Settings.Combat.KillAll then
        KillAll()
        Settings.Combat.KillAll = false
    end
    if Settings.Combat.InstantWin then
        InstantWin()
        Settings.Combat.InstantWin = false
    end
end)

Notify("NEXUS Omega carregado!")
print("NEXUS Omega ativado. Toque na bolinha para abrir o menu.")
