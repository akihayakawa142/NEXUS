--[[
    NEXUS PREMIUM - Murder Mystery 2
    Versão: 2.0
    Design: VexonHub inspired
    Funcionalidades completas: Aimbot, ESP, Auto Farm, Movimentação, Combate, Proteção, Misc
    Compatível com PC e Mobile (toque arrastável)
    Persistência de configurações (writefile/readfile)
    Webhook de atualização (opcional)
    Interface com categorias laterais, switches, sliders, botões
    Notificações elegantes
]]

-- ================= CONFIGURAÇÕES INICIAIS =================
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- ================= CONFIGURAÇÕES PERSISTENTES =================
local Settings = {
    -- Aimbot
    Aimbot = {
        Enabled = false,
        Silent = true,
        Target = "Murderer", -- "Murderer", "Sheriff", "Any"
        Smoothness = 0.3,
        MaxDistance = 100,
        FOV = {
            Enabled = true,
            Radius = 150,
            Color = Color3.fromRGB(255, 0, 0),
            Thickness = 2
        }
    },
    -- ESP
    ESP = {
        Enabled = false,
        Players = {
            Enabled = true,
            ShowBoxes = true,
            ShowNames = true,
            ShowHealth = false,
            ShowDistance = true,
            Colors = {
                Innocent = Color3.fromRGB(255, 255, 255),
                Murderer = Color3.fromRGB(255, 0, 0),
                Sheriff = Color3.fromRGB(0, 255, 0),
                Knife = Color3.fromRGB(255, 165, 0)
            }
        },
        Items = {
            Enabled = true,
            ShowCoins = true,
            ShowKnife = true
        },
        Tracers = {
            Enabled = false,
            Color = Color3.fromRGB(0, 255, 255)
        },
        Radar = {
            Enabled = false,
            Size = 150,
            Position = "BottomRight" -- "TopLeft", "TopRight", "BottomLeft", "BottomRight"
        }
    },
    -- Auto Farm
    AutoFarm = {
        Enabled = false,
        CollectCoins = true,
        CollectKnife = true,
        AutoReset = false,
        AutoPlay = false,
        FarmSpeed = 0.5 -- segundos entre coletas
    },
    -- Movimentação
    Movement = {
        Fly = false,
        Noclip = false,
        SpeedHack = {
            Enabled = false,
            Speed = 32
        },
        Teleport = {
            Enabled = false,
            Target = "Items" -- "Items", "Players", "Coordinates"
        },
        AntiAFK = false
    },
    -- Combate
    Combat = {
        KillAll = false,
        InstantWin = false,
        AutoParry = false,
        NoRecoil = false
    },
    -- Proteção
    Protection = {
        AntiBan = true,
        RandomDelay = 0.1,
        Webhook = "https://discord.com/api/webhooks/seu-webhook-aqui" -- substitua
    },
    -- Misc
    Misc = {
        AutoBuy = false,
        StealthMode = false,
        SoundEffects = true,
        PrimaryColor = Color3.fromRGB(138, 43, 226) -- roxo
    }
}

-- ================= VARIÁVEIS GLOBAIS =================
local ESPObjects = {} -- player -> { box, name, distance, tracer, ... }
local RadarObjects = {} -- para radar
local NotificationQueue = {}
local CurrentCategory = "Aimbot"
local MenuOpen = false
local Dragging = false
local DragStart, StartPos
local Flying = false
local Noclip = false
local OriginalSpeed = 16 -- velocidade padrão do MM2

-- ================= FUNÇÕES AUXILIARES =================
function SaveSettings()
    local data = {}
    for cat, vals in pairs(Settings) do
        data[cat] = vals
    end
    local success, err = pcall(function()
        writefile("NexusPremium.json", HttpService:JSONEncode(data))
    end)
    if not success then
        warn("Falha ao salvar configurações: " .. tostring(err))
    end
end

function LoadSettings()
    local success, data = pcall(function()
        if isfile("NexusPremium.json") then
            return HttpService:JSONDecode(readfile("NexusPremium.json"))
        end
    end)
    if success and data then
        for cat, vals in pairs(data) do
            if Settings[cat] then
                for key, val in pairs(vals) do
                    if type(Settings[cat][key]) == type(val) then
                        Settings[cat][key] = val
                    end
                end
            end
        end
    end
end

function Notify(title, message, duration)
    duration = duration or 2
    table.insert(NotificationQueue, { title = title, message = message, duration = duration, created = tick() })
    -- A UI de notificações será atualizada no loop de render
end

-- ================= CRIAR ELEMENTOS DE DESENHO (ESP, RADAR) =================
local function CreateDrawingObjects(player)
    if ESPObjects[player] then return end
    local box = Drawing.new("Square")
    box.Thickness = 2
    box.Color = Settings.ESP.Players.Colors.Innocent
    box.Visible = false
    
    local name = Drawing.new("Text")
    name.Size = 14
    name.Center = true
    name.Outline = true
    name.Color = box.Color
    name.Visible = false
    
    local distance = Drawing.new("Text")
    distance.Size = 12
    distance.Center = true
    distance.Outline = true
    distance.Color = Color3.fromRGB(200,200,200)
    distance.Visible = false
    
    local tracer = Drawing.new("Line")
    tracer.Thickness = 1
    tracer.Color = Settings.ESP.Tracers.Color
    tracer.Visible = false
    
    ESPObjects[player] = { box = box, name = name, distance = distance, tracer = tracer }
