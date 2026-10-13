--[[
    =======================================================
    CUSTOM FE UTILITY GUI (MOBILE FRIENDLY - STANDARD INPUT)
    Style: True Black Minimalist / AMOLED Clean UX
    Features: Move, Waypoint (Pathfinding, Forced TPWalk, Loop TP 0.2s),
              Player (Live Search & Safe TP), Visual (Dynamic Fullbright,
              NoFog, Custom MaxZoom), Util (Anti Gameplay Pause, Instant Prompts).
              Data Storage: Folder 'FEUtilityData/'
    =======================================================
--]]

-- 1. ANTI-DOUBLE SCRIPT EXECUTION & CLEANUP PREPARATION
if _G.FEUtilityCleanup then
    _G.FEUtilityCleanup()
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local PathfindingService = game:GetService("PathfindingService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- SYSTEM FOLDER SETUP
local FolderName = "FEUtilityData"
if makefolder and isfolder and not isfolder(FolderName) then
    pcall(function() makefolder(FolderName) end)
end

local WaypointFileName = FolderName .. "/Waypoints_" .. tostring(game.PlaceId) .. ".json"
local ConfigFileName = FolderName .. "/Config_" .. tostring(game.PlaceId) .. ".json"

-- Global Storage
local Connections = {}
local ESPLabels = {}
local FullbrightConns = {}
local NoFogConns = {}
local InstantPromptConn = nil
local ControlModule = nil

local currentChar = LocalPlayer.Character
local currentHum = currentChar and currentChar:FindFirstChildOfClass("Humanoid")

-- Server Base Data & Flags
local BaseWalkSpeed = currentHum and currentHum.WalkSpeed or 16
local BaseJumpPower = currentHum and (currentHum.UseJumpPower and currentHum.JumpPower or 50) or 50
local BaseGravity = workspace.Gravity
local BaseHipHeight = currentHum and currentHum.HipHeight or 0

local WalkSpeedVal = BaseWalkSpeed
local TPWalkVal = 1
local JumpPowerVal = BaseJumpPower
local HipHeightVal = BaseHipHeight
local GravityVal = BaseGravity
local FlySpeedVal = 50
local VehicleSpeedVal = 100
local TweenSpeedVal = 100
local CustomMaxZoomVal = 128

-- Movement Flags
local WalkSpeedEnabled = false
local TPWalkEnabled = false
local WallTPEnabled = false
local WallTPConn = nil
local FlyEnabled = false
local InfJumpEnabled = false
local NoclipEnabled = false
local AirwalkEnabled = false
local NoclipVehicleEnabled = false

-- Visual Flags
local ChamsEnabled = false
local DistanceESPEnabled = false
local FullbrightEnabled = false
local NoFogEnabled = false
local NoclipCamEnabled = false
local FreecamEnabled = false

-- Utility Flags
local AntiAFKEnabled = true
local InstantPromptEnabled = false
local AntiGameplayPauseEnabled = true -- Default ON
local AntiAnchoredEnabled = false
local HeadsitEnabled = false
local SpectateEnabled = false

local SelectedPlayer = nil
local CurrentTweenObj = nil
local AirwalkPart = nil
local AirwalkY = nil
local FreecamCamType = Camera.CameraType

local Waypoints = {}
local ActiveWalkToThread = nil
local ActiveWalkToName = nil
local ActiveWalkToMode = nil
local ActiveLoopTPThread = nil
local ActiveLoopTPName = nil

local FlyVelocityName = "FEFlyVelocity"
local FlyGyroName = "FEFlyGyro"

local DefaultLighting = {
    Brightness = game.Lighting.Brightness,
    FogEnd = game.Lighting.FogEnd,
    GlobalShadows = game.Lighting.GlobalShadows,
    Ambient = game.Lighting.Ambient,
    OutdoorAmbient = game.Lighting.OutdoorAmbient
}

-- Default Anti-Gameplay Pause
pcall(function() GuiService:SetGameplayPausedNotificationEnabled(false) end)

-- HELPER FORMAT 2 DESIMAL (XX.XX)
local function fmt2(val)
    return string.format("%.2f", tonumber(val) or 0)
end

-- SAFE HYBRID MOVE INPUT CALCULATOR
local function getMoveInput(hum)
    local moveVector = Vector3.zero
    if not ControlModule then
        pcall(function()
            local ps = LocalPlayer:FindFirstChild("PlayerScripts")
            local pm = ps and ps:FindFirstChild("PlayerModule")
            local cm = pm and pm:FindFirstChild("ControlModule")
            if cm then ControlModule = require(cm) end
        end)
    end

    if ControlModule and ControlModule.GetMoveVector then
        pcall(function() moveVector = ControlModule:GetMoveVector() end)
    end

    if moveVector.Magnitude == 0 and hum and hum.MoveDirection.Magnitude > 0 then
        local camCF = Camera.CFrame
        local flatLook = (camCF.LookVector * Vector3.new(1, 0, 1)).Unit
        local flatRight = (camCF.RightVector * Vector3.new(1, 0, 1)).Unit
        local forwardDot = hum.MoveDirection:Dot(flatLook)
        local rightDot = hum.MoveDirection:Dot(flatRight)
        moveVector = Vector3.new(rightDot, 0, -forwardDot)
    end
    return moveVector
end

-- MULTI-LAYERED TEAM DETECTION
local function isTeammate(targetPlayer)
    if not targetPlayer or targetPlayer == LocalPlayer then return true end
    if LocalPlayer.Team and targetPlayer.Team and LocalPlayer.Team == targetPlayer.Team then return true end
    if LocalPlayer.TeamColor and targetPlayer.TeamColor and LocalPlayer.TeamColor == targetPlayer.TeamColor then return true end

    local lpTeamAttr = LocalPlayer:GetAttribute("Team") or (LocalPlayer.Character and LocalPlayer.Character:GetAttribute("Team"))
    local tpTeamAttr = targetPlayer:GetAttribute("Team") or (targetPlayer.Character and targetPlayer.Character:GetAttribute("Team"))
    if lpTeamAttr and tpTeamAttr and lpTeamAttr == tpTeamAttr then return true end

    local lpLs = LocalPlayer:FindFirstChild("leaderstats") and (LocalPlayer.leaderstats:FindFirstChild("Team") or LocalPlayer.leaderstats:FindFirstChild("Faction"))
    local tpLs = targetPlayer:FindFirstChild("leaderstats") and (targetPlayer.leaderstats:FindFirstChild("Team") or targetPlayer.leaderstats:FindFirstChild("Faction"))
    if lpLs and tpLs and lpLs.Value == tpLs.Value then return true end

    return false
end

-- 2. GUI BASE CREATION (TRUE BLACK AMOLED TONE)
local TargetGuiParent = (gethui and gethui()) or game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FEUtilityMobileGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = TargetGuiParent

local function addCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 6)
    corner.Parent = parent
end

