--[[
    NEXUS PREMIUM - Murder Mystery 2
    Mod Menu Profissional com Design VexonHub
    Compatível com executors mobile e PC
    Versão: 2.0
]]

-- ==================== CONFIGURAÇÕES GLOBAIS ====================
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local VirtualInput = game:GetService("VirtualInput") -- pode não existir em mobile

-- Verificar se o executor permite escrita de arquivos
local canWrite = pcall(function() writefile("test.txt", "test") end)
if canWrite then
    writefile("test.txt", "") -- limpa
end

-- ==================== CONFIGURAÇÕES PADRÃO ====================
local Settings = {
    Aimbot = {
        Enabled = false,
        Silent = false,
        FOV = 150,
        Target = "Murderer", -- "Murderer", "Sheriff", "Innocent", "All"
        Smoothness = 50
    },
    ESP = {
        Enabled = true,
        Players = true,
        Items = true,
        Tracers = false,
        Radar = false,
        Colors = {
            Murderer = Color3.fromRGB(255, 0, 0),
            Sheriff = Color3.fromRGB(0, 100, 255),
            Innocent = Color3.fromRGB(0, 255, 0),
            Knife = Color3.fromRGB(255, 165, 0)
        }
    },
    AutoFarm = {
        Collect = false,
        Reset = false,
        AutoPlay = false
    },
    Movement = {
        Fly = false,
        Speed = 16,
        AntiAFK = true
    },
    Combat = {
        KillAll = false,
        InstantWin = false,
        AutoParry = false
    },
    Protection = {
        AntiBan = true,
        Webhook = "",
        CheckUpdates = false
    },
    Misc = {
        AutoBuy = false,
        Stealth = false
    },
    UI = {
        Opacity = 0.9,
        PrimaryColor = "Purple", -- "Purple", "Blue", "Red"
        Sounds = false
    }
}

-- Cores primárias
local ColorSchemes = {
    Purple = Color3.fromRGB(138, 43, 226),
    Blue = Color3.fromRGB(0, 100, 255),
    Red = Color3.fromRGB(255, 50, 50)
}
local PrimaryColor = ColorSchemes[Settings.UI.PrimaryColor]

-- ==================== VARIÁVEIS GLOBAIS ====================
local Gui = nil
local FloatingButton = nil
local MainMenu = nil
local MenuOpen = false
local Dragging = false
local DragStart, DragStartPos
local Notifications = {}
local ESPObjects = {}
local RadarFrame = nil
local CurrentCategory = "Aimbot"
local PlayerPositions = {} -- para radar
local LastUpdate = tick()
local FlySpeed = 0
local Flying = false
local OriginalSpeed = 16

-- ==================== FUNÇÕES AUXILIARES ====================
function SaveSettings()
    if not canWrite then return end
    local data = HttpService:JSONEncode(Settings)
    writefile("NexusPremium.json", data)
end

function LoadSettings()
    if not canWrite or not isfile("NexusPremium.json") then return end
    local data = readfile("NexusPremium.json")
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
    -- Aplicar cores
    PrimaryColor = ColorSchemes[Settings.UI.PrimaryColor] or ColorSchemes.Purple
end

function Notify(text, icon)
    -- Cria uma notificação simples
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
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = notif

    if icon then
        local iconImg = Instance.new("ImageLabel")
        iconImg.Size = UDim2.new(0, 20, 0, 20)
        iconImg.Position = UDim2.new(0, 5, 0.5, -10)
        iconImg.Image = icon
        iconImg.BackgroundTransparency = 1
        iconImg.Parent = notif
        label.Position = UDim2.new(0, 30, 0, 0)
        label.Size = UDim2.new(1, -35, 1, 0)
    end

    TweenService:Create(notif, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Position = UDim2.new(1, -270, 0, 10) }):Play()
    wait(2)
    TweenService:Create(notif, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Position = UDim2.new(1, -10, 0, 10) }):Play()
    wait(0.5)
    notif:Destroy()
end