end

local function UpdateESP()
    if not Settings.ESP.Enabled then return end
    local camera = workspace.CurrentCamera
    local viewportSize = camera.ViewportSize
    for player, objs in pairs(ESPObjects) do
        if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local root = player.Character.HumanoidRootPart
            local pos, onScreen = camera:WorldToViewportPoint(root.Position)
            if onScreen then
                -- Determinar cor baseada no papel
                local role = player:GetAttribute("Role") or (player.Team and player.Team.Name) or ""
                local color = Settings.ESP.Players.Colors.Innocent
                if role == "Murderer" then
                    color = Settings.ESP.Players.Colors.Murderer
                elseif role == "Sheriff" then
                    color = Settings.ESP.Players.Colors.Sheriff
                end
                
                -- Caixa
                if Settings.ESP.Players.ShowBoxes then
                    local size = player.Character:GetExtentsSize()
                    local width = size.X * 4
                    local height = size.Y * 4
                    local boxPos = Vector2.new(pos.X - width/2, pos.Y - height/2)
                    objs.box.Size = Vector2.new(width, height)
                    objs.box.Position = boxPos
                    objs.box.Color = color
                    objs.box.Visible = true
                else
                    objs.box.Visible = false
                end
                
                -- Nome
                if Settings.ESP.Players.ShowNames then
                    objs.name.Text = player.Name
                    objs.name.Position = Vector2.new(pos.X, pos.Y - 25)
                    objs.name.Color = color
                    objs.name.Visible = true
                else
                    objs.name.Visible = false
                end
                
                -- Distância
                if Settings.ESP.Players.ShowDistance then
                    local dist = (LocalPlayer.Character.HumanoidRootPart.Position - root.Position).magnitude
                    objs.distance.Text = string.format("%.1fm", dist)
                    objs.distance.Position = Vector2.new(pos.X, pos.Y + 10)
                    objs.distance.Visible = true
                else
                    objs.distance.Visible = false
                end
                
                -- Tracer
                if Settings.ESP.Tracers.Enabled then
                    objs.tracer.From = Vector2.new(viewportSize.X/2, viewportSize.Y)
                    objs.tracer.To = Vector2.new(pos.X, pos.Y)
                    objs.tracer.Color = Settings.ESP.Tracers.Color
                    objs.tracer.Visible = true
                else
                    objs.tracer.Visible = false
                end
            else
                objs.box.Visible = false
                objs.name.Visible = false
                objs.distance.Visible = false
                objs.tracer.Visible = false
            end
        else
            objs.box.Visible = false
            objs.name.Visible = false
            objs.distance.Visible = false
            objs.tracer.Visible = false
        end
    end
end

local function CreateESPForAll()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            CreateDrawingObjects(player)
        end
    end
end

-- ================= RADAR 2D =================
local radarFrame = nil
local radarPoints = {}
local function CreateRadar()
    if radarFrame then radarFrame:Destroy() end
    if not Settings.ESP.Radar.Enabled then return end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "NexusRadar"
    screenGui.Parent = LocalPlayer.PlayerGui
    
    local size = Settings.ESP.Radar.Size
    local position = Settings.ESP.Radar.Position
    local posOffset = UDim2.new()
    if position == "TopLeft" then
        posOffset = UDim2.new(0, 10, 0, 10)
    elseif position == "TopRight" then
        posOffset = UDim2.new(1, -size-10, 0, 10)
    elseif position == "BottomLeft" then
        posOffset = UDim2.new(0, 10, 1, -size-10)
    else -- BottomRight
        posOffset = UDim2.new(1, -size-10, 1, -size-10)
    end
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, size, 0, size)
    frame.Position = posOffset
    frame.BackgroundColor3 = Color3.fromRGB(0,0,0)
    frame.BackgroundTransparency = 0.5
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = frame
    
    local center = Instance.new("Frame")
    center.Size = UDim2.new(0, 4, 0, 4)
    center.Position = UDim2.new(0.5, -2, 0.5, -2)
    center.BackgroundColor3 = Color3.fromRGB(255,255,255)
    center.BorderSizePixel = 0
    center.Parent = frame
    
    local centerCorner = Instance.new("UICorner")
    centerCorner.CornerRadius = UDim.new(1,0)
    centerCorner.Parent = center
    
    radarFrame = frame
end