local function addStroke(parent, color, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Color3.fromRGB(30, 30, 40)
    stroke.Thickness = thickness or 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = parent
    return stroke
end

-- Floating Toggle Button
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "FloatingToggle"
ToggleBtn.Size = UDim2.new(0, 46, 0, 46)
ToggleBtn.Position = UDim2.new(0.05, 0, 0.2, 0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
ToggleBtn.TextColor3 = Color3.fromRGB(0, 229, 255)
ToggleBtn.Text = "FE"
ToggleBtn.Font = Enum.Font.SourceSansBold
ToggleBtn.TextSize = 16
ToggleBtn.Active = true
ToggleBtn.Draggable = true
ToggleBtn.Parent = ScreenGui
addCorner(ToggleBtn, 23)
addStroke(ToggleBtn, Color3.fromRGB(0, 229, 255), 1.5)

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 360, 0, 290)
MainFrame.Position = UDim2.new(0.5, -180, 0.5, -145)
MainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Visible = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui
addCorner(MainFrame, 8)
addStroke(MainFrame, Color3.fromRGB(30, 30, 42), 1)

-- Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 32)
Header.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -40, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "FE UTILITY <font color=\"#00e5ff\">MOBILE</font>"
Title.RichText = true
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 1, 0)
CloseBtn.Position = UDim2.new(1, -30, 0, 0)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 75, 75)
CloseBtn.Font = Enum.Font.SourceSansBold
CloseBtn.TextSize = 14
CloseBtn.Parent = Header

-- RESIZE HANDLE
local ResizeGrip = Instance.new("TextButton")
ResizeGrip.Name = "ResizeGrip"
ResizeGrip.Size = UDim2.new(0, 16, 0, 16)
ResizeGrip.Position = UDim2.new(1, -16, 1, -16)
ResizeGrip.BackgroundTransparency = 1
ResizeGrip.Text = "◢"
ResizeGrip.TextColor3 = Color3.fromRGB(0, 229, 255)
ResizeGrip.Font = Enum.Font.SourceSansBold
ResizeGrip.TextSize = 12
ResizeGrip.ZIndex = 10
ResizeGrip.Parent = MainFrame

local isResizing = false
local startPos, startSize

ResizeGrip.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isResizing = true
        startPos = input.Position
        startSize = MainFrame.Size
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if isResizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - startPos
        local newX = math.clamp(startSize.X.Offset + delta.X, 290, 600)
        local newY = math.clamp(startSize.Y.Offset + delta.Y, 220, 480)
        MainFrame.Size = UDim2.new(0, newX, 0, newY)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isResizing = false
    end
end)

-- Tab Bar
local TabScroll = Instance.new("ScrollingFrame")
TabScroll.Size = UDim2.new(1, -10, 0, 26)
TabScroll.Position = UDim2.new(0, 5, 0, 36)
TabScroll.BackgroundTransparency = 1
TabScroll.ScrollBarThickness = 0
TabScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
TabScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
TabScroll.Parent = MainFrame

local TabListLayout = Instance.new("UIListLayout")
TabListLayout.FillDirection = Enum.FillDirection.Horizontal
TabListLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabListLayout.Padding = UDim.new(0, 4)
TabListLayout.Parent = TabScroll

local ContentContainer = Instance.new("Frame")
ContentContainer.Size = UDim2.new(1, -10, 1, -72)
ContentContainer.Position = UDim2.new(0, 5, 0, 66)
ContentContainer.BackgroundTransparency = 1
ContentContainer.Parent = MainFrame

local Tabs = {}
local TabButtons = {}

local function createTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 64, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(150, 150, 160)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 11
    btn.Parent = TabScroll
    addCorner(btn, 4)
    addStroke(btn, Color3.fromRGB(22, 22, 30), 1)

    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, 0, 1, 0)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 3
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 229, 255)
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.Visible = false
    scrollFrame.Parent = ContentContainer

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 5)
    layout.Parent = scrollFrame

    Tabs[name] = scrollFrame
    TabButtons[name] = btn

    btn.MouseButton1Click:Connect(function()
        for tName, tFrame in pairs(Tabs) do
            local isTarget = (tName == name)
            tFrame.Visible = isTarget
            TabButtons[tName].BackgroundColor3 = isTarget and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(10, 10, 14)
            TabButtons[tName].TextColor3 = isTarget and Color3.fromRGB(0, 229, 255) or Color3.fromRGB(150, 150, 160)
        end
    end)

    return scrollFrame
end

local MoveTab = createTab("Move")
local WPTab = createTab("Waypoint")
local PlayerTab = createTab("Player")
local VisualTab = createTab("Visual")
local UtilTab = createTab("Util")

Tabs["Move"].Visible = true
TabButtons["Move"].BackgroundColor3 = Color3.fromRGB(0, 0, 0)
TabButtons["Move"].TextColor3 = Color3.fromRGB(0, 229, 255)

-- 3. UI CONTROLS HELPERS (STANDARD INPUT WITH NUMERIC FILTER)
local function addInputRow(parent, labelText, defaultValue, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -5, 0, 28)
    frame.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
    frame.Parent = parent
    addCorner(frame, 4)
    addStroke(frame, Color3.fromRGB(22, 22, 30), 1)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.5, -5, 1, 0)
    lbl.Position = UDim2.new(0, 6, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = Color3.fromRGB(200, 200, 210)
    lbl.Font = Enum.Font.SourceSans
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.24, 0, 0.75, 0)
    box.Position = UDim2.new(0.52, 0, 0.12, 0)
    box.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    box.Text = fmt2(defaultValue)
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.Font = Enum.Font.SourceSans
    box.TextSize = 11
    box.Parent = frame
    addCorner(box, 3)

    box:GetPropertyChangedSignal("Text"):Connect(function()
        box.Text = string.gsub(box.Text, "[^%d%.]", "")
    end)

    local applyBtn = Instance.new("TextButton")
    applyBtn.Size = UDim2.new(0.2, -6, 0.75, 0)
    applyBtn.Position = UDim2.new(0.78, 0, 0.12, 0)
    applyBtn.BackgroundColor3 = Color3.fromRGB(16, 16, 24)
    applyBtn.Text = "Set"
    applyBtn.TextColor3 = Color3.fromRGB(0, 229, 255)
    applyBtn.Font = Enum.Font.SourceSansBold
    applyBtn.TextSize = 11
    applyBtn.Parent = frame
    addCorner(applyBtn, 3)

    applyBtn.MouseButton1Click:Connect(function()
        local num = tonumber(box.Text)
        if num then callback(num) end
    end)

    return frame, box
end

