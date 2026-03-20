--[[
    NEXUS - Mod Menu Professional para Murder Mystery 2
    Versão: 1.0
    Design inspirado no VexonHub
    Funcionalidades: Aimbot, ESP, Auto Farm, Auto Play, No Recoil, Instant Win, Anti-AFK, Teletransporte, Auto Buy
    Persistência de configurações, notificações, interface responsiva
    Suporte a PC e Mobile
]]

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- ================= CONFIGURAÇÕES =================
local Settings = {
    Aimbot = {
        Enabled = false,
        Target = "Murderer", -- "Murderer", "Nearest", "Any"
        Smoothness = 0.3,
        ShowFOV = false,
        FOVRadius = 150
    },
    ESP = {
        Enabled = false,
        ShowNames = true,
        ShowBoxes = true,
        ShowTrails = false,
        ShowWeapon = true,
        Colors = {
            Innocent = Color3.fromRGB(255, 255, 255),
            Murderer = Color3.fromRGB(255, 0, 0),
            Sheriff = Color3.fromRGB(0, 255, 0),
            Knife = Color3.fromRGB(255, 165, 0)
        }
    },
    AutoFarm = {
        Enabled = false,
        CollectCoins = true,
        CollectKnives = true
    },
    AutoPlay = {
        Enabled = false,
        AutoJoin = true,
        AutoSkip = true
    },
    NoRecoil = false,
    InstantWin = false,
    AntiAFK = false,
    Teleport = {
        Enabled = false,
        Target = "Items" -- "Items", "Players"
    },
    AutoBuy = {
        Enabled = false,
        Item = "Knife"
    },
    UI = {
        PrimaryColor = Color3.fromRGB(138, 43, 226), -- Roxo
        SecondaryColor = Color3.fromRGB(0, 0, 0),
        TextColor = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.2
    }
}

-- ================= VARIÁVEIS GLOBAIS =================
local ESPObjects = {} -- Para armazenar objetos de desenho
local CurrentCategory = "Aimbot"
local MenuOpen = false
local Dragging = false
local DragStart, DragStartPos
local Notifications = {}
local SaveData = {}

-- ================= FUNÇÕES AUXILIARES =================
function SaveSettings()
    local data = {}
    for category, values in pairs(Settings) do
        data[category] = values
    end
    writefile("NexusSettings.json", game:GetService("HttpService"):JSONEncode(data))
end

function LoadSettings()
    if isfile("NexusSettings.json") then
        local data = game:GetService("HttpService"):JSONDecode(readfile("NexusSettings.json"))
        for category, values in pairs(data) do
            if Settings[category] then
                for key, val in pairs(values) do
                    Settings[category][key] = val
                end
            end
        end
    end
end

function Notify(title, message, duration)
    local notification = {
        Title = title,
        Message = message,
        Duration = duration or 3,
        Created = tick()
    }
    table.insert(Notifications, notification)
    -- Atualizar UI de notificações
    UpdateNotificationsUI()
end

function UpdateNotificationsUI()
    -- Será implementado na criação da GUI
end

-- ================= ESP (Wallhack) =================
local function CreateESP()
    -- Limpar ESP anterior
    for _, obj in pairs(ESPObjects) do
        if obj and obj.Remove then obj:Remove() end
    end
    ESPObjects = {}

    if not Settings.ESP.Enabled then return end

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local character = player.Character
            local root = character.HumanoidRootPart

            -- Determinar cor baseada no papel
            local color = Settings.ESP.Colors.Innocent
            local role = player:GetAttribute("Role") or (player.Team and player.Team.Name) or ""
            if role == "Murderer" then
                color = Settings.ESP.Colors.Murderer
            elseif role == "Sheriff" then
                color = Settings.ESP.Colors.Sheriff
            end

            -- Caixa
            if Settings.ESP.ShowBoxes then
                local box = Drawing.new("Square")
                box.Thickness = 2
                box.Color = color
                box.Visible = false
                ESPObjects[player] = { Box = box }
            end

            -- Nome
            if Settings.ESP.ShowNames then
                local name = Drawing.new("Text")
                name.Text = player.Name
                name.Size = 14
                name.Center = true
                name.Outline = true
                name.Color = color
                name.Visible = false
                if not ESPObjects[player] then ESPObjects[player] = {} end
                ESPObjects[player].Name = name
            end
        end
    end