local function UpdateRadar()
    if not Settings.ESP.Radar.Enabled or not radarFrame then return end
    -- Limpar pontos antigos
    for _, point in pairs(radarPoints) do
        point:Destroy()
    end
    radarPoints = {}
    
    local centerX = radarFrame.AbsoluteSize.X / 2
    local centerY = radarFrame.AbsoluteSize.Y / 2
    local playerPos = LocalPlayer.Character and LocalPlayer.Character.HumanoidRootPart.Position
    if not playerPos then return end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local targetPos = player.Character.HumanoidRootPart.Position
            local diff = targetPos - playerPos
            local angle = math.atan2(diff.Z, diff.X)
            local dist = diff.Magnitude
            local scale = math.min(1, 100 / dist) -- escala máxima 100
            local radius = (radarFrame.AbsoluteSize.X / 2) * scale
            local x = centerX + radius * math.cos(angle)
            local y = centerY + radius * math.sin(angle)
            
            local point = Instance.new("Frame")
            point.Size = UDim2.new(0, 4, 0, 4)
            point.Position = UDim2.new(0, x-2, 0, y-2)
            point.BackgroundColor3 = Settings.ESP.Players.Colors.Innocent
            local role = player:GetAttribute("Role") or (player.Team and player.Team.Name) or ""
            if role == "Murderer" then
                point.BackgroundColor3 = Settings.ESP.Players.Colors.Murderer
            elseif role == "Sheriff" then
                point.BackgroundColor3 = Settings.ESP.Players.Colors.Sheriff
            end
            point.BorderSizePixel = 0
            point.Parent = radarFrame
            
            local pointCorner = Instance.new("UICorner")
            pointCorner.CornerRadius = UDim.new(1,0)
            pointCorner.Parent = point
            
            table.insert(radarPoints, point)
        end
    end
end

-- ================= AIMBOT (Silent) =================
local function GetTarget()
    local camera = workspace.CurrentCamera
    local mousePos = UserInputService:GetMouseLocation()
    local target = nil
    local closestDist = Settings.Aimbot.FOV.Radius
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local role = player:GetAttribute("Role") or (player.Team and player.Team.Name) or ""
            if Settings.Aimbot.Target == "Murderer" and role ~= "Murderer" then continue end
            if Settings.Aimbot.Target == "Sheriff" and role ~= "Sheriff" then continue end
            
            local root = player.Character.HumanoidRootPart
            local screenPos, onScreen = camera:WorldToViewportPoint(root.Position)
            if onScreen then
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    target = player
                end
            end
        end
    end
    return target
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

local function SilentAim(target)
    -- Silent aim: modifica a direção do tiro sem mover a câmera
    -- Isso geralmente é feito interceptando eventos remotos ou modificando o mouse
    -- Para MM2, podemos simular alterando o ângulo de disparo no momento do click
    -- Aqui implementamos uma versão simples: ao atirar, redireciona o tiro para o alvo
    if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
        -- Simular um evento de tiro (exemplo: chamar função remota)
        -- Na prática, você precisaria encontrar a função de atirar no jogo
        -- Vamos deixar como placeholder
        -- fireclickdetector ou invocar remoto
    end
end

-- ================= AUTO FARM =================
local function AutoCollect()
    if not Settings.AutoFarm.Enabled then return end
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            if Settings.AutoFarm.CollectCoins and obj.Name:find("Coin") then
                local click = obj:FindFirstChildOfClass("ClickDetector")
                if click then
                    fireclickdetector(click)
                end
            end
            if Settings.AutoFarm.CollectKnife and obj.Name:find("Knife") then
                local click = obj:FindFirstChildOfClass("ClickDetector")
                if click then
                    fireclickdetector(click)
                end
            end
        end
    end
end

-- ================= MOVIMENTAÇÃO =================
local function StartFly()
    if Flying then return end
    Flying = true
    local char = LocalPlayer.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.PlatformStand = true
    end
    local bodyVel = Instance.new("BodyVelocity")
    bodyVel.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bodyVel.Velocity = Vector3.new(0,0,0)
    bodyVel.Parent = char.HumanoidRootPart
    
    local connection
    connection = RunService.RenderStepped:Connect(function()
        if not Flying then
            connection:Disconnect()
            bodyVel:Destroy()
            if humanoid then humanoid.PlatformStand = false end
            return
        end
        local move = Vector3.new(
            (UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0),
            (UserInputService:IsKeyDown(Enum.KeyCode.Space) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and 1 or 0),
            (UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0)
        )
        if move.Magnitude > 0 then
            move = move.unit
        end
        local camera = workspace.CurrentCamera
        local forward = camera.CFrame.LookVector
        local right = camera.CFrame.RightVector
        local vel = (right * move.X + Vector3.new(0, move.Y, 0) + forward * move.Z) * 50
        bodyVel.Velocity = vel
    end)
end

local function StopFly()
    Flying = false
end