local function addToggle(parent, labelText, defaultState, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -5, 0, 28)
    btn.BackgroundColor3 = defaultState and Color3.fromRGB(8, 30, 20) or Color3.fromRGB(8, 8, 12)
    btn.Text = "  " .. labelText
    btn.TextColor3 = defaultState and Color3.fromRGB(0, 229, 255) or Color3.fromRGB(180, 180, 190)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 11
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = parent
    addCorner(btn, 4)
    addStroke(btn, Color3.fromRGB(22, 22, 30), 1)

    local badge = Instance.new("TextLabel")
    badge.Size = UDim2.new(0, 36, 0, 18)
    badge.Position = UDim2.new(1, -42, 0.5, -9)
    badge.BackgroundColor3 = defaultState and Color3.fromRGB(0, 229, 255) or Color3.fromRGB(20, 20, 28)
    badge.Text = defaultState and "ON" or "OFF"
    badge.TextColor3 = defaultState and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(140, 140, 150)
    badge.Font = Enum.Font.SourceSansBold
    badge.TextSize = 10
    badge.Parent = btn
    addCorner(badge, 3)

    local state = defaultState
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.BackgroundColor3 = state and Color3.fromRGB(8, 30, 20) or Color3.fromRGB(8, 8, 12)
        btn.TextColor3 = state and Color3.fromRGB(0, 229, 255) or Color3.fromRGB(180, 180, 190)
        badge.BackgroundColor3 = state and Color3.fromRGB(0, 229, 255) or Color3.fromRGB(20, 20, 28)
        badge.Text = state and "ON" or "OFF"
        badge.TextColor3 = state and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(140, 140, 150)
        callback(state)
    end)
    return btn
end

local function addActionButton(parent, labelText, color, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -5, 0, 28)
    btn.BackgroundColor3 = color or Color3.fromRGB(12, 12, 18)
    btn.Text = labelText
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 11
    btn.Parent = parent
    addCorner(btn, 4)
    addStroke(btn, Color3.fromRGB(25, 25, 35), 1)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

-- 4. TAB 1: MOVEMENT & SERVER DATA FETCH
local ServerInfoLbl = Instance.new("TextLabel")
ServerInfoLbl.Size = UDim2.new(1, -5, 0, 22)
ServerInfoLbl.BackgroundTransparency = 1
ServerInfoLbl.Text = string.format("Base WS: %s | JP: %s | HH: %s | Grav: %s", fmt2(BaseWalkSpeed), fmt2(BaseJumpPower), fmt2(BaseHipHeight), fmt2(BaseGravity))
ServerInfoLbl.TextColor3 = Color3.fromRGB(0, 229, 255)
ServerInfoLbl.Font = Enum.Font.SourceSansBold
ServerInfoLbl.TextSize = 10
ServerInfoLbl.Parent = MoveTab

local function updateServerInfo()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        if not WalkSpeedEnabled then BaseWalkSpeed = hum.WalkSpeed end
        if hum.UseJumpPower then BaseJumpPower = hum.JumpPower end
        BaseHipHeight = hum.HipHeight
    end
    BaseGravity = workspace.Gravity
    ServerInfoLbl.Text = string.format("Base WS: %s | JP: %s | HH: %s | Grav: %s", fmt2(BaseWalkSpeed), fmt2(BaseJumpPower), fmt2(BaseHipHeight), fmt2(BaseGravity))
end

addActionButton(MoveTab, "Fetch / Reset Game Default", Color3.fromRGB(15, 30, 45), function()
    updateServerInfo()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        hum.WalkSpeed = BaseWalkSpeed
        hum.JumpPower = BaseJumpPower
        hum.HipHeight = BaseHipHeight
    end
    workspace.Gravity = BaseGravity
end)

addInputRow(MoveTab, "WalkSpeed Value", WalkSpeedVal, function(v)
    WalkSpeedVal = v
    if not WalkSpeedEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = v
    end
end)

addToggle(MoveTab, "WalkSpeed Loop", false, function(state) WalkSpeedEnabled = state end)

addInputRow(MoveTab, "TPWalk Speed", TPWalkVal, function(v) TPWalkVal = v end)
addToggle(MoveTab, "TPWalk (TranslateBy)", false, function(state) TPWalkEnabled = state end)

local function enableWallTP()
    if WallTPConn then WallTPConn:Disconnect() WallTPConn = nil end
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    local root = char:FindFirstChild("HumanoidRootPart") or torso

    if torso and root and hum then
        WallTPConn = torso.Touched:Connect(function(hit)
            if WallTPEnabled and hit:IsA("BasePart") then
                local currentHum = char:FindFirstChildOfClass("Humanoid")
                local currentRoot = char:FindFirstChild("HumanoidRootPart") or torso
                if currentHum and currentRoot and hit.Position.Y > (currentRoot.Position.Y - currentHum.HipHeight) then
                    local hitP = hit.Parent and (hit.Parent:FindFirstChild("HumanoidRootPart") or hit.Parent:FindFirstChild("Torso") or hit.Parent:FindFirstChild("UpperTorso"))
                    if hitP then
                        currentRoot.CFrame = hit.CFrame * CFrame.new(currentRoot.CFrame.LookVector.X, hitP.Size.Z/2 + currentHum.HipHeight, currentRoot.CFrame.LookVector.Z)
                    else
                        currentRoot.CFrame = hit.CFrame * CFrame.new(currentRoot.CFrame.LookVector.X, hit.Size.Y/2 + currentHum.HipHeight, currentRoot.CFrame.LookVector.Z)
                    end
                end
            end
        end)
    end
end

local function disableWallTP()
    if WallTPConn then WallTPConn:Disconnect() WallTPConn = nil end
end

addToggle(MoveTab, "WallTP (Touch Auto-Climb)", false, function(state)
    WallTPEnabled = state
    if state then enableWallTP() else disableWallTP() end
end)

Connections.WallTPCharAdded = LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    updateServerInfo()
    if WallTPEnabled then enableWallTP() end
end)

addInputRow(MoveTab, "JumpPower", JumpPowerVal, function(v)
    JumpPowerVal = v
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        hum.UseJumpPower = true
        hum.JumpPower = v
    end
end)

addInputRow(MoveTab, "HipHeight", HipHeightVal, function(v)
    HipHeightVal = v
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid").HipHeight = v
    end
end)

addInputRow(MoveTab, "Gravity", GravityVal, function(v)
    GravityVal = v
    workspace.Gravity = v
end)

addInputRow(MoveTab, "Fly Speed", FlySpeedVal, function(v) FlySpeedVal = v end)
addInputRow(MoveTab, "Vehicle Speed Boost", VehicleSpeedVal, function(v) VehicleSpeedVal = v end)

local function startFly()
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end

    local oldV = root:FindFirstChild(FlyVelocityName)
    if oldV then oldV:Destroy() end
    local oldG = root:FindFirstChild(FlyGyroName)
    if oldG then oldG:Destroy() end

    local bv = Instance.new("BodyVelocity")
    bv.Name = FlyVelocityName
    bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bv.Velocity = Vector3.zero
    bv.Parent = root

    local bg = Instance.new("BodyGyro")
    bg.Name = FlyGyroName
    bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    bg.P = 1000
    bg.D = 50
    bg.CFrame = Camera.CFrame
    bg.Parent = root

    hum.PlatformStand = true