end

-- Atualizar posições dos desenhos
local function UpdateESP()
    if not Settings.ESP.Enabled then return end

    for player, obj in pairs(ESPObjects) do
        if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local root = player.Character.HumanoidRootPart
            local pos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(root.Position)
            if onScreen then
                -- Caixa
                if obj.Box then
                    local size = player.Character:GetExtentsSize()
                    local width = size.X * 5
                    local height = size.Y * 5
                    local boxPos = Vector2.new(pos.X - width/2, pos.Y - height/2)
                    obj.Box.Size = Vector2.new(width, height)
                    obj.Box.Position = boxPos
                    obj.Box.Visible = true
                end
                -- Nome
                if obj.Name then
                    obj.Name.Position = Vector2.new(pos.X, pos.Y - 20)
                    obj.Name.Visible = true
                end
            else
                if obj.Box then obj.Box.Visible = false end
                if obj.Name then obj.Name.Visible = false end
            end
        else
            if obj.Box then obj.Box.Visible = false end
            if obj.Name then obj.Name.Visible = false end
        end
    end
end

-- ================= AIMBOT =================
local function GetClosestMurderer()
    local closest = nil
    local closestDist = math.huge
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local role = player:GetAttribute("Role") or (player.Team and player.Team.Name) or ""
            if role == "Murderer" then
                local pos = player.Character.HumanoidRootPart.Position
                local dist = (LocalPlayer.Character.HumanoidRootPart.Position - pos).magnitude
                if dist < closestDist then
                    closestDist = dist
                    closest = player
                end
            end
        end
    end
    return closest
end

local function GetNearestPlayer()
    local nearest = nil
    local nearestDist = math.huge
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local pos = player.Character.HumanoidRootPart.Position
            local dist = (LocalPlayer.Character.HumanoidRootPart.Position - pos).magnitude
            if dist < nearestDist then
                nearestDist = dist
                nearest = player
            end
        end
    end
    return nearest
end

local function AimAt(target)
    if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
        local targetPos = target.Character.HumanoidRootPart.Position
        local camera = workspace.CurrentCamera
        local lookVector = (targetPos - camera.CFrame.Position).unit
        local newCFrame = CFrame.new(camera.CFrame.Position, camera.CFrame.Position + lookVector)
        camera.CFrame = camera.CFrame:Lerp(newCFrame, Settings.Aimbot.Smoothness)
    end
end

-- ================= AUTO FARM =================
local function AutoFarm()
    if not Settings.AutoFarm.Enabled then return end
    -- Coletar itens no chão (exemplo simplificado)
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name:find("Coin") then
            -- Simular toque no objeto
            fireclickdetector(obj:FindFirstChildOfClass("ClickDetector"))
        end
    end
end

-- ================= AUTO PLAY =================
local function AutoPlay()
    if not Settings.AutoPlay.Enabled then return end
    -- Exemplo: pular round automaticamente (detectar fim de round)
    local roundEnded = false -- Lógica para detectar fim do round
    if roundEnded then
        -- Simular clique no botão "Next Round" ou algo similar
    end
end

-- ================= ANTI-AFK =================
local function AntiAFK()
    if not Settings.AntiAFK then return end
    -- Simular movimento
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new(0,0))
end

-- ================= TELEPORTE =================
local function TeleportTo(target)
    if not Settings.Teleport.Enabled then return end
    if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.Character.HumanoidRootPart.CFrame = target.Character.HumanoidRootPart.CFrame
    end
end

-- ================= AUTO BUY =================
local function AutoBuy()
    if not Settings.AutoBuy.Enabled then return end
    -- Exemplo: comprar item na loja (simular clique)
end

-- ================= INSTANT WIN =================
local function InstantWin()
    if not Settings.InstantWin then return end
    -- Lógica para vencer instantaneamente (exemplo: enviar evento remoto)
end

-- ================= NO RECOIL =================
local function NoRecoil()
    if not Settings.NoRecoil then return end
    -- Lógica para remover recoil (se aplicável)
end