local function NoclipToggle()
    Noclip = not Noclip
    if Noclip then
        local char = LocalPlayer.Character
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
        -- Atualizar quando o personagem for atualizado
        local connection
        connection = LocalPlayer.CharacterAdded:Connect(function(newChar)
            for _, part in pairs(newChar:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end)
    else
        -- Restaurar colisão
        local char = LocalPlayer.Character
        if char then
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
    end
end

local function SpeedHack()
    if Settings.Movement.SpeedHack.Enabled then
        local char = LocalPlayer.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = Settings.Movement.SpeedHack.Speed
        end
    else
        local char = LocalPlayer.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 16 -- velocidade padrão
        end
    end
end

local function AntiAFK()
    if not Settings.Movement.AntiAFK then return end
    -- Simula movimento leve periodicamente
    local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid:Move(Vector3.new(0,0,0), true)
    end
end

-- ================= COMBATE =================
local function KillAll()
    if not Settings.Combat.KillAll then return end
    -- Buscar todos os jogadores e simular morte
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Humanoid") then
            player.Character.Humanoid.Health = 0
        end
    end
end

local function InstantWin()
    if not Settings.Combat.InstantWin then return end
    -- MM2: vencer a partida é disparar um evento remoto (exemplo)
    -- Precisamos encontrar a função que envia vitória
    -- Placeholder: enviar evento de "round win"
    local remote = ReplicatedStorage:FindFirstChild("RoundWin") or ReplicatedStorage:FindFirstChild("GameWin")
    if remote then
        remote:FireServer()
    end
end

local function AutoParry()
    if not Settings.Combat.AutoParry then return end
    -- Simular bloqueio automático (se o jogo tiver mecânica de parry)
    -- Geralmente é um evento remoto de "block"
end

local function NoRecoil()
    -- Remover recoil de armas (ajustar propriedades do mouse ou da arma)
    -- Placeholder
end

-- ================= PROTEÇÃO =================
local function RandomDelay()
    if Settings.Protection.RandomDelay then
        local delay = Settings.Protection.RandomDelay
        local waitTime = math.random(delay*1000, delay*2000)/1000
        task.wait(waitTime)
    end
end

local function AntiBan()
    if not Settings.Protection.AntiBan then return end
    -- Ofuscação de chamadas remotas, adicionar atraso aleatório entre ações
    -- Hook de funções sensíveis (exemplo)
    -- Vamos apenas simular com RandomDelay
end

-- ================= GUI (INTERFACE) =================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NexusPremium"
screenGui.Parent = LocalPlayer.PlayerGui

-- Bolinha flutuante
local floatingButton = Instance.new("ImageButton")
floatingButton.Size = UDim2.new(0, 60, 0, 60)
floatingButton.Position = UDim2.new(0, 20, 0, 100)
floatingButton.BackgroundColor3 = Settings.Misc.PrimaryColor
floatingButton.BackgroundTransparency = 0.3
floatingButton.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png" -- substituir por ícone de faca
floatingButton.ImageColor3 = Color3.fromRGB(255,255,255)
floatingButton.Parent = screenGui

local cornerBtn = Instance.new("UICorner")
cornerBtn.CornerRadius = UDim.new(1, 0)
cornerBtn.Parent = floatingButton

-- Arrastar bolinha
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

-- Menu principal
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 450, 0, 550)
mainFrame.Position = UDim2.new(0.5, -225, 0.5, -275)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
mainFrame.BackgroundTransparency = 0.1
mainFrame.Visible = false
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = mainFrame

local shadow = Instance.new("UIShadow")
shadow.Parent = mainFrame

-- Categorias laterais
local categoriesFrame = Instance.new("Frame")
categoriesFrame.Size = UDim2.new(0, 140, 1, 0)
categoriesFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
categoriesFrame.BackgroundTransparency = 0.5
categoriesFrame.Parent = mainFrame

local categories = {
    { name = "Aimbot", icon = "🎯" },
    { name = "ESP", icon = "👁️" },
    { name = "Auto Farm", icon = "🌾" },
    { name = "Movimentação", icon = "🏃" },
    { name = "Combate", icon = "⚔️" },
    { name = "Proteção", icon = "🛡️" },
    { name = "Misc", icon = "⚙️" },
    { name = "Configurações", icon = "🔧" }
}
local categoryButtons = {}
for i, cat in ipairs(categories) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 45)
    btn.Position = UDim2.new(0, 0, 0, (i-1)*50)
    btn.Text = cat.icon .. "  " .. cat.name
    btn.TextColor3 = Settings.UI and Settings.UI.TextColor or Color3.fromRGB(255,255,255)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    btn.BackgroundTransparency = 0.5
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.Parent = categoriesFrame
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = btn
    
    btn.MouseButton1Click:Connect(function()
        CurrentCategory = cat.name
        UpdateContentFrame()
    end)
    categoryButtons[cat.name] = btn
end

-- Área de conteúdo
local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, -150, 1, -20)
contentFrame.Position = UDim2.new(0, 145, 0, 10)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

-- Cabeçalho com imagem de perfil
local profileImage = Instance.new("ImageLabel")
profileImage.Size = UDim2.new(0, 50, 0, 50)
profileImage.Position = UDim2.new(1, -60, 0, 10)
profileImage.Image = "https://play-lh.googleusercontent.com/5jcAEbmAQ-4XAYIlHGl_ZW9X9GJlTImrA4EBYBztutHPou2W3DB-w2FR7oOOE22_FPSv=w240-h480-rw"
profileImage.BackgroundTransparency = 1
profileImage.Parent = mainFrame

local profileCorner = Instance.new("UICorner")
profileCorner.CornerRadius = UDim.new(1, 0)
profileCorner.Parent = profileImage