end

local function stopFly()
    local char = LocalPlayer.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
        if root then
            local bv = root:FindFirstChild(FlyVelocityName)
            if bv then bv:Destroy() end
            local bg = root:FindFirstChild(FlyGyroName)
            if bg then bg:Destroy() end
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false end
    end
end

addToggle(MoveTab, "Mobile Fly (ControlModule)", false, function(state)
    FlyEnabled = state
    if FlyEnabled then startFly() else stopFly() end
end)

addToggle(MoveTab, "Airwalk (Locked Y Floor)", false, function(state)
    AirwalkEnabled = state
    if not state then
        AirwalkY = nil
        if AirwalkPart then AirwalkPart:Destroy() AirwalkPart = nil end
    end
end)

addToggle(MoveTab, "Noclip Vehicle", false, function(state) NoclipVehicleEnabled = state end)
addToggle(MoveTab, "Infinite Jump", false, function(state) InfJumpEnabled = state end)
addToggle(MoveTab, "Noclip", false, function(state) NoclipEnabled = state end)

-- Movement Loops
Connections.FlyLoop = RunService.RenderStepped:Connect(function()
    if FlyEnabled then
        local char = LocalPlayer.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
            local hum = char:FindFirstChildOfClass("Humanoid")
            if root and hum then
                local bv = root:FindFirstChild(FlyVelocityName)
                local bg = root:FindFirstChild(FlyGyroName)
                if not bv or not bg then
                    startFly()
                    bv = root:FindFirstChild(FlyVelocityName)
                    bg = root:FindFirstChild(FlyGyroName)
                end

                if bv and bg then
                    hum.PlatformStand = true
                    bg.CFrame = Camera.CFrame
                    local moveVector = getMoveInput(hum)
                    local vel = Vector3.zero
                    if moveVector.X ~= 0 then vel = vel + Camera.CFrame.RightVector * (moveVector.X * FlySpeedVal * 2.5) end
                    if moveVector.Z ~= 0 then vel = vel - Camera.CFrame.LookVector * (moveVector.Z * FlySpeedVal * 2.5) end
                    bv.Velocity = vel
                end
            end
        end
    end
end)

Connections.TPWalkLoop = RunService.Heartbeat:Connect(function(delta)
    if TPWalkEnabled and LocalPlayer.Character and not ActiveWalkToName then
        local char = LocalPlayer.Character
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.MoveDirection.Magnitude > 0 then
            char:TranslateBy(hum.MoveDirection * TPWalkVal * delta * 10)
        end
    end
end)

Connections.WalkSpeedLoop = RunService.RenderStepped:Connect(function()
    if WalkSpeedEnabled and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = WalkSpeedVal end
    end
end)