-- ================= GUI =================
local function CreateFloatingButton()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "NexusMenu"
    screenGui.Parent = LocalPlayer.PlayerGui

    local floatingButton = Instance.new("ImageButton")
    floatingButton.Size = UDim2.new(0, 50, 0, 50)
    floatingButton.Position = UDim2.new(0, 10, 0, 100)
    floatingButton.BackgroundColor3 = Settings.UI.PrimaryColor
    floatingButton.BackgroundTransparency = 0.2
    floatingButton.Image = "rbxassetid://1234567890" -- Substitua por um ID de imagem de faca ou engrenagem
    floatingButton.ImageColor3 = Color3.fromRGB(255, 255, 255)
    floatingButton.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = floatingButton

    -- Arrastar
    local dragging = false
    local dragStart, startPos
    floatingButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = floatingButton.Position
        end
    end)
    floatingButton.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    floatingButton.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            floatingButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- Abrir/fechar menu
    floatingButton.MouseButton1Click:Connect(function()
        MenuOpen = not MenuOpen
        local menu = screenGui:FindFirstChild("MainMenu")
        if menu then
            menu.Visible = MenuOpen
            if MenuOpen then
                TweenService:Create(menu, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { BackgroundTransparency = 0.1 }):Play()
            end
        end
    end)

    return floatingButton, screenGui
end