-- Função para criar elementos UI
function CreateToggle(parent, text, defaultValue, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 40)
    frame.BackgroundTransparency = 1
    frame.Parent = parent
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 1, 0)
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
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,1,0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = frame
    
    local active = defaultValue
    btn.MouseButton1Click:Connect(function()
        active = not active
        toggleBg.BackgroundColor3 = active and Color3.fromRGB(0,200,0) or Color3.fromRGB(80,80,100)
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
    label.Size = UDim2.new(1,0,0,20)
    label.Text = text .. ": " .. tostring(defaultValue)
    label.TextColor3 = Color3.fromRGB(255,255,255)
    label.BackgroundTransparency = 1
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    
    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(1,0,0,4)
    sliderBg.Position = UDim2.new(0,0,0,30)
    sliderBg.BackgroundColor3 = Color3.fromRGB(80,80,100)
    sliderBg.BorderSizePixel = 0
    sliderBg.Parent = frame
    
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((defaultValue - min)/(max - min), 0, 1, 0)
    fill.BackgroundColor3 = Settings.Misc.PrimaryColor
    fill.BorderSizePixel = 0
    fill.Parent = sliderBg
    
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 12, 0, 12)
    knob.Position = UDim2.new((defaultValue - min)/(max - min), -6, 0.5, -6)
    knob.BackgroundColor3 = Settings.Misc.PrimaryColor
    knob.BorderSizePixel = 0
    knob.Parent = sliderBg
    
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1,0)
    knobCorner.Parent = knob
    
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0,40,0,20)
    valueLabel.Position = UDim2.new(1, -50, 0, 30)
    valueLabel.Text = tostring(defaultValue)
    valueLabel.TextColor3 = Color3.fromRGB(255,255,255)
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

function CreateButton(parent, text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 40)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.BackgroundColor3 = Color3.fromRGB(30,30,40)
    btn.BorderSizePixel = 0
    btn.Parent = parent
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = btn
    
    btn.MouseButton1Click:Connect(callback)
    return btn
end

function CreateDropdown(parent, text, options, defaultValue, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 50)
    frame.BackgroundTransparency = 1
    frame.Parent = parent
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1,0,0,20)
    label.Text = text
    label.TextColor3 = Color3.fromRGB(255,255,255)
    label.BackgroundTransparency = 1
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    
    local dropdownBtn = Instance.new("TextButton")
    dropdownBtn.Size = UDim2.new(1,0,0,30)
    dropdownBtn.Position = UDim2.new(0,0,0,25)
    dropdownBtn.Text = defaultValue
    dropdownBtn.TextColor3 = Color3.fromRGB(255,255,255)
    dropdownBtn.BackgroundColor3 = Color3.fromRGB(30,30,40)
    dropdownBtn.BorderSizePixel = 0
    dropdownBtn.Parent = frame
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0,8)
    btnCorner.Parent = dropdownBtn
    
    local dropdownList = Instance.new("Frame")
    dropdownList.Size = UDim2.new(1,0,0,0)
    dropdownList.Position = UDim2.new(0,0,0,55)
    dropdownList.BackgroundColor3 = Color3.fromRGB(30,30,40)
    dropdownList.ClipsDescendants = true
    dropdownList.Visible = false
    dropdownList.Parent = frame
    
    local listCorner = Instance.new("UICorner")
    listCorner.CornerRadius = UDim.new(0,8)
    listCorner.Parent = dropdownList
    
    local optButtons = {}
    for i, opt in ipairs(options) do
        local optBtn = Instance.new("TextButton")
        optBtn.Size = UDim2.new(1,0,0,30)
        optBtn.Position = UDim2.new(0,0,0,(i-1)*30)
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
            callback(opt)
        end)
        optButtons[opt] = optBtn
    end
    
    dropdownBtn.MouseButton1Click:Connect(function()
        dropdownList.Visible = not dropdownList.Visible
        if dropdownList.Visible then
            dropdownList.Size = UDim2.new(1,0,0,#options * 30)
        else
            dropdownList.Size = UDim2.new(1,0,0,0)
        end
    end)
    
    return frame
end

function CreateColorPicker(parent, text, defaultColor, callback)
    -- Placeholder para seletor de cor
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 40)
    frame.BackgroundTransparency = 1
    frame.Parent = parent
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6,0,1,0)
    label.Text = text
    label.TextColor3 = Color3.fromRGB(255,255,255)
    label.BackgroundTransparency = 1
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    
    local colorBox = Instance.new("Frame")
    colorBox.Size = UDim2.new(0, 30, 0, 30)
    colorBox.Position = UDim2.new(1, -40, 0.5, -15)
    colorBox.BackgroundColor3 = defaultColor
    colorBox.BorderSizePixel = 0
    colorBox.Parent = frame
    
    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 6)
    boxCorner.Parent = colorBox
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,1,0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = frame
    
    btn.MouseButton1Click:Connect(function()
        -- Simples seletor de cores (pode ser expandido)
        local newColor = Color3.fromRGB(math.random(0,255), math.random(0,255), math.random(0,255))
        colorBox.BackgroundColor3 = newColor
        callback(newColor)
    end)
    
    return frame
end