-- ==================== CRIAÇÃO DOS ELEMENTOS UI ====================
function CreateFloatingButton()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "NexusPremium"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local button = Instance.new("ImageButton")
    button.Size = UDim2.new(0, 50, 0, 50)
    button.Position = UDim2.new(0, 10, 0, 100)
    button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    button.BackgroundTransparency = 1
    button.Image = "https://img.icons8.com/nolan/1200/nexus-vortex--v2.jpg" -- imagem da bolinha
    button.ImageColor3 = Color3.fromRGB(255, 255, 255)
    button.ImageTransparency = 0.3
    button.Parent = screenGui

    -- Arredondamento
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = button

    -- Carregar posição salva
    if isfile("NexusButtonPos.txt") then
        local pos = readfile("NexusButtonPos.txt")
        local x, y = pos:match("(%d+),(%d+)")
        if x and y then
            button.Position = UDim2.new(0, tonumber(x), 0, tonumber(y))
        end
    end

    -- Arrastar
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
            if canWrite then
                writefile("NexusButtonPos.txt", tostring(button.Position.X.Offset) .. "," .. tostring(button.Position.Y.Offset))
            end
        end
    end)
    button.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - dragStart
            button.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- Abrir/fechar menu
    button.MouseButton1Click:Connect(function()
        MenuOpen = not MenuOpen
        if MenuOpen then
            MainMenu.Visible = true
            TweenService:Create(MainMenu, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { BackgroundTransparency = 0.1 }):Play()
            TweenService:Create(MainMenu, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Position = UDim2.new(0.5, -MainMenu.AbsoluteSize.X/2, 0.5, -MainMenu.AbsoluteSize.Y/2) }):Play()
        else
            TweenService:Create(MainMenu, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
            wait(0.2)
            MainMenu.Visible = false
        end
    end)

    return screenGui, button
end