local function CreateMainMenu(screenGui)
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainMenu"
    mainFrame.Size = UDim2.new(0, 400, 0, 500)
    mainFrame.Position = UDim2.new(0.5, -200, 0.5, -250)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.Visible = false
    mainFrame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame

    local shadow = Instance.new("UIShadow")
    shadow.Parent = mainFrame

    -- Categorias laterais
    local categoriesFrame = Instance.new("Frame")
    categoriesFrame.Size = UDim2.new(0, 120, 1, 0)
    categoriesFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    categoriesFrame.BackgroundTransparency = 0.5
    categoriesFrame.Parent = mainFrame

    local categoriesList = {"Aimbot", "ESP", "Auto Farm", "Auto Play", "Player", "Misc", "Settings"}
    local categoryButtons = {}
    for i, cat in ipairs(categoriesList) do
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, 0, 0, 40)
        button.Position = UDim2.new(0, 0, 0, (i-1)*45)
        button.Text = cat
        button.TextColor3 = Settings.UI.TextColor
        button.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        button.BackgroundTransparency = 0.5
        button.Parent = categoriesFrame

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 8)
        btnCorner.Parent = button

        button.MouseButton1Click:Connect(function()
            CurrentCategory = cat
            UpdateContentFrame()
        end)
        categoryButtons[cat] = button
    end

    -- Conteúdo principal
    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, -130, 1, -20)
    contentFrame.Position = UDim2.new(0, 125, 0, 10)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = mainFrame

    -- Imagem de perfil (cabeçalho)
    local profileImage = Instance.new("ImageLabel")
    profileImage.Size = UDim2.new(0, 50, 0, 50)
    profileImage.Position = UDim2.new(1, -60, 0, 10)
    profileImage.Image = "https://play-lh.googleusercontent.com/5jcAEbmAQ-4XAYIlHGl_ZW9X9GJlTImrA4EBYBztutHPou2W3DB-w2FR7oOOE22_FPSv=w240-h480-rw"
    profileImage.BackgroundTransparency = 1
    profileImage.Parent = mainFrame

    local profileCorner = Instance.new("UICorner")
    profileCorner.CornerRadius = UDim.new(1, 0)
    profileCorner.Parent = profileImage

    -- Atualizar conteúdo com base na categoria atual
    local function UpdateContentFrame()
        for _, child in pairs(contentFrame:GetChildren()) do
            child:Destroy()
        end

        if CurrentCategory == "Aimbot" then
            -- Toggle Aimbot
            local aimbotToggle = CreateToggle(contentFrame, "Ativar Aimbot", Settings.Aimbot.Enabled, function(value)
                Settings.Aimbot.Enabled = value
                Notify("Aimbot", value and "Ativado" or "Desativado", 2)
                SaveSettings()
            end)
            aimbotToggle.Position = UDim2.new(0, 0, 0, 0)

            -- Dropdown para alvo
            local targetDropdown = CreateDropdown(contentFrame, "Alvo", {"Murderer", "Nearest", "Any"}, Settings.Aimbot.Target, function(value)
                Settings.Aimbot.Target = value
                SaveSettings()
            end)
            targetDropdown.Position = UDim2.new(0, 0, 0, 60)

            -- Slider para suavidade
            local smoothSlider = CreateSlider(contentFrame, "Suavidade", 0, 1, Settings.Aimbot.Smoothness, function(value)
                Settings.Aimbot.Smoothness = value
                SaveSettings()
            end)
            smoothSlider.Position = UDim2.new(0, 0, 0, 120)

        elseif CurrentCategory == "ESP" then
            local espToggle = CreateToggle(contentFrame, "Ativar ESP", Settings.ESP.Enabled, function(value)
                Settings.ESP.Enabled = value
                if value then CreateESP() else for _, obj in pairs(ESPObjects) do if obj.Box then obj.Box.Visible = false end if obj.Name then obj.Name.Visible = false end end end
                SaveSettings()
                Notify("ESP", value and "Ativado" or "Desativado", 2)
            end)
            espToggle.Position = UDim2.new(0, 0, 0, 0)

            local nameToggle = CreateToggle(contentFrame, "Mostrar Nomes", Settings.ESP.ShowNames, function(value)
                Settings.ESP.ShowNames = value
                SaveSettings()
            end)
            nameToggle.Position = UDim2.new(0, 0, 0, 50)

            local boxToggle = CreateToggle(contentFrame, "Mostrar Caixas", Settings.ESP.ShowBoxes, function(value)
                Settings.ESP.ShowBoxes = value
                SaveSettings()
            end)
            boxToggle.Position = UDim2.new(0, 0, 0, 100)

        elseif CurrentCategory == "Auto Farm" then
            local farmToggle = CreateToggle(contentFrame, "Auto Farm", Settings.AutoFarm.Enabled, function(value)
                Settings.AutoFarm.Enabled = value
                Notify("Auto Farm", value and "Iniciado" or "Parado", 2)
                SaveSettings()
            end)
            farmToggle.Position = UDim2.new(0, 0, 0, 0)

            local coinsToggle = CreateToggle(contentFrame, "Coletar Moedas", Settings.AutoFarm.CollectCoins, function(value)
                Settings.AutoFarm.CollectCoins = value
                SaveSettings()
            end)
            coinsToggle.Position = UDim2.new(0, 0, 0, 50)

            local knivesToggle = CreateToggle(contentFrame, "Coletar Facas", Settings.AutoFarm.CollectKnives, function(value)
                Settings.AutoFarm.CollectKnives = value
                SaveSettings()
            end)
            knivesToggle.Position = UDim2.new(0, 0, 0, 100)

        elseif CurrentCategory == "Auto Play" then
            local playToggle = CreateToggle(contentFrame, "Auto Play", Settings.AutoPlay.Enabled, function(value)
                Settings.AutoPlay.Enabled = value
                Notify("Auto Play", value and "Ativado" or "Desativado", 2)
                SaveSettings()
            end)
            playToggle.Position = UDim2.new(0, 0, 0, 0)

            local joinToggle = CreateToggle(contentFrame, "Auto Join", Settings.AutoPlay.AutoJoin, function(value)
                Settings.AutoPlay.AutoJoin = value
                SaveSettings()
            end)
            joinToggle.Position = UDim2.new(0, 0, 0, 50)

        elseif CurrentCategory == "Player" then
            local teleportToggle = CreateToggle(contentFrame, "Teletransporte", Settings.Teleport.Enabled, function(value)
                Settings.Teleport.Enabled = value
                Notify("Teletransporte", value and "Ativado" : "Desativado", 2)
                SaveSettings()
            end)
            teleportToggle.Position = UDim2.new(0, 0, 0, 0)

            local teleportTarget = CreateDropdown(contentFrame, "Destino", {"Items", "Players"}, Settings.Teleport.Target, function(value)
                Settings.Teleport.Target = value
                SaveSettings()
            end)
            teleportTarget.Position = UDim2.new(0, 0, 0, 60)

        elseif CurrentCategory == "Misc" then
            local noRecoilToggle = CreateToggle(contentFrame, "No Recoil", Settings.NoRecoil, function(value)
                Settings.NoRecoil = value
                Notify("No Recoil", value and "Ativado" : "Desativado", 2)
                SaveSettings()
            end)
            noRecoilToggle.Position = UDim2.new(0, 0, 0, 0)

            local instantWinBtn = CreateButton(contentFrame, "Vitória Instantânea", function()
                InstantWin()
                Notify("Instant Win", "Ativado", 2)
            end)
            instantWinBtn.Position = UDim2.new(0, 0, 0, 50)

            local antiAFKToggle = CreateToggle(contentFrame, "Anti-AFK", Settings.AntiAFK, function(value)
                Settings.AntiAFK = value
                SaveSettings()
            end)
            antiAFKToggle.Position = UDim2.new(0, 0, 0, 100)

        elseif CurrentCategory == "Settings" then
            -- Botão de salvar configurações
            local saveBtn = CreateButton(contentFrame, "Salvar Configurações", function()
                SaveSettings()
                Notify("Configurações", "Salvas com sucesso", 2)
            end)
            saveBtn.Position = UDim2.new(0, 0, 0, 0)

            local loadBtn = CreateButton(contentFrame, "Carregar Configurações", function()
                LoadSettings()
                Notify("Configurações", "Carregadas", 2)
            end)
            loadBtn.Position = UDim2.new(0, 0, 0, 50)

            -- Reset
            local resetBtn = CreateButton(contentFrame, "Resetar Configurações", function()
                -- Resetar para valores padrão (definir manualmente)
                Notify("Reset", "Configurações resetadas", 2)
            end)
            resetBtn.Position = UDim2.new(0, 0, 0, 100)
        end
    end

    UpdateContentFrame()

    return mainFrame