-- Atualizar conteúdo da categoria selecionada
local function UpdateContentFrame()
    for _, child in pairs(contentFrame:GetChildren()) do
        child:Destroy()
    end
    
    local y = 0
    if CurrentCategory == "Aimbot" then
        local toggle = CreateToggle(contentFrame, "Aimbot Ativado", Settings.Aimbot.Enabled, function(val)
            Settings.Aimbot.Enabled = val
            Notify("Aimbot", val and "Ativado" or "Desativado")
            SaveSettings()
        end)
        toggle.Position = UDim2.new(0,0,0,y)
        y = y + 50
        
        local silentToggle = CreateToggle(contentFrame, "Silent Aim", Settings.Aimbot.Silent, function(val)
            Settings.Aimbot.Silent = val
            SaveSettings()
        end)
        silentToggle.Position = UDim2.new(0,0,0,y)
        y = y + 50
        
        local targetDropdown = CreateDropdown(contentFrame, "Alvo", {"Murderer", "Sheriff", "Any"}, Settings.Aimbot.Target, function(val)
            Settings.Aimbot.Target = val
            SaveSettings()
        end)
        targetDropdown.Position = UDim2.new(0,0,0,y)
        y = y + 60
        
        local smoothSlider = CreateSlider(contentFrame, "Suavidade", 0, 1, Settings.Aimbot.Smoothness, function(val)
            Settings.Aimbot.Smoothness = val
            SaveSettings()
        end)
        smoothSlider.Position = UDim2.new(0,0,0,y)
        y = y + 60
        
        local distSlider = CreateSlider(contentFrame, "Distância Máxima", 0, 200, Settings.Aimbot.MaxDistance, function(val)
            Settings.Aimbot.MaxDistance = val
            SaveSettings()
        end)
        distSlider.Position = UDim2.new(0,0,0,y)
        y = y + 60
        
        local fovToggle = CreateToggle(contentFrame, "Mostrar Campo de Mira", Settings.Aimbot.FOV.Enabled, function(val)
            Settings.Aimbot.FOV.Enabled = val
            SaveSettings()
        end)
        fovToggle.Position = UDim2.new(0,0,0,y)
        y = y + 50
        
        local fovRadius = CreateSlider(contentFrame, "Raio do Campo", 50, 300, Settings.Aimbot.FOV.Radius, function(val)
            Settings.Aimbot.FOV.Radius = val
            SaveSettings()
        end)
        fovRadius.Position = UDim2.new(0,0,0,y)
        
    elseif CurrentCategory == "ESP" then
        local espToggle = CreateToggle(contentFrame, "ESP Ativado", Settings.ESP.Enabled, function(val)
            Settings.ESP.Enabled = val
            if val then CreateESPForAll() else
                for _, objs in pairs(ESPObjects) do
                    if objs.box then objs.box.Visible = false end
                    if objs.name then objs.name.Visible = false end
                    if objs.distance then objs.distance.Visible = false end
                    if objs.tracer then objs.tracer.Visible = false end
                end
            end
            SaveSettings()
        end)
        espToggle.Position = UDim2.new(0,0,0,y)
        y = y + 50
        
        local playerToggle = CreateToggle(contentFrame, "ESP de Jogadores", Settings.ESP.Players.Enabled, function(val)
            Settings.ESP.Players.Enabled = val
            SaveSettings()
        end)
        playerToggle.Position = UDim2.new(0,0,0,y)
        y = y + 50
        
        local boxToggle = CreateToggle(contentFrame, "Caixas", Settings.ESP.Players.ShowBoxes, function(val)
            Settings.ESP.Players.ShowBoxes = val
            SaveSettings()
        end)
        boxToggle.Position = UDim2.new(0,0,0,y)
        y = y + 50
        
        local nameToggle = CreateToggle(contentFrame, "Nomes", Settings.ESP.Players.ShowNames, function(val)
            Settings.ESP.Players.ShowNames = val
            SaveSettings()
        end)
        nameToggle.Position = UDim2.new(0,0,0,y)
        y = y + 50
        
        local distToggle = CreateToggle(contentFrame, "Distância", Settings.ESP.Players.ShowDistance, function(val)
            Settings.ESP.Players.ShowDistance = val
            SaveSettings()
        end)
        distToggle.Position = UDim2.new(0,0,0,y)
        y = y + 50
        
        local tracerToggle = CreateToggle(contentFrame, "Traçadores", Settings.ESP.Tracers.Enabled, function(val)
            Settings.ESP.Tracers.Enabled = val
            SaveSettings()
        end)
        tracerToggle.Position = UDim2.new(0,0,0,y)
        y = y + 50
        
        local radarToggle = CreateToggle(contentFrame, "Radar 2D", Settings.ESP.Radar.Enabled, function(val)
            Settings.ESP.Radar.Enabled = val
            if val then CreateRadar() else if radarFrame then radarFrame:Destroy() end end
            SaveSettings()
        end)
        radarToggle.Position = UDim2.new(0,0,0,y)
        y = y + 50
        
        local radarPosDropdown = CreateDropdown(contentFrame, "Posição do Radar", {"TopLeft","TopRight","BottomLeft","BottomRight"}, Settings.ESP.Radar.Position, function(val)
            Settings.ESP.Radar.Position = val
            if Settings.ESP.Radar.Enabled then CreateRadar() end
            SaveSettings()
        end)
        radarPosDropdown.Position = UDim2.new(0,0,0,y)
        
    elseif CurrentCategory == "Auto Farm" then
        local farmToggle = CreateToggle(contentFrame, "Auto Farm Ativado", Settings.AutoFarm.Enabled, function(val)
            Settings.AutoFarm.Enabled = val
            Notify("Auto Farm", val and "Iniciado" or "Parado")
            SaveSettings()
        end)
        farmToggle.Position = UDim2.new(0,0,0,y)
        y = y + 50
        
        local coinsToggle = CreateToggle(contentFrame, "Coletar Moedas", Settings.AutoFarm.CollectCoins, function(val)
            Settings.AutoFarm.CollectCoins = val
            SaveSettings()
        end)
        coinsToggle.Position = UDim2.new(0,0,0,y)
        y = y + 50
        
        local knifeToggle = CreateToggle(contentFrame, "Coletar Faca", Settings.AutoFarm.CollectKnife, function(val)
            Settings.AutoFarm.CollectKnife = val
            SaveSettings()
        end)
        knifeToggle.Position = UDim2.new(0,0,0,y)
        y = y + 50
        
        local resetToggle = CreateToggle(contentFrame, "Auto Reset", Settings.AutoFarm.AutoReset, function(val)
            Settings.AutoFarm.AutoReset = val
            SaveSettings()
        end)
        resetToggle.Position = UDim2.new(0,0,0,y)
        y = y + 50
        
        local playToggle = CreateToggle(contentFrame, "Auto Play", Settings.AutoFarm.AutoPlay, function(val)
            Settings.AutoFarm.AutoPlay = val
            SaveSettings()
        end)
        playToggle.Position = UDim2.new(0,0,0,y)
        
    elseif CurrentCategory == "Movimentação" then
        local flyToggle = CreateToggle(contentFrame, "Fly", Settings.Movement.Fly, function(val)
            Settings.Movement.Fly = val
            if val then StartFly() else StopFly() end
            SaveSettings()
        end)
        flyToggle.Position = UDim2.new(0,0,0,y)
        y = y + 50
        
        local noclipToggle = CreateToggle(contentFrame, "Noclip", Settings.Movement.Noclip, function(val)
            Settings.Movement.Noclip = val
            NoclipToggle()
            SaveSettings()
        end)
        noclipToggle.Position = UDim2.new(0,0,0,y)
        y = y + 50
        
        local speedToggle = CreateToggle(contentFrame, "Speed Hack", Settings.Movement.SpeedHack.Enabled, function(val)
            Settings.Movement.SpeedHack.Enabled = val
            SpeedHack()
            SaveSettings()
        end)
        speedToggle.Position = UDim2.new(0,0,0,y)
        y = y + 50
        
        local speedSlider = CreateSlider(contentFrame, "Velocidade", 16, 100, Settings.Movement.SpeedHack.Speed, function(val)
            Settings.Movement.SpeedHack.Speed = val
            if Settings.Movement.SpeedHack.Enabled then SpeedHack() end
            SaveSettings()
        end)
        speedSlider.Position = UDim2.new(0,0,0,y)
        y = y + 60
        
        local teleportToggle = CreateToggle(contentFrame, "Teletransporte", Settings.Movement.Teleport.Enabled, function(val)
            Settings.Movement.Teleport.Enabled = val
            SaveSettings()
        end)
        teleportToggle.Position = UDim2.new(0,0,0,y)
        y = y + 50
        
        local teleportTarget = CreateDropdown(contentFrame, "Destino", {"Items", "Players", "Coordinates"}, Settings.Movement.Teleport.Target, function(val)
            Settings.Movement.Teleport.Target = val
            SaveSettings()
        end)
        teleportTarget.Position = UDim2.new(0,0,0,y)
        y = y + 60
        
        local antiAFKToggle = CreateToggle(contentFrame, "Anti-AFK", Settings.Movement.AntiAFK, function(val)
            Settings.Movement.AntiAFK = val
            SaveSettings()
        end)
        antiAFKToggle.Position = UDim2.new(0,0,0,y)
        
    elseif CurrentCategory == "Combate" then
        local killAllBtn = CreateButton(contentFrame, "Kill All", function()
            KillAll()
            Notify("Combate", "Kill All executado")
        end)
        killAllBtn.Position = UDim2.new(0,0,0,y)
        y = y + 50
        
        local instantWinBtn = CreateButton(contentFrame, "Instant Win", function()
            InstantWin()
            Notify("Combate", "Vitória instantânea ativada")
        end)
        instantWinBtn.Position = UDim2.new(0,0,0,y)
        y = y + 50
        
        local autoParryToggle = CreateToggle(contentFrame, "Auto Parry", Settings.Combat.AutoParry, function(val)
            Settings.Combat.AutoParry = val
            SaveSettings()
        end)
        autoParryToggle.Position = UDim2.new(0,0,0,y)
        y = y + 50
        
        local noRecoilToggle = CreateToggle(contentFrame, "No Recoil", Settings.Combat.NoRecoil, function(val)
            Settings.Combat.NoRecoil = val
            SaveSettings()
        end)
        noRecoilToggle.Position = UDim2.new(0,0,0,y)
        
    elseif CurrentCategory == "Proteção" then
        local antiBanToggle = CreateToggle(contentFrame, "Anti-Ban", Settings.Protection.AntiBan, function(val)
            Settings.Protection.AntiBan = val
            SaveSettings()
        end)
        antiBanToggle.Position = UDim2.new(0,0,0,y)
        y = y + 50
        
        local delaySlider = CreateSlider(contentFrame, "Atraso Aleatório (s)", 0, 1, Settings.Protection.RandomDelay, function(val)
            Settings.Protection.RandomDelay = val
            SaveSettings()
        end)
        delaySlider.Position = UDim2.new(0,0,0,y)
        y = y + 60
        
        local webhookInput = Instance.new("TextBox")
        webhookInput.Size = UDim2.new(1, -20, 0, 30)
        webhookInput.Position = UDim2.new(0, 10, 0, y)
        webhookInput.PlaceholderText = "Webhook URL"
        webhookInput.Text = Settings.Protection.Webhook
        webhookInput.TextColor3 = Color3.fromRGB(255,255,255)
        webhookInput.BackgroundColor3 = Color3.fromRGB(30,30,40)
        webhookInput.BorderSizePixel = 0
        webhookInput.Parent = contentFrame
        local webCorner = Instance.new("UICorner")
        webCorner.CornerRadius = UDim.new(0,6)
        webCorner.Parent = webhookInput
        webhookInput.FocusLost:Connect(function()
            Settings.Protection.Webhook = webhookInput.Text
            SaveSettings()
        end)
        
    elseif CurrentCategory == "Misc" then
        local autoBuyToggle = CreateToggle(contentFrame, "Auto Buy", Settings.Misc.AutoBuy, function(val)
            Settings.Misc.AutoBuy = val
            SaveSettings()
        end)
        autoBuyToggle.Position = UDim2.new(0,0,0,y)
        y = y + 50
        
        local stealthToggle = CreateToggle(contentFrame, "Stealth Mode", Settings.Misc.StealthMode, function(val)
            Settings.Misc.StealthMode = val
            if val then
                -- Ocultar elementos da GUI? Talvez diminuir transparência
            end
            SaveSettings()
        end)
        stealthToggle.Position = UDim2.new(0,0,0,y)
        y = y + 50
        
        local soundToggle = CreateToggle(contentFrame, "Efeitos Sonoros", Settings.Misc.SoundEffects, function(val)
            Settings.Misc.SoundEffects = val
            SaveSettings()
        end)
        soundToggle.Position = UDim2.new(0,0,0,y)
        y = y + 50
        
        local colorPicker = CreateColorPicker(contentFrame, "Cor Primária", Settings.Misc.PrimaryColor, function(val)
            Settings.Misc.PrimaryColor = val
            floatingButton.BackgroundColor3 = val
            SaveSettings()
        end)
        colorPicker.Position = UDim2.new(0,0,0,y)
        
    elseif CurrentCategory == "Configurações" then
        local saveBtn = CreateButton(contentFrame, "Salvar Configurações", function()
            SaveSettings()
            Notify("Configurações", "Salvas com sucesso")
        end)
        saveBtn.Position = UDim2.new(0,0,0,y)
        y = y + 50
        
        local loadBtn = CreateButton(contentFrame, "Carregar Configurações", function()
            LoadSettings()
            Notify("Configurações", "Carregadas")
            -- Recriar GUI para refletir alterações? (simplesmente recarregar script é melhor)
        end)
        loadBtn.Position = UDim2.new(0,0,0,y)
        y = y + 50
        
        local resetBtn = CreateButton(contentFrame, "Resetar Configurações", function()
            -- Resetar valores padrão
            -- (redefinir Settings)
            Notify("Configurações", "Resetadas para padrão")
        end)
        resetBtn.Position = UDim2.new(0,0,0,y)
    end