function CreateMainMenu()
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 400, 0, 500)
    mainFrame.Position = UDim2.new(0.5, -200, 0.5, -250)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.Visible = false
    mainFrame.Parent = Gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 20)
    corner.Parent = mainFrame

    -- Sombra
    local shadow = Instance.new("UIShadow")
    shadow.Parent = mainFrame

    -- Categorias (lateral esquerda)
    local categoriesFrame = Instance.new("Frame")
    categoriesFrame.Size = UDim2.new(0, 100, 1, 0)
    categoriesFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    categoriesFrame.BackgroundTransparency = 0.5
    categoriesFrame.Parent = mainFrame

    local categories = {
        { name = "Aimbot", icon = "https://img.icons8.com/ios-filled/50/ffffff/aim.png" },
        { name = "ESP", icon = "https://img.icons8.com/ios-filled/50/ffffff/eye.png" },
        { name = "Auto Farm", icon = "https://img.icons8.com/ios-filled/50/ffffff/coin.png" },
        { name = "Movimentação", icon = "https://img.icons8.com/ios-filled/50/ffffff/running.png" },
        { name = "Combate", icon = "https://img.icons8.com/ios-filled/50/ffffff/sword.png" },
        { name = "Proteção", icon = "https://img.icons8.com/ios-filled/50/ffffff/shield.png" },
        { name = "Misc", icon = "https://img.icons8.com/ios-filled/50/ffffff/tools.png" },
        { name = "Configurações", icon = "https://img.icons8.com/ios-filled/50/ffffff/settings.png" }
    }

    local categoryButtons = {}
    for i, cat in ipairs(categories) do
        local btn = Instance.new("ImageButton")
        btn.Size = UDim2.new(1, 0, 0, 60)
        btn.Position = UDim2.new(0, 0, 0, (i-1)*65)
        btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        btn.BackgroundTransparency = 0.5
        btn.Image = cat.icon
        btn.ImageColor3 = Color3.fromRGB(255, 255, 255)
        btn.Parent = categoriesFrame

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 12)
        btnCorner.Parent = btn

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 20)
        label.Position = UDim2.new(0, 0, 1, -25)
        label.BackgroundTransparency = 1
        label.Text = cat.name
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextSize = 10
        label.Font = Enum.Font.GothamBold
        label.Parent = btn

        btn.MouseButton1Click:Connect(function()
            CurrentCategory = cat.name
            UpdateContentFrame()
        end)
        categoryButtons[cat.name] = btn
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
    profileCorner.CornerRadius = UDim.new(1, 0)
    profileCorner.Parent = profileImage

    -- Função para atualizar o conteúdo conforme categoria
    local function UpdateContentFrame()
        for _, child in pairs(contentFrame:GetChildren()) do
            child:Destroy()
        end

        -- ScrollView
        local scroll = Instance.new("ScrollingFrame")
        scroll.Size = UDim2.new(1, 0, 1, 0)
        scroll.BackgroundTransparency = 1
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroll.ScrollBarThickness = 4
        scroll.Parent = contentFrame

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 8)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = scroll

        local yOffset = 0

        -- Funções para criar elementos
        function CreateToggle(text, defaultValue, callback)
            local frame = Instance.new("Frame")
            frame.Size = UDim2.new(1, -20, 0, 50)
            frame.BackgroundTransparency = 1
            frame.Parent = scroll

            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(0.6, 0, 1, 0)
            label.Position = UDim2.new(0, 0, 0, 0)
            label.Text = text
            label.TextColor3 = Color3.fromRGB(255, 255, 255)
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

            local active = defaultValue
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 1, 0)
            btn.BackgroundTransparency = 1
            btn.Text = ""
            btn.Parent = frame

            btn.MouseButton1Click:Connect(function()
                active = not active
                toggleBg.BackgroundColor3 = active and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(80, 80, 100)
                knob.Position = active and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
                callback(active)
                if Settings.UI.Sounds then
                    -- place sound
                end
            end)

            return frame
        end

        function CreateSlider(text, min, max, defaultValue, callback)
            local frame = Instance.new("Frame")
            frame.Size = UDim2.new(1, -20, 0, 60)
            frame.BackgroundTransparency = 1
            frame.Parent = scroll

            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, 0, 0, 20)
            label.Text = text .. ": " .. tostring(defaultValue)
            label.TextColor3 = Color3.fromRGB(255, 255, 255)
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
            knobCorner.CornerRadius = UDim.new(1, 0)
            knobCorner.Parent = knob

            local valueLabel = Instance.new("TextLabel")
            valueLabel.Size = UDim2.new(0, 40, 0, 20)
            valueLabel.Position = UDim2.new(1, -50, 0, 30)
            valueLabel.Text = tostring(defaultValue)
            valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
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

        function CreateDropdown(text, options, defaultOption, callback)
            local frame = Instance.new("Frame")
            frame.Size = UDim2.new(1, -20, 0, 60)
            frame.BackgroundTransparency = 1
            frame.Parent = scroll

            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, 0, 0, 20)
            label.Text = text
            label.TextColor3 = Color3.fromRGB(255, 255, 255)
            label.BackgroundTransparency = 1
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Parent = frame

            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 0, 30)
            btn.Position = UDim2.new(0, 0, 0, 25)
            btn.Text = defaultOption
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
            btn.BorderSizePixel = 0
            btn.Parent = frame

            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 8)
            btnCorner.Parent = btn

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
                optBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                optBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
                optBtn.BorderSizePixel = 0
                optBtn.Parent = dropdownList

                local optCorner = Instance.new("UICorner")
                optCorner.CornerRadius = UDim.new(0, 6)
                optCorner.Parent = optBtn

                optBtn.MouseButton1Click:Connect(function()
                    btn.Text = opt
                    dropdownList.Visible = false
                    dropdownList.Size = UDim2.new(1, 0, 0, 0)
                    callback(opt)
                end)
            end

            btn.MouseButton1Click:Connect(function()
                dropdownList.Visible = not dropdownList.Visible
                if dropdownList.Visible then
                    dropdownList.Size = UDim2.new(1, 0, 0, #options * 30)
                else
                    dropdownList.Size = UDim2.new(1, 0, 0, 0)
                end
            end)

            return frame
        end

        function CreateButton(text, callback)
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -20, 0, 40)
            btn.Text = text
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
            btn.BorderSizePixel = 0
            btn.Parent = scroll

            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 8)
            btnCorner.Parent = btn

            btn.MouseButton1Click:Connect(callback)
            return btn
        end

        -- Conteúdo por categoria
        if CurrentCategory == "Aimbot" then
            CreateToggle("Ativar Aimbot", Settings.Aimbot.Enabled, function(v)
                Settings.Aimbot.Enabled = v
                Notify("Aimbot " .. (v and "ativado" or "desativado"))
                SaveSettings()
            end)
            CreateToggle("Silent Aim", Settings.Aimbot.Silent, function(v)
                Settings.Aimbot.Silent = v
                Notify("Silent Aim " .. (v and "ativado" or "desativado"))
                SaveSettings()
            end)
            CreateSlider("Campo de mira", 50, 300, Settings.Aimbot.FOV, function(v)
                Settings.Aimbot.FOV = v
                SaveSettings()
            end)
            CreateDropdown("Alvo preferencial", {"Assassino", "Xerife", "Inocente", "Todos"}, Settings.Aimbot.Target, function(v)
                Settings.Aimbot.Target = v
                SaveSettings()
            end)
            CreateSlider("Smoothness", 0, 100, Settings.Aimbot.Smoothness, function(v)
                Settings.Aimbot.Smoothness = v
                SaveSettings()
            end)

        elseif CurrentCategory == "ESP" then
            CreateToggle("ESP Jogadores", Settings.ESP.Players, function(v)
                Settings.ESP.Players = v
                SaveSettings()
                if v then CreateESP() else ClearESP() end
            end)
            CreateToggle("ESP Itens", Settings.ESP.Items, function(v)
                Settings.ESP.Items = v
                SaveSettings()
            end)
            CreateToggle("Traçadores", Settings.ESP.Tracers, function(v)
                Settings.ESP.Tracers = v
                SaveSettings()
            end)
            CreateToggle("Radar 2D", Settings.ESP.Radar, function(v)
                Settings.ESP.Radar = v
                if v then CreateRadar() else if RadarFrame then RadarFrame:Destroy() end end
                SaveSettings()
            end)

        elseif CurrentCategory == "Auto Farm" then
            CreateToggle("Auto Collect", Settings.AutoFarm.Collect, function(v)
                Settings.AutoFarm.Collect = v
                SaveSettings()
            end)
            CreateToggle("Auto Reset", Settings.AutoFarm.Reset, function(v)
                Settings.AutoFarm.Reset = v
                SaveSettings()
            end)
            CreateToggle("Auto Play", Settings.AutoFarm.AutoPlay, function(v)
                Settings.AutoFarm.AutoPlay = v
                SaveSettings()
            end)

        elseif CurrentCategory == "Movimentação" then
            CreateToggle("Fly / NoClip", Settings.Movement.Fly, function(v)
                Settings.Movement.Fly = v
                SaveSettings()
                if v then
                    Flying = true
                    FlySpeed = 50
                else
                    Flying = false
                end
            end)
            CreateSlider("Speed Hack", 16, 100, Settings.Movement.Speed, function(v)
                Settings.Movement.Speed = v
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                    LocalPlayer.Character.Humanoid.WalkSpeed = v
                end
                SaveSettings()
            end)
            CreateButton("Teletransporte para Item", function()
                -- Implementar teleporte para item mais próximo
                local closestItem = nil
                local closestDist = math.huge
                for _, obj in pairs(Workspace:GetDescendants()) do
                    if obj:IsA("BasePart") and (obj.Name:find("Coin") or obj.Name:find("Knife")) then
                        local dist = (LocalPlayer.Character.HumanoidRootPart.Position - obj.Position).magnitude
                        if dist < closestDist then
                            closestDist = dist
                            closestItem = obj
                        end
                    end
                end
                if closestItem then
                    LocalPlayer.Character.HumanoidRootPart.CFrame = closestItem.CFrame + Vector3.new(0, 3, 0)
                    Notify("Teleportado para item")
                else
                    Notify("Nenhum item próximo encontrado")
                end
            end)
            CreateToggle("Anti-AFK", Settings.Movement.AntiAFK, function(v)
                Settings.Movement.AntiAFK = v
                SaveSettings()
            end)

        elseif CurrentCategory == "Combate" then
            CreateButton("Kill All", function()
                for _, player in pairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Humanoid") then
                        player.Character.Humanoid.Health = 0
                    end
                end
                Notify("Kill All executado")
            end)
            CreateButton("Instant Win", function()
                -- Simula vitória instantânea (pode não funcionar em todos servidores)
                -- Tenta enviar um evento remoto (exemplo)
                local remote = game:GetService("ReplicatedStorage"):FindFirstChild("WinEvent") -- ajustar
                if remote then
                    remote:FireServer()
                end
                Notify("Instant Win tentado")
            end)
            CreateToggle("Auto Parry", Settings.Combat.AutoParry, function(v)
                Settings.Combat.AutoParry = v
                SaveSettings()
            end)

        elseif CurrentCategory == "Proteção" then
            CreateToggle("Anti-Ban", Settings.Protection.AntiBan, function(v)
                Settings.Protection.AntiBan = v
                SaveSettings()
            end)
            -- Webhook
            local webhookFrame = Instance.new("Frame")
            webhookFrame.Size = UDim2.new(1, -20, 0, 80)
            webhookFrame.BackgroundTransparency = 1
            webhookFrame.Parent = scroll

            local webhookLabel = Instance.new("TextLabel")
            webhookLabel.Size = UDim2.new(1, 0, 0, 20)
            webhookLabel.Text = "Webhook URL:"
            webhookLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            webhookLabel.BackgroundTransparency = 1
            webhookLabel.TextXAlignment = Enum.TextXAlignment.Left
            webhookLabel.Parent = webhookFrame

            local webhookInput = Instance.new("TextBox")
            webhookInput.Size = UDim2.new(1, 0, 0, 30)
            webhookInput.Position = UDim2.new(0, 0, 0, 25)
            webhookInput.PlaceholderText = "https://discord.com/api/webhooks/..."
            webhookInput.Text = Settings.Protection.Webhook or ""
            webhookInput.TextColor3 = Color3.fromRGB(255, 255, 255)
            webhookInput.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
            webhookInput.BorderSizePixel = 0
            webhookInput.Parent = webhookFrame

            local webhookCorner = Instance.new("UICorner")
            webhookCorner.CornerRadius = UDim.new(0, 8)
            webhookCorner.Parent = webhookInput

            webhookInput:GetPropertyChangedSignal("Text"):Connect(function()
                Settings.Protection.Webhook = webhookInput.Text
                SaveSettings()
            end)

            CreateButton("Testar Webhook", function()
                if Settings.Protection.Webhook and Settings.Protection.Webhook ~= "" then
                    local success, err = pcall(function()
                        HttpService:PostAsync(Settings.Protection.Webhook, HttpService:JSONEncode({ content = "NEXUS Premium: Teste de notificação!" }))
                    end)
                    if success then
                        Notify("Webhook enviado com sucesso!")
                    else
                        Notify("Erro ao enviar webhook: " .. tostring(err))
                    end
                else
                    Notify("Insira uma URL de webhook válida")
                end
            end)

            CreateButton("Verificar Atualizações", function()
                -- Verificar versão no pastebin ou github
                local url = "https://raw.githubusercontent.com/seuuser/nexus/version.txt" -- substituir
                local success, data = pcall(function()
                    return game:HttpGet(url)
                end)
                if success and data then
                    local latestVersion = data:match("VERSION=(.+)")
                    if latestVersion and latestVersion ~= "2.0" then
                        Notify("Nova versão disponível: " .. latestVersion)
                    else
                        Notify("Você está na versão mais recente")
                    end
                else
                    Notify("Erro ao verificar atualizações")
                end
            end)

        elseif CurrentCategory == "Misc" then
            CreateToggle("Auto Buy", Settings.Misc.AutoBuy, function(v)
                Settings.Misc.AutoBuy = v
                SaveSettings()
            end)
            CreateButton("Recolher Todas Moedas", function()
                for _, obj in pairs(Workspace:GetDescendants()) do
                    if obj:IsA("BasePart") and obj.Name:find("Coin") then
                        local click = obj:FindFirstChildOfClass("ClickDetector")
                        if click then
                            click:FireClick()
                        end
                    end
                end
                Notify("Moedas recolhidas")
            end)
            CreateToggle("Modo Stealth", Settings.Misc.Stealth, function(v)
                Settings.Misc.Stealth = v
                if v then
                    -- Desativar visualmente as funções (manter lógica)
                    -- Por exemplo, esconder ESP, etc.
                end
                SaveSettings()
            end)

        elseif CurrentCategory == "Configurações" then
            CreateButton("Salvar Configurações", function()
                SaveSettings()
                Notify("Configurações salvas")
            end)
            CreateButton("Carregar Configurações", function()
                LoadSettings()
                Notify("Configurações carregadas")
                -- Recriar interface para aplicar alterações
                UpdateContentFrame()
            end)
            CreateSlider("Opacidade do Menu", 0.5, 1, Settings.UI.Opacity, function(v)
                Settings.UI.Opacity = v
                mainFrame.BackgroundTransparency = 1 - v
                SaveSettings()
            end)
            CreateDropdown("Cor Primária", {"Roxo", "Azul", "Vermelho"}, Settings.UI.PrimaryColor, function(v)
                Settings.UI.PrimaryColor = v
                PrimaryColor = ColorSchemes[v]
                SaveSettings()
                -- Atualizar cores dos elementos
                UpdateContentFrame() -- recria para aplicar nova cor
            end)
            CreateToggle("Sons de Ativação", Settings.UI.Sounds, function(v)
                Settings.UI.Sounds = v
                SaveSettings()
            end)
        end

        -- Atualizar canvas size do scroll
        local function updateCanvas()
            local totalHeight = 0
            for _, child in pairs(scroll:GetChildren()) do
                if child:IsA("Frame") or child:IsA("TextButton") then
                    totalHeight = totalHeight + child.Size.Y.Offset + layout.Padding.Offset
                end
            end
            scroll.CanvasSize = UDim2.new(0, 0, 0, totalHeight + 10)
        end
        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
        updateCanvas()
    end

    UpdateContentFrame()
    return mainFrame