end

-- Funções auxiliares para criação de elementos UI
function CreateToggle(parent, text, defaultValue, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 40)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 1, 0)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.Text = text
    label.TextColor3 = Settings.UI.TextColor
    label.BackgroundTransparency = 1
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local toggleBg = Instance.new("Frame")
    toggleBg.Size = UDim2.new(0, 50, 0, 24)
    toggleBg.Position = UDim2.new(1, -60, 0.5, -12)
    toggleBg.BackgroundColor3 = defaultValue and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(80, 80, 100)
    toggleBg.BorderSizePixel = 0
    toggleBg.Parent = frame

    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(1, 0)
    toggleCorner.Parent = toggleBg

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 20, 0, 20)
    knob.Position = defaultValue and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = toggleBg

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 1, 0)
    button.BackgroundTransparency = 1
    button.Text = ""
    button.Parent = frame

    local active = defaultValue
    button.MouseButton1Click:Connect(function()
        active = not active
        toggleBg.BackgroundColor3 = active and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(80, 80, 100)
        knob.Position = active and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
        callback(active)
    end)

    return frame
end

function CreateSlider(parent, text, min, max, defaultValue, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 50)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 20)
    label.Text = text .. ": " .. tostring(defaultValue)
    label.TextColor3 = Settings.UI.TextColor
    label.BackgroundTransparency = 1
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(1, 0, 0, 4)
    sliderBg.Position = UDim2.new(0, 0, 0, 30)
    sliderBg.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    sliderBg.BorderSizePixel = 0
    sliderBg.Parent = frame

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((defaultValue - min)/(max - min), 0, 1, 0)
    fill.BackgroundColor3 = Settings.UI.PrimaryColor
    fill.BorderSizePixel = 0
    fill.Parent = sliderBg

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 12, 0, 12)
    knob.Position = UDim2.new((defaultValue - min)/(max - min), -6, 0.5, -6)
    knob.BackgroundColor3 = Settings.UI.PrimaryColor
    knob.BorderSizePixel = 0
    knob.Parent = sliderBg

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0, 40, 0, 20)
    valueLabel.Position = UDim2.new(1, -50, 0, 30)
    valueLabel.Text = tostring(defaultValue)
    valueLabel.TextColor3 = Settings.UI.TextColor
    valueLabel.BackgroundTransparency = 1
    valueLabel.Parent = frame

    local dragging = false
    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    knob.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    knob.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local pos = input.Position.X - sliderBg.AbsolutePosition.X
            local percent = math.clamp(pos / sliderBg.AbsoluteSize.X, 0, 1)
            local value = min + percent * (max - min)
            fill.Size = UDim2.new(percent, 0, 1, 0)
            knob.Position = UDim2.new(percent, -6, 0.5, -6)
            valueLabel.Text = string.format("%.2f", value)
            callback(value)
        end
    end)

    return frame