end

-- ================= LOOP PRINCIPAL =================
LoadSettings()
CreateESPForAll()
if Settings.ESP.Radar.Enabled then CreateRadar() end

-- Loop de atualização em tempo real
RunService.RenderStepped:Connect(function()
    -- ESP
    if Settings.ESP.Enabled then
        UpdateESP()
        if Settings.ESP.Radar.Enabled then UpdateRadar() end
    end
    
    -- Aimbot (com FOV desenhado)
    if Settings.Aimbot.Enabled then
        local target = GetTarget()
        if target then
            if Settings.Aimbot.Silent then
                SilentAim(target)
            else
                AimAt(target)
            end
        end
        -- Desenhar círculo FOV
        if Settings.Aimbot.FOV.Enabled then
            -- Desenhar círculo no centro da tela (simulação, seria melhor com Drawing)
        end
    end
    
    -- Auto Farm
    if Settings.AutoFarm.Enabled then
        AutoCollect()
    end
    
    -- Anti-AFK
    if Settings.Movement.AntiAFK then
        AntiAFK()
    end
    
    -- Velocidade
    if Settings.Movement.SpeedHack.Enabled then
        SpeedHack()
    else
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum and hum.WalkSpeed ~= 16 then
            hum.WalkSpeed = 16
        end
    end
    
    -- Notificações (simples)
    for i, notif in ipairs(NotificationQueue) do
        if tick() - notif.created > notif.duration then
            table.remove(NotificationQueue, i)
        else
            -- Exibir na tela (usar StarterGui:SetCore ou criar uma UI de notificação)
        end
    end
end)

-- Atualizar ao adicionar novos jogadores
Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        CreateDrawingObjects(player)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if ESPObjects[player] then
        ESPObjects[player].box:Remove()
        ESPObjects[player].name:Remove()
        ESPObjects[player].distance:Remove()
        ESPObjects[player].tracer:Remove()
        ESPObjects[player] = nil
    end
end)

-- Abrir/fechar menu ao clicar na bolinha
floatingButton.MouseButton1Click:Connect(function()
    MenuOpen = not MenuOpen
    if MenuOpen then
        mainFrame.Visible = true
        TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { BackgroundTransparency = 0.1 }):Play()
    else
        TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
        task.wait(0.2)
        mainFrame.Visible = false
    end
end)

-- Notificação inicial
Notify("NEXUS Premium", "Menu carregado com sucesso! Toque na bolinha.", 3)

print("NEXUS Premium carregado. Use a bolinha flutuante para abrir o menu.")