end

-- ==================== FUNÇÕES ESP (DRAWING) ====================
local function CreateESP()
    -- Implementação com Drawing (se suportado)
    -- Se não, usar BillboardGui
    pcall(function()
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                -- Criar objetos de desenho
            end
        end
    end)
end

function ClearESP()
    for _, obj in pairs(ESPObjects) do
        if obj and obj.Remove then obj:Remove() end
    end
    ESPObjects = {}
end

-- ==================== RADAR 2D ====================
function CreateRadar()
    if RadarFrame then RadarFrame:Destroy() end
    RadarFrame = Instance.new("Frame")
    RadarFrame.Size = UDim2.new(0, 150, 0, 150)
    RadarFrame.Position = UDim2.new(1, -160, 1, -160)
    RadarFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    RadarFrame.BackgroundTransparency = 0.5
    RadarFrame.BorderSizePixel = 0
    RadarFrame.Parent = Gui

    local radarCorner = Instance.new("UICorner")
    radarCorner.CornerRadius = UDim.new(0, 75)
    radarCorner.Parent = RadarFrame

    -- Atualizar posições
    RunService.RenderStepped:Connect(function()
        if not Settings.ESP.Radar then return end
        -- Limpar pontos antigos
        for _, child in pairs(RadarFrame:GetChildren()) do
            if child:IsA("ImageLabel") then
                child:Destroy()
            end
        end
        local center = RadarFrame.AbsoluteSize / 2
        local localPos = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position or Vector3.new()
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                local relative = player.Character.HumanoidRootPart.Position - localPos
                local angle = math.atan2(relative.X, relative.Z)
                local dist = relative.Magnitude / 10 -- escala
                local x = center.X + math.sin(angle) * dist
                local z = center.Y + math.cos(angle) * dist
                if x > 0 and x < RadarFrame.AbsoluteSize.X and z > 0 and z < RadarFrame.AbsoluteSize.Y then
                    local dot = Instance.new("ImageLabel")
                    dot.Size = UDim2.new(0, 4, 0, 4)
                    dot.Position = UDim2.new(0, x, 0, z)
                    dot.BackgroundColor3 = Settings.ESP.Colors[player:GetAttribute("Role")] or Settings.ESP.Colors.Innocent
                    dot.BackgroundTransparency = 0
                    dot.Image = ""
                    dot.Parent = RadarFrame
                end
            end
        end
    end)