Connections.VehicleBoostLoop = RunService.Heartbeat:Connect(function()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum.SeatPart and hum.SeatPart:IsA("VehicleSeat") then
            hum.SeatPart.MaxSpeed = VehicleSpeedVal
            if NoclipVehicleEnabled and hum.SeatPart.Parent then
                for _, part in pairs(hum.SeatPart.Parent:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
        end
    end
end)

Connections.AirwalkLoop = RunService.RenderStepped:Connect(function()
    if AirwalkEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = LocalPlayer.Character.HumanoidRootPart
        if not AirwalkY then
            AirwalkY = hrp.Position.Y - 3.5
        end
        if not AirwalkPart or not AirwalkPart.Parent then
            AirwalkPart = Instance.new("Part")
            AirwalkPart.Size = Vector3.new(6, 1, 6)
            AirwalkPart.Transparency = 1
            AirwalkPart.Anchored = true
            AirwalkPart.CanCollide = true
            AirwalkPart.Parent = workspace
        end
        AirwalkPart.CFrame = CFrame.new(hrp.Position.X, AirwalkY, hrp.Position.Z)
    end
end)

Connections.NoclipLoop = RunService.Stepped:Connect(function()
    if NoclipEnabled and LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end)

Connections.InfJumpLoop = UserInputService.JumpRequest:Connect(function()
    if InfJumpEnabled and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- 5. TAB 2: WAYPOINT (PATHFINDING + FORCED TPWALK COMPATIBILITY)
local WPCreateFrame = Instance.new("Frame")
WPCreateFrame.Size = UDim2.new(1, -5, 0, 28)
WPCreateFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
WPCreateFrame.Parent = WPTab
addCorner(WPCreateFrame, 4)

local WPInput = Instance.new("TextBox")
WPInput.Size = UDim2.new(0.65, -5, 0.8, 0)
WPInput.Position = UDim2.new(0, 5, 0.1, 0)
WPInput.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
WPInput.PlaceholderText = "Waypoint Name..."
WPInput.Text = ""
WPInput.TextColor3 = Color3.fromRGB(255, 255, 255)
WPInput.Font = Enum.Font.SourceSans
WPInput.TextSize = 11
WPInput.Parent = WPCreateFrame
addCorner(WPInput, 3)

local WPAddBtn = Instance.new("TextButton")
WPAddBtn.Size = UDim2.new(0.32, -5, 0.8, 0)
WPAddBtn.Position = UDim2.new(0.67, 0, 0.1, 0)
WPAddBtn.BackgroundColor3 = Color3.fromRGB(12, 35, 55)
WPAddBtn.Text = "+ Create"
WPAddBtn.TextColor3 = Color3.fromRGB(0, 229, 255)
WPAddBtn.Font = Enum.Font.SourceSansBold
WPAddBtn.TextSize = 11
WPAddBtn.Parent = WPCreateFrame
addCorner(WPAddBtn, 3)

local renderWaypoints

local function stopAllWaypointActions()
    if CurrentTweenObj then CurrentTweenObj:Cancel() CurrentTweenObj = nil end
    if ActiveWalkToThread then task.cancel(ActiveWalkToThread) ActiveWalkToThread = nil ActiveWalkToName = nil ActiveWalkToMode = nil end
    if ActiveLoopTPThread then task.cancel(ActiveLoopTPThread) ActiveLoopTPThread = nil ActiveLoopTPName = nil end
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):MoveTo(LocalPlayer.Character.HumanoidRootPart.Position)
    end
end

addActionButton(WPTab, "Cancel All Active Actions", Color3.fromRGB(60, 20, 20), function()
    stopAllWaypointActions()
    if renderWaypoints then renderWaypoints() end
end)

addInputRow(WPTab, "Tween Speed", TweenSpeedVal, function(v) TweenSpeedVal = v end)

local WPListFrame = Instance.new("Frame")
WPListFrame.Size = UDim2.new(1, -5, 0, 0)
WPListFrame.AutomaticSize = Enum.AutomaticSize.Y
WPListFrame.BackgroundTransparency = 1
WPListFrame.Parent = WPTab

local WPListLayout = Instance.new("UIListLayout")
WPListLayout.SortOrder = Enum.SortOrder.LayoutOrder
WPListLayout.Padding = UDim.new(0, 4)
WPListLayout.Parent = WPListFrame

local function saveWaypointsToFile()
    if writefile then
        local data = {}
        for name, cf in pairs(Waypoints) do data[name] = {cf:GetComponents()} end
        pcall(function() writefile(WaypointFileName, HttpService:JSONEncode(data)) end)
    end
end

renderWaypoints = function()
    for _, child in pairs(WPListFrame:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    for name, cf in pairs(Waypoints) do
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 30)
        card.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
        card.Parent = WPListFrame
        addCorner(card, 4)
        addStroke(card, Color3.fromRGB(22, 22, 30), 1)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.2, -2, 1, 0)
        lbl.Position = UDim2.new(0, 4, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = name
        lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        lbl.Font = Enum.Font.SourceSansBold
        lbl.TextSize = 10
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = card

        local btnTP = Instance.new("TextButton")
        btnTP.Size = UDim2.new(0.1, 0, 0.8, 0)
        btnTP.Position = UDim2.new(0.21, 0, 0.1, 0)
        btnTP.BackgroundColor3 = Color3.fromRGB(10, 45, 25)
        btnTP.Text = "TP"
        btnTP.TextColor3 = Color3.fromRGB(255, 255, 255)
        btnTP.Font = Enum.Font.SourceSansBold
        btnTP.TextSize = 9
        btnTP.Parent = card
        addCorner(btnTP, 3)

        local btnDirect = Instance.new("TextButton")
        btnDirect.Size = UDim2.new(0.17, 0, 0.8, 0)
        btnDirect.Position = UDim2.new(0.32, 0, 0.1, 0)
        btnDirect.BackgroundColor3 = (ActiveWalkToName == name and ActiveWalkToMode == "Direct") and Color3.fromRGB(0, 229, 255) or Color3.fromRGB(15, 35, 55)
        btnDirect.Text = "WalkTo"
        btnDirect.TextColor3 = (ActiveWalkToName == name and ActiveWalkToMode == "Direct") and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
        btnDirect.Font = Enum.Font.SourceSansBold
        btnDirect.TextSize = 9
        btnDirect.Parent = card
        addCorner(btnDirect, 3)

        local btnPath = Instance.new("TextButton")
        btnPath.Size = UDim2.new(0.18, 0, 0.8, 0)
        btnPath.Position = UDim2.new(0.50, 0, 0.1, 0)
        btnPath.BackgroundColor3 = (ActiveWalkToName == name and ActiveWalkToMode == "Path") and Color3.fromRGB(0, 229, 255) or Color3.fromRGB(25, 45, 65)
        btnPath.Text = "Pathfinding"
        btnPath.TextColor3 = (ActiveWalkToName == name and ActiveWalkToMode == "Path") and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
        btnPath.Font = Enum.Font.SourceSansBold
        btnPath.TextSize = 8
        btnPath.Parent = card
        addCorner(btnPath, 3)

        local btnLoop = Instance.new("TextButton")
        btnLoop.Size = UDim2.new(0.16, 0, 0.8, 0)
        btnLoop.Position = UDim2.new(0.69, 0, 0.1, 0)
        btnLoop.BackgroundColor3 = (ActiveLoopTPName == name) and Color3.fromRGB(0, 229, 255) or Color3.fromRGB(45, 35, 10)
        btnLoop.Text = "Loop 0.2s"
        btnLoop.TextColor3 = (ActiveLoopTPName == name) and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
        btnLoop.Font = Enum.Font.SourceSansBold
        btnLoop.TextSize = 8
        btnLoop.Parent = card
        addCorner(btnLoop, 3)

        local btnDel = Instance.new("TextButton")
        btnDel.Size = UDim2.new(0.1, 0, 0.8, 0)
        btnDel.Position = UDim2.new(0.87, 0, 0.1, 0)
        btnDel.BackgroundColor3 = Color3.fromRGB(50, 15, 15)
        btnDel.Text = "✕"
        btnDel.TextColor3 = Color3.fromRGB(255, 255, 255)
        btnDel.Font = Enum.Font.SourceSansBold
        btnDel.TextSize = 9
        btnDel.Parent = card
        addCorner(btnDel, 3)

        btnTP.MouseButton1Click:Connect(function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                LocalPlayer.Character.HumanoidRootPart.CFrame = cf
            end
        end)

        -- DIRECT WALKTO WITH TPWALK OVERRIDE
        btnDirect.MouseButton1Click:Connect(function()
            if ActiveWalkToName == name and ActiveWalkToMode == "Direct" then
                stopAllWaypointActions()
                renderWaypoints()
            else
                stopAllWaypointActions()
                ActiveWalkToName = name
                ActiveWalkToMode = "Direct"
                ActiveWalkToThread = task.spawn(function()
                    while ActiveWalkToName == name do
                        local char = LocalPlayer.Character
                        local hum = char and char:FindFirstChildOfClass("Humanoid")
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")

                        if hum and hrp then
                            local dir = (cf.Position - hrp.Position)
                            local flatDir = Vector3.new(dir.X, 0, dir.Z)
                            if flatDir.Magnitude <= 3 then
                                stopAllWaypointActions()
                                renderWaypoints()
                                break
                            end

                            if TPWalkEnabled then
                                char:TranslateBy(flatDir.Unit * TPWalkVal * 0.3 * 10)
                            else
                                hum:MoveTo(cf.Position)
                            end
                        end
                        task.wait(0.03)
                    end
                end)
                renderWaypoints()
            end
        end)

        -- PATHFINDING WALKTO WITH SMART NAV & TPWALK OVERRIDE
        btnPath.MouseButton1Click:Connect(function()
            if ActiveWalkToName == name and ActiveWalkToMode == "Path" then
                stopAllWaypointActions()
                renderWaypoints()
            else
                stopAllWaypointActions()
                ActiveWalkToName = name
                ActiveWalkToMode = "Path"
                ActiveWalkToThread = task.spawn(function()
                    local char = LocalPlayer.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if not (hum and hrp) then return end

                    local path = PathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = true})
                    local success = pcall(function() path:ComputeAsync(hrp.Position, cf.Position) end)

                    if success and path.Status == Enum.PathStatus.Success then
                        local pathWaypoints = path:GetWaypoints()
                        for _, wp in ipairs(pathWaypoints) do
                            if ActiveWalkToName ~= name then break end
                            if wp.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end

                            while ActiveWalkToName == name do
                                char = LocalPlayer.Character
                                hum = char and char:FindFirstChildOfClass("Humanoid")
                                hrp = char and char:FindFirstChild("HumanoidRootPart")
                                if not (hum and hrp) then break end

                                local dir = (wp.Position - hrp.Position)
                                local flatDir = Vector3.new(dir.X, 0, dir.Z)
                                if flatDir.Magnitude <= 2.5 then break end

                                if TPWalkEnabled then
                                    char:TranslateBy(flatDir.Unit * TPWalkVal * 0.03 * 10)
                                else
                                    hum:MoveTo(wp.Position)
                                end
                                task.wait(0.03)
                            end
                        end
                    else
                        -- Fallback Direct Walk
                        while ActiveWalkToName == name do
                            char = LocalPlayer.Character
                            hum = char and char:FindFirstChildOfClass("Humanoid")
                            hrp = char and char:FindFirstChild("HumanoidRootPart")
                            if not (hum and hrp) then break end

                            local dir = (cf.Position - hrp.Position)
                            local flatDir = Vector3.new(dir.X, 0, dir.Z)
                            if flatDir.Magnitude <= 3 then break end

                            if TPWalkEnabled then
                                char:TranslateBy(flatDir.Unit * TPWalkVal * 0.03 * 10)
                            else
                                hum:MoveTo(cf.Position)
                            end
                            task.wait(0.03)
                        end
                    end

                    stopAllWaypointActions()
                    renderWaypoints()
                end)
                renderWaypoints()
            end
        end)

        btnLoop.MouseButton1Click:Connect(function()
            if ActiveLoopTPName == name then
                stopAllWaypointActions()
                renderWaypoints()
            else
                stopAllWaypointActions()
                ActiveLoopTPName = name
                ActiveLoopTPThread = task.spawn(function()
                    while ActiveLoopTPName == name do
                        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                            LocalPlayer.Character.HumanoidRootPart.CFrame = cf
                        end
                        task.wait(0.2)
                    end
                end)
                renderWaypoints()
            end
        end)

        btnDel.MouseButton1Click:Connect(function()
            if ActiveLoopTPName == name or ActiveWalkToName == name then stopAllWaypointActions() end
            Waypoints[name] = nil
            saveWaypointsToFile()
            renderWaypoints()
        end)
    end