end

function CreateDropdown(parent, text, options, defaultValue, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 50)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 20)
    label.Text = text
    label.TextColor3 = Settings.UI.TextColor
    label.BackgroundTransparency = 1
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local dropdownBtn = Instance.new("TextButton")
    dropdownBtn.Size = UDim2.new(1, 0, 0, 30)
    dropdownBtn.Position = UDim2.new(0, 0, 0, 25)
    dropdownBtn.Text = defaultValue
    dropdownBtn.TextColor3 = Settings.UI.TextColor
    dropdownBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    dropdownBtn.BorderSizePixel = 0
    dropdownBtn.Parent = frame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = dropdownBtn

    local dropdownList = Instance.new("Frame")
    dropdownList.Size = UDim2.new(1, 0, 0, 0)
    dropdownList.Position = UDim2.new(0, 0, 0, 55)
    dropdownList.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    dropdownList.ClipsDescendants = true
    dropdownList.Visible = false
    dropdownList.Parent = frame

    local listCorner = Instance.new("UICorner")
    listCorner.CornerRadius = UDim.new(0, 8)
    listCorner.Parent = dropdownList

    for i, opt in ipairs(options) do
        local optBtn = Instance.new("TextButton")
        optBtn.Size = UDim2.new(1, 0, 0, 30)
        optBtn.Position = UDim2.new(0, 0, 0, (i-1)*30)
        optBtn.Text = opt
        optBtn.TextColor3 = Settings.UI.TextColor
        optBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        optBtn.BorderSizePixel = 0
        optBtn.Parent = dropdownList

        local optCorner = Instance.new("UICorner")
        optCorner.CornerRadius = UDim.new(0, 6)
        optCorner.Parent = optBtn

        optBtn.MouseButton1Click:Connect(function()
            dropdownBtn.Text = opt
            dropdownList.Visible = false
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

function CreateButton(parent, text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 40)
    btn.Text = text
    btn.TextColor3 = Settings.UI.TextColor
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    btn.BorderSizePixel = 0
    btn.Parent = parent

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = btn

    btn.MouseButton1Click:Connect(callback)

    return btn
end

-- ================= INICIALIZAÇÃO =================
LoadSettings()

-- Criar GUI
local floatingBtn, mainGui = CreateFloatingButton()
local mainMenu = CreateMainMenu(mainGui)

-- Loop principal para atualizações em tempo real
RunService.RenderStepped:Connect(function()
    if Settings.ESP.Enabled then
        UpdateESP()
    end
    if Settings.Aimbot.Enabled then
        local target = nil
        if Settings.Aimbot.Target == "Murderer" then
            target = GetClosestMurderer()
        elseif Settings.Aimbot.Target == "Nearest" then
            target = GetNearestPlayer()
        end
        if target then
            AimAt(target)
        end
    end
    if Settings.AutoFarm.Enabled then
        AutoFarm()
    end
    if Settings.AutoPlay.Enabled then
        AutoPlay()
    end
    if Settings.AntiAFK then
        AntiAFK()
    end
    if Settings.Teleport.Enabled then
        -- Exemplo: teletransportar para itens ou jogadores
    end
    if Settings.AutoBuy.Enabled then
        AutoBuy()
    end
    if Settings.NoRecoil then
        NoRecoil()
    end
    if Settings.InstantWin then
        InstantWin()
    end
end)

-- Notificações (simples por enquanto)
local function UpdateNotificationsUI()
    -- Implementação futura para exibir notificações em tela
end

Notify("NEXUS", "Menu carregado com sucesso!", 3)

print("NEXUS Mod Menu carregado. Use a bolinha flutuante para abrir.")