end

-- ==================== LOOP DE FUNÇÕES ====================
-- Aimbot (simples)
local function AimAt(target)
    if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then return end
    local targetPos = target.Character.HumanoidRootPart.Position
    local camPos = Camera.CFrame.Position
    local direction = (targetPos - camPos).unit
    local newCFrame = CFrame.new(camPos, camPos + direction)
    Camera.CFrame = Camera.CFrame:Lerp(newCFrame, Settings.Aimbot.Smoothness / 100)
end

-- Auto Collect
local function AutoCollect()
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and (obj.Name:find("Coin") or obj.Name:find("Knife")) then
            local click = obj:FindFirstChildOfClass("ClickDetector")
            if click then
                click:FireClick()
            end
        end
    end
end

-- Auto Reset (quando morrer)
local function AutoReset()
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("Humanoid") or LocalPlayer.Character.Humanoid.Health <= 0 then
        -- Esperar respawn
        wait(2)
        -- Tentar reentrar? Simular clique em botão de reiniciar
        local resetButton = game:GetService("StarterGui"):FindFirstChild("ResetButton") -- lugar comum
        if resetButton then
            resetButton:FireClick()
        end
    end
end

-- Anti-AFK
local function AntiAFK()
    if Settings.Movement.AntiAFK then
        -- Simular movimento de mouse ou toque
        VirtualInput:SendMouseButtonEvent(0, 0, 0, true, Enum.UserInputType.MouseButton1, 1)
        wait(0.1)
        VirtualInput:SendMouseButtonEvent(0, 0, 0, false, Enum.UserInputType.MouseButton1, 1)
    end