end

WPAddBtn.MouseButton1Click:Connect(function()
    local name = WPInput.Text ~= "" and WPInput.Text or ("WP_" .. tostring(#WPListFrame:GetChildren() + 1))
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        Waypoints[name] = char.HumanoidRootPart.CFrame
        WPInput.Text = ""
        saveWaypointsToFile()
        renderWaypoints()
    end
end)

-- Initial Load Waypoints
if readfile and isfile and isfile(WaypointFileName) then
    pcall(function()
        local decoded = HttpService:JSONDecode(readfile(WaypointFileName))
        for name, cfTable in pairs(decoded) do Waypoints[name] = CFrame.new(unpack(cfTable)) end
    end)
end
renderWaypoints()

-- 6. TAB 3: PLAYER (WITH LIVE SEARCH & SAFE TELEPORT)
local SearchFrame = Instance.new("Frame")
SearchFrame.Size = UDim2.new(1, -5, 0, 26)
SearchFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
SearchFrame.Parent = PlayerTab
addCorner(SearchFrame, 4)
addStroke(SearchFrame, Color3.fromRGB(22, 22, 30), 1)

local SearchBox = Instance.new("TextBox")
SearchBox.Size = UDim2.new(1, -10, 1, 0)
SearchBox.Position = UDim2.new(0, 5, 0, 0)
SearchBox.BackgroundTransparency = 1
SearchBox.PlaceholderText = "🔍 Search Player Name..."
SearchBox.Text = ""
SearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
SearchBox.Font = Enum.Font.SourceSans
SearchBox.TextSize = 11
SearchBox.TextXAlignment = Enum.TextXAlignment.Left
SearchBox.Parent = SearchFrame

local PlrListFrame = Instance.new("Frame")
PlrListFrame.Size = UDim2.new(1, -5, 0, 95)
PlrListFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
PlrListFrame.Parent = PlayerTab
addCorner(PlrListFrame, 4)
addStroke(PlrListFrame, Color3.fromRGB(22, 22, 30), 1)

local PlrScroll = Instance.new("ScrollingFrame")
PlrScroll.Size = UDim2.new(1, -10, 1, -10)
PlrScroll.Position = UDim2.new(0, 5, 0, 5)
PlrScroll.BackgroundTransparency = 1
PlrScroll.ScrollBarThickness = 3
PlrScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
PlrScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
PlrScroll.Parent = PlrListFrame

local PlrListLayout = Instance.new("UIListLayout")
PlrListLayout.SortOrder = Enum.SortOrder.LayoutOrder
PlrListLayout.Padding = UDim.new(0, 3)
PlrListLayout.Parent = PlrScroll

local TargetLbl = Instance.new("TextLabel")
TargetLbl.Size = UDim2.new(1, -5, 0, 18)
TargetLbl.BackgroundTransparency = 1
TargetLbl.Text = "Target: None"
TargetLbl.TextColor3 = Color3.fromRGB(0, 229, 255)
TargetLbl.Font = Enum.Font.SourceSansBold
TargetLbl.TextSize = 11
TargetLbl.Parent = PlayerTab

local function refreshPlayerList()
    for _, child in pairs(PlrScroll:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
    local query = string.lower(SearchBox.Text)

    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local matchName = string.find(string.lower(plr.Name), query)
            local matchDisplay = string.find(string.lower(plr.DisplayName), query)

            if query == "" or matchName or matchDisplay then
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, 0, 0, 22)
                btn.BackgroundColor3 = (SelectedPlayer == plr) and Color3.fromRGB(12, 35, 55) or Color3.fromRGB(8, 8, 12)
                btn.Text = " " .. plr.DisplayName .. " (@" .. plr.Name .. ")"
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
                btn.Font = Enum.Font.SourceSans
                btn.TextSize = 11
                btn.TextXAlignment = Enum.TextXAlignment.Left
                btn.Parent = PlrScroll
                addCorner(btn, 3)

                btn.MouseButton1Click:Connect(function()
                    SelectedPlayer = plr
                    TargetLbl.Text = "Target: " .. plr.Name
                    refreshPlayerList()
                end)
            end
        end
    end
end

SearchBox:GetPropertyChangedSignal("Text"):Connect(refreshPlayerList)

addActionButton(PlayerTab, "Refresh Player List", Color3.fromRGB(14, 14, 20), refreshPlayerList)

-- SAFE TP TO PLAYER
addActionButton(PlayerTab, "TP to Player", Color3.fromRGB(10, 45, 25), function()
    if SelectedPlayer and SelectedPlayer.Character then
        local targetHRP = SelectedPlayer.Character:FindFirstChild("HumanoidRootPart")
        local targetHum = SelectedPlayer.Character:FindFirstChildOfClass("Humanoid")
        local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

        if targetHRP and targetHum and targetHum.Health > 0 and myHRP then
            myHRP.CFrame = targetHRP.CFrame
        end
    end
end)

-- SAFE TWEEN TO PLAYER
addActionButton(PlayerTab, "Tween to Player", Color3.fromRGB(50, 35, 10), function()
    if SelectedPlayer and SelectedPlayer.Character then
        local targetHRP = SelectedPlayer.Character:FindFirstChild("HumanoidRootPart")
        local targetHum = SelectedPlayer.Character:FindFirstChildOfClass("Humanoid")
        local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

        if targetHRP and targetHum and targetHum.Health > 0 and myHRP then
            local dist = (myHRP.Position - targetHRP.Position).Magnitude
            local time = dist / math.max(TweenSpeedVal, 1)
            stopAllWaypointActions()
            CurrentTweenObj = TweenService:Create(myHRP, TweenInfo.new(time, Enum.EasingStyle.Linear), {CFrame = targetHRP.CFrame})
            CurrentTweenObj:Play()
        end
    end
end)

addToggle(PlayerTab, "Headsit (Sit on Head)", false, function(state) HeadsitEnabled = state end)

addToggle(PlayerTab, "Spectate Player", false, function(state)
    SpectateEnabled = state
    if SpectateEnabled and SelectedPlayer and SelectedPlayer.Character and SelectedPlayer.Character:FindFirstChildOfClass("Humanoid") then
        Camera.CameraSubject = SelectedPlayer.Character:FindFirstChildOfClass("Humanoid")
    else
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
            Camera.CameraSubject = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        end
    end
end)

addToggle(PlayerTab, "Anti-Anchored / Anti-Stun", false, function(state) AntiAnchoredEnabled = state end)

Connections.AntiAnchoredLoop = RunService.Heartbeat:Connect(function()
    if AntiAnchoredEnabled and LocalPlayer.Character then
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hrp and hrp.Anchored then hrp.Anchored = false end
        if hum and hum.PlatformStand then hum.PlatformStand = false end
    end
end)

Connections.HeadsitLoop = RunService.Heartbeat:Connect(function()
    if HeadsitEnabled and SelectedPlayer and SelectedPlayer.Character and SelectedPlayer.Character:FindFirstChild("Head") then
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hrp and hum then
            hrp.CFrame = SelectedPlayer.Character.Head.CFrame * CFrame.new(0, 2, 0)
            hum.Sit = true
        end
    end
end)

refreshPlayerList()

-- 7. TAB 4: VISUAL (DYNAMIC FULLBRIGHT, NOFOG & CUSTOM MAXZOOM)
local function getChamColor(plr)
    if isTeammate(plr) then return Color3.fromRGB(0, 255, 120) else return Color3.fromRGB(0, 229, 255) end
end

local function applyChams(plr)
    if not plr or plr == LocalPlayer or not ChamsEnabled then return end
    local char = plr.Character
    if not char then return end

    local hl = char:FindFirstChild("FEUtilityCham")
    if not hl then
        hl = Instance.new("Highlight")
        hl.Name = "FEUtilityCham"
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = 0.5
        hl.Adornee = char
        hl.Parent = char
    end
    hl.FillColor = getChamColor(plr)
end

local function removeChams()
    for _, plr in pairs(Players:GetPlayers()) do
        if plr.Character then
            local hl = plr.Character:FindFirstChild("FEUtilityCham")
            if hl then hl:Destroy() end
        end
    end
end

local function setupPlayerListeners(plr)
    if plr == LocalPlayer then return end
    plr.CharacterAdded:Connect(function(char)
        if ChamsEnabled then task.wait(0.5) applyChams(plr) end
    end)
    if plr.Character then applyChams(plr) end
end

for _, plr in pairs(Players:GetPlayers()) do setupPlayerListeners(plr) end
Connections.PlayerAddedChams = Players.PlayerAdded:Connect(setupPlayerListeners)

task.spawn(function()
    while true do
        if ChamsEnabled then
            for _, plr in pairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then applyChams(plr) end
            end
        end
        task.wait(1)
    end
end)

local function updateDistanceESP()
    for _, e in pairs(ESPLabels) do e:Destroy() end
    table.clear(ESPLabels)
    if not DistanceESPEnabled then return end

    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("Head") then
            local bg = Instance.new("BillboardGui")
            bg.Size = UDim2.new(0, 100, 0, 30)
            bg.Adornee = plr.Character.Head
            bg.AlwaysOnTop = true
            bg.Parent = ScreenGui

            local txt = Instance.new("TextLabel")
            txt.Size = UDim2.new(1, 0, 1, 0)
            txt.BackgroundTransparency = 1
            txt.TextColor3 = getChamColor(plr)
            txt.Font = Enum.Font.SourceSansBold
            txt.TextSize = 11
            txt.Parent = bg

            table.insert(ESPLabels, bg)
        end
    end
end

addToggle(VisualTab, "Team-Color Chams ESP", false, function(state)
    ChamsEnabled = state
    if ChamsEnabled then
        for _, plr in pairs(Players:GetPlayers()) do applyChams(plr) end
    else
        removeChams()
    end
end)

addToggle(VisualTab, "Distance ESP", false, function(state)
    DistanceESPEnabled = state
    updateDistanceESP()
end)

-- DYNAMIC FULLBRIGHT ENGINE
local function applyFullbright()
    if not FullbrightEnabled then return end
    game.Lighting.Brightness = 2
    game.Lighting.GlobalShadows = false
    game.Lighting.Ambient = Color3.fromRGB(255, 255, 255)
    game.Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
end

addToggle(VisualTab, "Fullbright", false, function(state)
    FullbrightEnabled = state
    for _, conn in pairs(FullbrightConns) do conn:Disconnect() end
    table.clear(FullbrightConns)

    if FullbrightEnabled then
        applyFullbright()
        table.insert(FullbrightConns, game.Lighting:GetPropertyChangedSignal("Brightness"):Connect(applyFullbright))
        table.insert(FullbrightConns, game.Lighting:GetPropertyChangedSignal("Ambient"):Connect(applyFullbright))
        table.insert(FullbrightConns, game.Lighting:GetPropertyChangedSignal("OutdoorAmbient"):Connect(applyFullbright))
        table.insert(FullbrightConns, game.Lighting:GetPropertyChangedSignal("GlobalShadows"):Connect(applyFullbright))
    else
        game.Lighting.Brightness = DefaultLighting.Brightness
        game.Lighting.GlobalShadows = DefaultLighting.GlobalShadows
        game.Lighting.Ambient = DefaultLighting.Ambient
        game.Lighting.OutdoorAmbient = DefaultLighting.OutdoorAmbient
    end
end)

-- DYNAMIC NOFOG ENGINE
local function applyNoFog()
    if not NoFogEnabled then return end
    game.Lighting.FogEnd = 999999
    for _, v in pairs(game.Lighting:GetDescendants()) do if v:IsA("Atmosphere") then v.Density = 0 end end
end

addToggle(VisualTab, "NoFog", false, function(state)
    NoFogEnabled = state
    for _, conn in pairs(NoFogConns) do conn:Disconnect() end
    table.clear(NoFogConns)

    if NoFogEnabled then
        applyNoFog()
        table.insert(NoFogConns, game.Lighting:GetPropertyChangedSignal("FogEnd"):Connect(applyNoFog))
        table.insert(NoFogConns, game.Lighting.ChildAdded:Connect(function(child) if child:IsA("Atmosphere") then child.Density = 0 end end))
        table.insert(NoFogConns, workspace.DescendantAdded:Connect(function(desc) if NoFogEnabled and desc:IsA("Atmosphere") then desc.Density = 0 end end))
    else
        game.Lighting.FogEnd = DefaultLighting.FogEnd
    end
end)

-- CUSTOM MAXZOOM VIA STANDARD TEXTBOX
addInputRow(VisualTab, "Custom MaxZoom", CustomMaxZoomVal, function(v)
    CustomMaxZoomVal = v
    LocalPlayer.CameraMaxZoomDistance = v
end)

addActionButton(VisualTab, "FPS Booster (Low Graphics)", Color3.fromRGB(12, 35, 55), function()
    pcall(function()
        for _, v in pairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") then
                v.Material = Enum.Material.SmoothPlastic
                v.CastShadow = false
            elseif v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                v.Enabled = false
            end
        end
    end)
end)

addToggle(VisualTab, "Freecam", false, function(state)
    FreecamEnabled = state
    if FreecamEnabled then
        FreecamCamType = Camera.CameraType
        Camera.CameraType = Enum.CameraType.Scriptable
    else
        Camera.CameraType = FreecamCamType
    end
end)

addToggle(VisualTab, "Noclip Cam", false, function(state)
    NoclipCamEnabled = state
    LocalPlayer.DevCameraOcclusionMode = state and Enum.DevCameraOcclusionMode.Invisicam or Enum.DevCameraOcclusionMode.Zoom
end)

Connections.ESPUpdateLoop = RunService.RenderStepped:Connect(function()
    if DistanceESPEnabled then
        for _, bg in pairs(ESPLabels) do
            if bg.Adornee and bg.Adornee.Parent and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local dist = math.floor((LocalPlayer.Character.HumanoidRootPart.Position - bg.Adornee.Position).Magnitude)
                local txtLabel = bg:FindFirstChildOfClass("TextLabel")
                if txtLabel then txtLabel.Text = bg.Adornee.Parent.Name .. "\n[" .. tostring(dist) .. "m]" end
            end
        end
    end
end)

-- 8. TAB 5: UTILITY & RAPIH DATA
addToggle(UtilTab, "Anti Gameplay Pause", true, function(state)
    AntiGameplayPauseEnabled = state
    pcall(function() GuiService:SetGameplayPausedNotificationEnabled(not state) end)
end)

local function applyInstantPrompt(prompt)
    if prompt:IsA("ProximityPrompt") then prompt.HoldDuration = 0 end
end

addToggle(UtilTab, "Instant Proximity Prompt", false, function(state)
    InstantPromptEnabled = state
    if InstantPromptConn then InstantPromptConn:Disconnect() InstantPromptConn = nil end

    if state then
        for _, desc in pairs(workspace:GetDescendants()) do applyInstantPrompt(desc) end
        InstantPromptConn = workspace.DescendantAdded:Connect(function(desc)
            if InstantPromptEnabled then applyInstantPrompt(desc) end
        end)
    end
end)

addToggle(UtilTab, "Anti-AFK", true, function(state) AntiAFKEnabled = state end)

Connections.AntiAFKLoop = LocalPlayer.Idled:Connect(function()
    if AntiAFKEnabled then
        local vu = game:GetService("VirtualUser")
        vu:CaptureController()
        vu:ClickButton2(Vector2.zero)
    end
end)

addActionButton(UtilTab, "Launch MoonDex", Color3.fromRGB(25, 20, 45), function()
    pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/infyiff/backup/main/dex.lua"))() end)
end)

addActionButton(UtilTab, "Launch Cobalt RSpy", Color3.fromRGB(12, 30, 50), function()
    pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/GOTROBLOX/Cobalt/main/Cobalt.lua"))() end)
end)

addActionButton(UtilTab, "Rejoin Server", Color3.fromRGB(40, 25, 50), function()
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end)

-- FIXED SAVE CONFIG TO FOLDER 'FEUtilityData/'
addActionButton(UtilTab, "Save Config Per-Game", Color3.fromRGB(10, 45, 25), function()
    if writefile then
        local cfg = {
            WalkSpeedVal = WalkSpeedVal,
            TPWalkVal = TPWalkVal,
            JumpPowerVal = JumpPowerVal,
            HipHeightVal = HipHeightVal,
            GravityVal = GravityVal,
            CustomMaxZoomVal = CustomMaxZoomVal
        }
        pcall(function() writefile(ConfigFileName, HttpService:JSONEncode(cfg)) end)
    end
end)

-- AUTO LOAD CONFIG
if readfile and isfile and isfile(ConfigFileName) then
    pcall(function()
        local cfg = HttpService:JSONDecode(readfile(ConfigFileName))
        if cfg.WalkSpeedVal then WalkSpeedVal = cfg.WalkSpeedVal end
        if cfg.TPWalkVal then TPWalkVal = cfg.TPWalkVal end
        if cfg.JumpPowerVal then JumpPowerVal = cfg.JumpPowerVal end
        if cfg.HipHeightVal then HipHeightVal = cfg.HipHeightVal end
        if cfg.GravityVal then GravityVal = cfg.GravityVal end
        if cfg.CustomMaxZoomVal then
            CustomMaxZoomVal = cfg.CustomMaxZoomVal
            LocalPlayer.CameraMaxZoomDistance = CustomMaxZoomVal
        end
    end)
end

addActionButton(UtilTab, "UNLOAD SCRIPT", Color3.fromRGB(60, 15, 15), function()
    if _G.FEUtilityCleanup then _G.FEUtilityCleanup() end
end)

-- 9. TOGGLE & CLEANUP BINDINGS
CloseBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false end)
ToggleBtn.MouseButton1Click:Connect(function() MainFrame.Visible = not MainFrame.Visible end)

_G.FEUtilityCleanup = function()
    TPWalkEnabled = false
    WallTPEnabled = false
    ChamsEnabled = false
    FlyEnabled = false
    FullbrightEnabled = false
    NoFogEnabled = false
    InstantPromptEnabled = false

    stopFly()
    disableWallTP()
    removeChams()
    stopAllWaypointActions()

    if InstantPromptConn then InstantPromptConn:Disconnect() InstantPromptConn = nil end
    for _, conn in pairs(FullbrightConns) do conn:Disconnect() end
    for _, conn in pairs(NoFogConns) do conn:Disconnect() end
    table.clear(FullbrightConns)
    table.clear(NoFogConns)

    for _, conn in pairs(Connections) do
        if conn and conn.Connected then conn:Disconnect() end
    end

    for _, e in pairs(ESPLabels) do e:Destroy() end
    if AirwalkPart then AirwalkPart:Destroy() end

    pcall(function() GuiService:SetGameplayPausedNotificationEnabled(true) end)

    ScreenGui:Destroy()
    _G.FEUtilityCleanup = nil
end