end

-- Fly
local function FlyLoop()
    if Flying then
        local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.PlatformStand = true
            local bodyVelocity = Instance.new("BodyVelocity")
            bodyVelocity.MaxForce = Vector3.new(1, 1, 1) * 100000
            bodyVelocity.Velocity = Vector3.new(0, FlySpeed, 0)
            bodyVelocity.Parent = LocalPlayer.Character.HumanoidRootPart
            -- Controles (WASD) para movimentação no ar
            -- Implementação simplificada
        end
    else
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.PlatformStand = false
            for _, v in pairs(LocalPlayer.Character:GetDescendants()) do
                if v:IsA("BodyVelocity") then v:Destroy() end
            end
        end
    end
end

-- ==================== EXECUÇÃO PRINCIPAL ====================
LoadSettings()
Gui = CreateFloatingButton()
MainMenu = CreateMainMenu()

-- Aplicar velocidade inicial
if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
    LocalPlayer.Character.Humanoid.WalkSpeed = Settings.Movement.Speed
end

-- Loop principal
RunService.RenderStepped:Connect(function()
    if Settings.ESP.Enabled and Settings.ESP.Players then
        CreateESP()
    end
    if Settings.Aimbot.Enabled then
        local target = nil
        if Settings.Aimbot.Target == "Assassino" then
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player:GetAttribute("Role") == "Murderer" then
                    target = player
                    break
                end
            end
        elseif Settings.Aimbot.Target == "Xerife" then
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player:GetAttribute("Role") == "Sheriff" then
                    target = player
                    break
                end
            end
        elseif Settings.Aimbot.Target == "Inocente" then
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and not player:GetAttribute("Role") then
                    target = player
                    break
                end
            end
        elseif Settings.Aimbot.Target == "Todos" then
            local nearest = nil
            local nearestDist = math.huge
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    local dist = (LocalPlayer.Character.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).magnitude
                    if dist < nearestDist then
                        nearestDist = dist
                        nearest = player
                    end
                end
            end
            target = nearest
        end
        if target then
            AimAt(target)
        end
    end
    if Settings.AutoFarm.Collect then
        AutoCollect()
    end
    if Settings.AutoFarm.Reset then
        AutoReset()
    end
    if Settings.Movement.AntiAFK then
        AntiAFK()
    end
    if Settings.Movement.Fly then
        FlyLoop()
    end
    -- Auto Play (simples)
    if Settings.AutoFarm.AutoPlay then
        -- Pular round automaticamente (detectar fim)
        local roundEnded = false -- implementar
        if roundEnded then
            -- Simular clique no botão de próximo round
        end
    end
    -- Auto Parry (defesa automática)
    if Settings.Combat.AutoParry then
        -- Detectar quando alguém estiver perto e bloquear
    end
end)

-- Inicializar notificação
Notify("NEXUS Premium carregado", "https://img.icons8.com/ios-filled/50/ffffff/checkmark.png")
print("NEXUS Premium carregado com sucesso!")
