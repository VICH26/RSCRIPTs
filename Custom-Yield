--[[
    =======================================================
    CUSTOM FE UTILITY GUI (MOBILE FRIENDLY - FIXED FLY ENGINE)
    Style: True Black Minimalist / AMOLED Clean UX
    Features: 30+ Utilities, Ultra-Low Latency Aimbot Engine,
              Dynamic Proximity Prompts, Dynamic Fullbright & NoFog,
              Mobile Fly (Hybrid MoveDirection + ControlModule),
              TPWalk (TranslateBy), WallTP (Touch Auto-Climb),
              Dynamic Chams, Per-Game Config & Resizable Window
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

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Global Storage
local Connections = {}
local ESPLabels = {}
local NPCCache = {}
local FullbrightConns = {}
local NoFogConns = {}
local InstantPromptConn = nil
local ControlModule = nil

local currentChar = LocalPlayer.Character
local currentHum = currentChar and currentChar:FindFirstChildOfClass("Humanoid")

-- Feature Variables & Defaults
local WalkSpeedVal = currentHum and currentHum.WalkSpeed or 16
local TPWalkVal = 1
local JumpPowerVal = currentHum and (currentHum.UseJumpPower and currentHum.JumpPower or 50) or 50
local HipHeightVal = currentHum and currentHum.HipHeight or 0
local GravityVal = workspace.Gravity
local FlySpeedVal = 50
local VehicleSpeedVal = 100
local TweenSpeedVal = 100
local PromptRadiusVal = 10

-- Combat & Aimbot Variables
local AimbotEnabled = false
local AimbotTargetMode = "Enemies" -- "Enemies", "All Players", "NPCs", "All"
local AimbotTargetPart = "Head" -- "Head", "HumanoidRootPart"
local IgnoreTeams = true
local WallCheck = true
local ShowFOVCircle = true
local FOVRadiusVal = 60
local SmoothnessVal = 2
local VelocityPredictionEnabled = false
local PredictionScaleVal = 1.0

local KillAuraEnabled = false
local KillAuraRadius = 50
local KillAuraDelay = 0.1
local KillAuraTargetMode = "NPCs"
local WeaponReachEnabled = false
local WeaponReachSize = 15

-- Movement Flags
local WalkSpeedEnabled = false
local TPWalkEnabled = false
local WallTPEnabled = false
local WallTPConn = nil
local FlyEnabled = false
local FloatEnabled = false
local InfJumpEnabled = false
local NoclipEnabled = false
local AirwalkEnabled = false
local NoclipVehicleEnabled = false

-- Visual Flags
local ChamsEnabled = false
local DistanceESPEnabled = false
local FullbrightEnabled = false
local NoFogEnabled = false
local MaxZoomEnabled = false
local NoclipCamEnabled = false
local FreecamEnabled = false

-- Utility Flags
local AntiAFKEnabled = true
local InstantPromptEnabled = false
local AutoPromptEnabled = false
local AntiGameplayPauseEnabled = false
local AntiKnockbackEnabled = false
local AntiRagdollEnabled = false
local AntiAnchoredEnabled = false
local HeadsitEnabled = false
local SpectateEnabled = false

local SelectedPlayer = nil
local CurrentTweenObj = nil
local AirwalkPart = nil
local FreecamCamType = Camera.CameraType

local Waypoints = {}
local WaypointFileName = "Waypoints_" .. tostring(game.PlaceId) .. ".json"
local ConfigFileName = "Config_FEUtility_" .. tostring(game.PlaceId) .. ".json"

local FlyVelocityName = "FEFlyVelocity"
local FlyGyroName = "FEFlyGyro"
local FloatBV, FloatBG

local DefaultLighting = {
    Brightness = game.Lighting.Brightness,
    FogEnd = game.Lighting.FogEnd,
    GlobalShadows = game.Lighting.GlobalShadows,
    Ambient = game.Lighting.Ambient,
    OutdoorAmbient = game.Lighting.OutdoorAmbient
}

-- Drawing API FOV Circle
local FOVCircle = nil
pcall(function()
    if Drawing and Drawing.new then
        FOVCircle = Drawing.new("Circle")
        FOVCircle.Thickness = 1.5
        FOVCircle.Color = Color3.fromRGB(0, 229, 255)
        FOVCircle.Filled = false
        FOVCircle.Transparency = 0.7
        FOVCircle.Radius = FOVRadiusVal
        FOVCircle.Visible = false
    end
end)

-- SAFE HYBRID MOVE INPUT CALCULATOR (PREVENTS STUCK FLY BUG)
local function getMoveInput(hum)
    local moveVector = Vector3.zero

    -- 1. Coba ambil dari ControlModule jika ada
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

    -- 2. Fallback Universal via Humanoid.MoveDirection jika ControlModule tidak memberikan nilai
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

    if LocalPlayer.Team and targetPlayer.Team then
        if LocalPlayer.Team == targetPlayer.Team then return true end
    end

    if LocalPlayer.TeamColor and targetPlayer.TeamColor then
        if LocalPlayer.TeamColor == targetPlayer.TeamColor then return true end
    end

    local lpTeamAttr = LocalPlayer:GetAttribute("Team") or (LocalPlayer.Character and LocalPlayer.Character:GetAttribute("Team"))
    local tpTeamAttr = targetPlayer:GetAttribute("Team") or (targetPlayer.Character and targetPlayer.Character:GetAttribute("Team"))
    if lpTeamAttr and tpTeamAttr and lpTeamAttr == tpTeamAttr then return true end

    local lpLs = LocalPlayer:FindFirstChild("leaderstats") and (LocalPlayer.leaderstats:FindFirstChild("Team") or LocalPlayer.leaderstats:FindFirstChild("Faction"))
    local tpLs = targetPlayer:FindFirstChild("leaderstats") and (targetPlayer.leaderstats:FindFirstChild("Team") or targetPlayer.leaderstats:FindFirstChild("Faction"))
    if lpLs and tpLs and lpLs.Value == tpLs.Value then return true end

    return false
end

-- BACKGROUND NPC SCANNER (OPTIMIZED RUNS ONCE PER SECOND)
task.spawn(function()
    while true do
        if AimbotEnabled or KillAuraEnabled then
            local newCache = {}
            local myChar = LocalPlayer.Character

            local function scanContainer(parent)
                for _, obj in pairs(parent:GetChildren()) do
                    if obj:IsA("Model") and obj ~= myChar and not Players:GetPlayerFromCharacter(obj) then
                        if obj:FindFirstChildOfClass("Humanoid") and (obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Head")) then
                            table.insert(newCache, obj)
                        end
                    elseif obj:IsA("Folder") or (obj:IsA("Model") and not obj:FindFirstChildOfClass("Humanoid")) then
                        for _, subObj in pairs(obj:GetChildren()) do
                            if subObj:IsA("Model") and subObj ~= myChar and not Players:GetPlayerFromCharacter(subObj) then
                                if subObj:FindFirstChildOfClass("Humanoid") and (subObj:FindFirstChild("HumanoidRootPart") or subObj:FindFirstChild("Head")) then
                                    table.insert(newCache, subObj)
                                end
                            end
                        end
                    end
                end
            end

            scanContainer(workspace)
            NPCCache = newCache
        end
        task.wait(1)
    end
end)

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
    btn.Size = UDim2.new(0, 58, 1, 0)
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
            TabButtons[tName].BackgroundColor3 = isTarget and Color3.fromRGB(0, 229, 255) or Color3.fromRGB(10, 10, 14)
            TabButtons[tName].TextColor3 = isTarget and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(150, 150, 160)
        end
    end)

    return scrollFrame
end

local MoveTab = createTab("Move")
local CombatTab = createTab("Combat")
local WPTab = createTab("Waypoint")
local PlayerTab = createTab("Player")
local VisualTab = createTab("Visual")
local UtilTab = createTab("Util")

Tabs["Move"].Visible = true
TabButtons["Move"].BackgroundColor3 = Color3.fromRGB(0, 229, 255)
TabButtons["Move"].TextColor3 = Color3.fromRGB(0, 0, 0)

-- 3. UI CONTROLS HELPERS
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
    box.Text = tostring(defaultValue)
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.Font = Enum.Font.SourceSans
    box.TextSize = 11
    box.Parent = frame
    addCorner(box, 3)

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

local function addSliderInput(parent, labelText, minVal, maxVal, defaultVal, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -5, 0, 38)
    frame.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
    frame.Parent = parent
    addCorner(frame, 4)
    addStroke(frame, Color3.fromRGB(22, 22, 30), 1)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.6, -5, 0, 18)
    lbl.Position = UDim2.new(0, 6, 0, 2)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = Color3.fromRGB(200, 200, 210)
    lbl.Font = Enum.Font.SourceSans
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.32, -5, 0, 16)
    box.Position = UDim2.new(0.68, 0, 0, 3)
    box.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    box.Text = tostring(defaultVal)
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.Font = Enum.Font.SourceSans
    box.TextSize = 11
    box.Parent = frame
    addCorner(box, 3)

    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(1, -12, 0, 6)
    sliderBg.Position = UDim2.new(0, 6, 0, 24)
    sliderBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    sliderBg.Parent = frame
    addCorner(sliderBg, 3)

    local sliderFill = Instance.new("Frame")
    local initialPercent = math.clamp((defaultVal - minVal) / (maxVal - minVal), 0, 1)
    sliderFill.Size = UDim2.new(initialPercent, 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(0, 229, 255)
    sliderFill.Parent = sliderBg
    addCorner(sliderFill, 3)

    local isDragging = false
    local function updateSlider(inputPos)
        local scale = math.clamp((inputPos.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
        sliderFill.Size = UDim2.new(scale, 0, 1, 0)
        local val = math.floor((minVal + (maxVal - minVal) * scale) * 100 + 0.5) / 100
        box.Text = tostring(val)
        callback(val)
    end

    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            updateSlider(input.Position)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input.Position)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = false
        end
    end)

    return frame
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

-- 4. TAB 1: MOVEMENT
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
    if WallTPConn then
        WallTPConn:Disconnect()
        WallTPConn = nil
    end
end

addToggle(MoveTab, "WallTP (Touch Auto-Climb)", false, function(state)
    WallTPEnabled = state
    if state then enableWallTP() else disableWallTP() end
end)

Connections.WallTPCharAdded = LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
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

addToggle(MoveTab, "Float", false, function(state)
    FloatEnabled = state
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local hrp = char.HumanoidRootPart

    if FloatEnabled then
        FloatBV = Instance.new("BodyVelocity")
        FloatBV.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        FloatBV.Velocity = Vector3.zero
        FloatBV.Parent = hrp

        FloatBG = Instance.new("BodyGyro")
        FloatBG.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
        FloatBG.CFrame = hrp.CFrame
        FloatBG.Parent = hrp
    else
        if FloatBV then FloatBV:Destroy() end
        if FloatBG then FloatBG:Destroy() end
    end
end)

addToggle(MoveTab, "Airwalk (Invisible Floor)", false, function(state)
    AirwalkEnabled = state
    if not state and AirwalkPart then
        AirwalkPart:Destroy()
        AirwalkPart = nil
    end
end)

addToggle(MoveTab, "Noclip Vehicle", false, function(state) NoclipVehicleEnabled = state end)
addToggle(MoveTab, "Infinite Jump", false, function(state) InfJumpEnabled = state end)
addToggle(MoveTab, "Noclip", false, function(state) NoclipEnabled = state end)

-- 5. TAB 2: COMBAT (AIMBOT, KILL AURA, WEAPON REACH)
addToggle(CombatTab, "Aimbot Target Lock", false, function(state) AimbotEnabled = state end)

local AimTargetBtn = addActionButton(CombatTab, "Aimbot Mode: " .. AimbotTargetMode, Color3.fromRGB(20, 20, 30), function()
    if AimbotTargetMode == "Enemies" then AimbotTargetMode = "All Players"
    elseif AimbotTargetMode == "All Players" then AimbotTargetMode = "NPCs"
    elseif AimbotTargetMode == "NPCs" then AimbotTargetMode = "All"
    else AimbotTargetMode = "Enemies" end
end)
AimTargetBtn.MouseButton1Click:Connect(function() AimTargetBtn.Text = "Aimbot Mode: " .. AimbotTargetMode end)

local AimPartBtn = addActionButton(CombatTab, "Aim Part: " .. AimbotTargetPart, Color3.fromRGB(20, 20, 30), function()
    if AimbotTargetPart == "Head" then AimbotTargetPart = "HumanoidRootPart"
    else AimbotTargetPart = "Head" end
end)
AimPartBtn.MouseButton1Click:Connect(function() AimPartBtn.Text = "Aim Part: " .. AimbotTargetPart end)

addToggle(CombatTab, "Ignore Teams", true, function(state) IgnoreTeams = state end)
addToggle(CombatTab, "Wall Check (Raycast)", true, function(state) WallCheck = state end)
addToggle(CombatTab, "Show FOV Circle", true, function(state)
    ShowFOVCircle = state
    if FOVCircle then FOVCircle.Visible = state end
end)

addSliderInput(CombatTab, "FOV Circle Radius", 0, 180, FOVRadiusVal, function(val)
    FOVRadiusVal = val
    if FOVCircle then FOVCircle.Radius = val end
end)

addSliderInput(CombatTab, "Aimbot Smoothness", 0, 10, SmoothnessVal, function(val) SmoothnessVal = val end)
addToggle(CombatTab, "Velocity Prediction", false, function(state) VelocityPredictionEnabled = state end)
addSliderInput(CombatTab, "Prediction Scale", 0.1, 2.0, PredictionScaleVal, function(val) PredictionScaleVal = val end)

addToggle(CombatTab, "Kill Aura", false, function(state) KillAuraEnabled = state end)

local TargetModeBtn = addActionButton(CombatTab, "Aura Target Mode: " .. KillAuraTargetMode, Color3.fromRGB(20, 20, 30), function()
    if KillAuraTargetMode == "NPCs" then KillAuraTargetMode = "Players"
    elseif KillAuraTargetMode == "Players" then KillAuraTargetMode = "All"
    else KillAuraTargetMode = "NPCs" end
end)
TargetModeBtn.MouseButton1Click:Connect(function() TargetModeBtn.Text = "Aura Target Mode: " .. KillAuraTargetMode end)

addSliderInput(CombatTab, "Aura Radius (Studs)", 1, 200, KillAuraRadius, function(val) KillAuraRadius = val end)
addSliderInput(CombatTab, "Attack Delay (Sec)", 0.05, 2, KillAuraDelay, function(val) KillAuraDelay = val end)

addToggle(CombatTab, "Weapon Reach (Hitbox Expander)", false, function(state) WeaponReachEnabled = state end)
addInputRow(CombatTab, "Reach Hitbox Size", WeaponReachSize, function(v) WeaponReachSize = v end)

-- ULTRA OPTIMIZED AIMBOT ENGINE
local function getClosestAimbotTarget()
    local char = LocalPlayer.Character
    if not char then return nil end

    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local candidateModels = {}

    if AimbotTargetMode == "Enemies" or AimbotTargetMode == "All Players" or AimbotTargetMode == "All" then
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local isEnemy = not isTeammate(plr)
                if (AimbotTargetMode == "All Players") or (AimbotTargetMode == "All") or (AimbotTargetMode == "Enemies" and (not IgnoreTeams or isEnemy)) then
                    table.insert(candidateModels, plr.Character)
                end
            end
        end
    end

    if AimbotTargetMode == "NPCs" or AimbotTargetMode == "All" then
        for _, npcModel in pairs(NPCCache) do
            table.insert(candidateModels, npcModel)
        end
    end

    local validCandidates = {}
    for _, model in pairs(candidateModels) do
        local hum = model:FindFirstChildOfClass("Humanoid")
        local targetPart = model:FindFirstChild(AimbotTargetPart) or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")

        if hum and hum.Health > 0 and targetPart then
            local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
            if onScreen then
                local dist2D = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                if dist2D <= FOVRadiusVal then
                    table.insert(validCandidates, {Part = targetPart, Model = model, Dist = dist2D})
                end
            end
        end
    end

    if #validCandidates == 0 then return nil end

    table.sort(validCandidates, function(a, b) return a.Dist < b.Dist end)

    if not WallCheck then return validCandidates[1].Part end

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    for _, cand in ipairs(validCandidates) do
        rayParams.FilterAncestorsInstances = {char, cand.Model}
        local origin = Camera.CFrame.Position
        local dir = cand.Part.Position - origin
        local hit = workspace:Raycast(origin, dir, rayParams)

        if not hit or not hit.Instance then
            return cand.Part
        end
    end

    return nil
end

Connections.AimbotLoop = RunService.RenderStepped:Connect(function()
    if FOVCircle then
        FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        FOVCircle.Visible = AimbotEnabled and ShowFOVCircle
        FOVCircle.Radius = FOVRadiusVal
    end

    if AimbotEnabled then
        local targetPart = getClosestAimbotTarget()
        if targetPart then
            local targetPos = targetPart.Position

            if VelocityPredictionEnabled and targetPart.Parent:FindFirstChild("HumanoidRootPart") then
                local hrp = targetPart.Parent.HumanoidRootPart
                local dist = (Camera.CFrame.Position - targetPos).Magnitude
                local timeToTarget = dist / 1000
                targetPos = targetPos + (hrp.AssemblyLinearVelocity * timeToTarget * PredictionScaleVal)
            end

            local targetCF = CFrame.new(Camera.CFrame.Position, targetPos)
            if SmoothnessVal > 0 then
                local lerpFactor = math.clamp(1 / (SmoothnessVal * 2), 0.05, 1)
                Camera.CFrame = Camera.CFrame:Lerp(targetCF, lerpFactor)
            else
                Camera.CFrame = targetCF
            end
        end
    end
end)

-- Mobile Fly & Movement Loops (FIXED HYBRID FLY LOOP)
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
                    if moveVector.X ~= 0 then
                        vel = vel + Camera.CFrame.RightVector * (moveVector.X * FlySpeedVal * 2.5)
                    end
                    if moveVector.Z ~= 0 then
                        vel = vel - Camera.CFrame.LookVector * (moveVector.Z * FlySpeedVal * 2.5)
                    end
                    bv.Velocity = vel
                end
            end
        end
    end
end)

Connections.TPWalkLoop = RunService.Heartbeat:Connect(function(delta)
    if TPWalkEnabled and LocalPlayer.Character then
        local char = LocalPlayer.Character
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.MoveDirection.Magnitude > 0 then
            char:TranslateBy(hum.MoveDirection * TPWalkVal * delta * 10)
        end
    end
end)

-- Kill Aura & Reach Loops
task.spawn(function()
    while true do
        if KillAuraEnabled then
            pcall(function()
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local tool = char and char:FindFirstChildOfClass("Tool")

                if hrp and tool then
                    local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildOfClass("BasePart")

                    local targets = {}
                    if KillAuraTargetMode == "Players" or KillAuraTargetMode == "All" then
                        for _, plr in pairs(Players:GetPlayers()) do
                            if plr ~= LocalPlayer and plr.Character then table.insert(targets, plr.Character) end
                        end
                    end
                    if KillAuraTargetMode == "NPCs" or KillAuraTargetMode == "All" then
                        for _, npc in pairs(NPCCache) do table.insert(targets, npc) end
                    end

                    for _, obj in pairs(targets) do
                        local targetHum = obj:FindFirstChildOfClass("Humanoid")
                        local targetPart = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso") or obj:FindFirstChild("Head")

                        if targetHum and targetHum.Health > 0 and targetPart then
                            local dist = (hrp.Position - targetPart.Position).Magnitude
                            if dist <= KillAuraRadius then
                                local targetPlr = Players:GetPlayerFromCharacter(obj)
                                local isEnemy = not isTeammate(targetPlr)
                                local validTarget = (KillAuraTargetMode == "All") or (KillAuraTargetMode == "NPCs" and not targetPlr) or (KillAuraTargetMode == "Players" and targetPlr and (not IgnoreTeams or isEnemy))

                                if validTarget then
                                    tool:Activate()
                                    if handle and firetouchinterest then
                                        firetouchinterest(handle, targetPart, 0)
                                        firetouchinterest(handle, targetPart, 1)
                                    end
                                end
                            end
                        end
                    end
                end
            end)
        end
        task.wait(KillAuraDelay)
    end
end)

Connections.WeaponReachLoop = RunService.RenderStepped:Connect(function()
    if WeaponReachEnabled and LocalPlayer.Character then
        local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if tool then
            local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildOfClass("BasePart")
            if handle then
                handle.Size = Vector3.new(WeaponReachSize, WeaponReachSize, WeaponReachSize)
                handle.Transparency = 0.7
                handle.Massless = true
            end
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
        if not AirwalkPart or not AirwalkPart.Parent then
            AirwalkPart = Instance.new("Part")
            AirwalkPart.Size = Vector3.new(6, 1, 6)
            AirwalkPart.Transparency = 1
            AirwalkPart.Anchored = true
            AirwalkPart.CanCollide = true
            AirwalkPart.Parent = workspace
        end
        AirwalkPart.CFrame = CFrame.new(hrp.Position.X, hrp.Position.Y - 3.5, hrp.Position.Z)
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

-- 6. TAB 3: WAYPOINT
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

addActionButton(WPTab, "Cancel Active Tween", Color3.fromRGB(50, 20, 20), function()
    if CurrentTweenObj then
        CurrentTweenObj:Cancel()
        CurrentTweenObj = nil
    end
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

local function renderWaypoints()
    for _, child in pairs(WPListFrame:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    for name, cf in pairs(Waypoints) do
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 28)
        card.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
        card.Parent = WPListFrame
        addCorner(card, 4)
        addStroke(card, Color3.fromRGB(22, 22, 30), 1)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.35, -5, 1, 0)
        lbl.Position = UDim2.new(0, 5, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = name
        lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        lbl.Font = Enum.Font.SourceSansBold
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = card

        local btnTP = Instance.new("TextButton")
        btnTP.Size = UDim2.new(0.18, 0, 0.8, 0)
        btnTP.Position = UDim2.new(0.36, 0, 0.1, 0)
        btnTP.BackgroundColor3 = Color3.fromRGB(10, 45, 25)
        btnTP.Text = "TP"
        btnTP.TextColor3 = Color3.fromRGB(255, 255, 255)
        btnTP.Font = Enum.Font.SourceSansBold
        btnTP.TextSize = 10
        btnTP.Parent = card
        addCorner(btnTP, 3)

        local btnTween = Instance.new("TextButton")
        btnTween.Size = UDim2.new(0.2, 0, 0.8, 0)
        btnTween.Position = UDim2.new(0.55, 0, 0.1, 0)
        btnTween.BackgroundColor3 = Color3.fromRGB(50, 35, 10)
        btnTween.Text = "Tween"
        btnTween.TextColor3 = Color3.fromRGB(255, 255, 255)
        btnTween.Font = Enum.Font.SourceSansBold
        btnTween.TextSize = 10
        btnTween.Parent = card
        addCorner(btnTween, 3)

        local btnDel = Instance.new("TextButton")
        btnDel.Size = UDim2.new(0.18, 0, 0.8, 0)
        btnDel.Position = UDim2.new(0.76, 0, 0.1, 0)
        btnDel.BackgroundColor3 = Color3.fromRGB(50, 15, 15)
        btnDel.Text = "Del"
        btnDel.TextColor3 = Color3.fromRGB(255, 255, 255)
        btnDel.Font = Enum.Font.SourceSansBold
        btnDel.TextSize = 10
        btnDel.Parent = card
        addCorner(btnDel, 3)

        btnTP.MouseButton1Click:Connect(function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                LocalPlayer.Character.HumanoidRootPart.CFrame = cf
            end
        end)

        btnTween.MouseButton1Click:Connect(function()
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local hrp = char.HumanoidRootPart
                local dist = (hrp.Position - cf.Position).Magnitude
                local time = dist / math.max(TweenSpeedVal, 1)
                if CurrentTweenObj then CurrentTweenObj:Cancel() end
                CurrentTweenObj = TweenService:Create(hrp, TweenInfo.new(time, Enum.EasingStyle.Linear), {CFrame = cf})
                CurrentTweenObj:Play()
            end
        end)

        btnDel.MouseButton1Click:Connect(function()
            Waypoints[name] = nil
            saveWaypointsToFile()
            renderWaypoints()
        end)
    end
end

WPAddBtn.MouseButton1Click:Connect(function()
    local name = WPInput.Text ~= "" and WPInput.Text or ("WP_" .. tostring(#WPListFrame:GetChildren()))
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        Waypoints[name] = char.HumanoidRootPart.CFrame
        WPInput.Text = ""
        saveWaypointsToFile()
        renderWaypoints()
    end
end)

if readfile and isfile and isfile(WaypointFileName) then
    pcall(function()
        local decoded = HttpService:JSONDecode(readfile(WaypointFileName))
        for name, cfTable in pairs(decoded) do Waypoints[name] = CFrame.new(unpack(cfTable)) end
        renderWaypoints()
    end)
end

-- 7. TAB 4: PLAYER
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
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
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

addActionButton(PlayerTab, "Refresh Player List", Color3.fromRGB(14, 14, 20), refreshPlayerList)

addActionButton(PlayerTab, "TP to Player", Color3.fromRGB(10, 45, 25), function()
    if SelectedPlayer and SelectedPlayer.Character and SelectedPlayer.Character:FindFirstChild("HumanoidRootPart") then
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.CFrame = SelectedPlayer.Character.HumanoidRootPart.CFrame
        end
    end
end)

addActionButton(PlayerTab, "Tween to Player", Color3.fromRGB(50, 35, 10), function()
    if SelectedPlayer and SelectedPlayer.Character and SelectedPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local hrp = char.HumanoidRootPart
            local targetCF = SelectedPlayer.Character.HumanoidRootPart.CFrame
            local dist = (hrp.Position - targetCF.Position).Magnitude
            local time = dist / math.max(TweenSpeedVal, 1)
            if CurrentTweenObj then CurrentTweenObj:Cancel() end
            CurrentTweenObj = TweenService:Create(hrp, TweenInfo.new(time, Enum.EasingStyle.Linear), {CFrame = targetCF})
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

-- 8. TAB 5: VISUAL (DYNAMIC FULLBRIGHT, NOFOG & CHAMS ESP)
local function getChamColor(plr)
    if isTeammate(plr) then
        return Color3.fromRGB(0, 255, 120)
    else
        return Color3.fromRGB(0, 229, 255)
    end
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
        if ChamsEnabled then
            task.wait(0.5)
            applyChams(plr)
        end
    end)
    if plr.Character then
        applyChams(plr)
    end
end

for _, plr in pairs(Players:GetPlayers()) do setupPlayerListeners(plr) end
Connections.PlayerAddedChams = Players.PlayerAdded:Connect(setupPlayerListeners)

task.spawn(function()
    while true do
        if ChamsEnabled then
            for _, plr in pairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    applyChams(plr)
                end
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

        -- Dynamic Listeners: Menolak perubahan lighting malam/gelap dari script game
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
    for _, v in pairs(game.Lighting:GetDescendants()) do
        if v:IsA("Atmosphere") then v.Density = 0 end
    end
end

addToggle(VisualTab, "NoFog", false, function(state)
    NoFogEnabled = state

    for _, conn in pairs(NoFogConns) do conn:Disconnect() end
    table.clear(NoFogConns)

    if NoFogEnabled then
        applyNoFog()

        -- Dynamic Listeners: Jaga FogEnd dan matikan Atmosphere baru
        table.insert(NoFogConns, game.Lighting:GetPropertyChangedSignal("FogEnd"):Connect(applyNoFog))
        table.insert(NoFogConns, game.Lighting.ChildAdded:Connect(function(child)
            if child:IsA("Atmosphere") then child.Density = 0 end
        end))
        table.insert(NoFogConns, workspace.DescendantAdded:Connect(function(desc)
            if NoFogEnabled and desc:IsA("Atmosphere") then desc.Density = 0 end
        end))
    else
        game.Lighting.FogEnd = DefaultLighting.FogEnd
    end
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

addToggle(VisualTab, "Unlock MaxZoom", false, function(state)
    MaxZoomEnabled = state
    LocalPlayer.CameraMaxZoomDistance = state and 99999 or 128
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

-- 9. TAB 6: UTILITY & DEV TOOLS
addToggle(UtilTab, "Anti Gameplay Pause", false, function(state)
    AntiGameplayPauseEnabled = state
    pcall(function() GuiService:SetGameplayPausedNotificationEnabled(not state) end)
end)

addToggle(UtilTab, "Anti-Knockback", false, function(state) AntiKnockbackEnabled = state end)
addToggle(UtilTab, "Anti-Ragdoll", false, function(state) AntiRagdollEnabled = state end)

Connections.AntiKnockbackLoop = RunService.Heartbeat:Connect(function()
    if AntiKnockbackEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = LocalPlayer.Character.HumanoidRootPart
        if hrp.AssemblyLinearVelocity.Magnitude > 100 then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end
end)

Connections.AntiRagdollLoop = RunService.Stepped:Connect(function()
    if AntiRagdollEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        local state = hum:GetState()
        if state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown then
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end
end)

addInputRow(UtilTab, "Prompt Trigger Radius", PromptRadiusVal, function(v) PromptRadiusVal = v end)
addToggle(UtilTab, "Auto-Trigger Prompt", false, function(state) AutoPromptEnabled = state end)

task.spawn(function()
    while true do
        if AutoPromptEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = LocalPlayer.Character.HumanoidRootPart
            for _, prompt in pairs(workspace:GetDescendants()) do
                if prompt:IsA("ProximityPrompt") and prompt.Parent and prompt.Parent:IsA("BasePart") then
                    local dist = (hrp.Position - prompt.Parent.Position).Magnitude
                    if dist <= PromptRadiusVal and fireproximityprompt then
                        fireproximityprompt(prompt)
                    end
                end
            end
        end
        task.wait(0.2)
    end
end)

-- DYNAMIC INSTANT PROXIMITY PROMPT ENGINE
local function applyInstantPrompt(prompt)
    if prompt:IsA("ProximityPrompt") then
        prompt.HoldDuration = 0
    end
end

addToggle(UtilTab, "Instant Proximity Prompt", false, function(state)
    InstantPromptEnabled = state

    if InstantPromptConn then
        InstantPromptConn:Disconnect()
        InstantPromptConn = nil
    end

    if state then
        -- 1. Terapkan ke prompt yang sudah ada
        for _, desc in pairs(workspace:GetDescendants()) do
            applyInstantPrompt(desc)
        end
        -- 2. Dynamic Listener: Terapkan otomatis ke prompt baru yang di-load
        InstantPromptConn = workspace.DescendantAdded:Connect(function(desc)
            if InstantPromptEnabled then
                applyInstantPrompt(desc)
            end
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
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/infyiff/backup/main/dex.lua"))()
    end)
end)

addActionButton(UtilTab, "Launch Cobalt RSpy", Color3.fromRGB(12, 30, 50), function()
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/GOTROBLOX/Cobalt/main/Cobalt.lua"))()
    end)
end)

addActionButton(UtilTab, "Smallest Server Hop", Color3.fromRGB(12, 35, 55), function()
    pcall(function()
        local http = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
        for _, server in pairs(http.data) do
            if server.playing < server.maxPlayers and server.id ~= game.JobId then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
                break
            end
        end
    end)
end)

addActionButton(UtilTab, "Server Hop", Color3.fromRGB(20, 25, 40), function()
    TeleportService:Teleport(game.PlaceId, LocalPlayer)
end)

addActionButton(UtilTab, "Rejoin", Color3.fromRGB(40, 25, 50), function()
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end)

addActionButton(UtilTab, "Save Config Per-Game", Color3.fromRGB(10, 45, 25), function()
    if writefile then
        local cfg = {
            WalkSpeedVal = WalkSpeedVal,
            TPWalkVal = TPWalkVal,
            JumpPowerVal = JumpPowerVal,
            HipHeightVal = HipHeightVal,
            GravityVal = GravityVal,
            KillAuraRadius = KillAuraRadius,
            KillAuraDelay = KillAuraDelay,
            KillAuraTargetMode = KillAuraTargetMode,
            WeaponReachSize = WeaponReachSize,
            PromptRadiusVal = PromptRadiusVal,
            FOVRadiusVal = FOVRadiusVal,
            SmoothnessVal = SmoothnessVal,
            PredictionScaleVal = PredictionScaleVal,
            IgnoreTeams = IgnoreTeams,
            WallCheck = WallCheck
        }
        pcall(function() writefile(ConfigFileName, HttpService:JSONEncode(cfg)) end)
    end
end)

-- Auto-Load Config Per-Game
if readfile and isfile and isfile(ConfigFileName) then
    pcall(function()
        local cfg = HttpService:JSONDecode(readfile(ConfigFileName))
        if cfg.WalkSpeedVal then WalkSpeedVal = cfg.WalkSpeedVal end
        if cfg.TPWalkVal then TPWalkVal = cfg.TPWalkVal end
        if cfg.JumpPowerVal then JumpPowerVal = cfg.JumpPowerVal end
        if cfg.HipHeightVal then HipHeightVal = cfg.HipHeightVal end
        if cfg.GravityVal then GravityVal = cfg.GravityVal end
        if cfg.KillAuraRadius then KillAuraRadius = cfg.KillAuraRadius end
        if cfg.KillAuraDelay then KillAuraDelay = cfg.KillAuraDelay end
        if cfg.KillAuraTargetMode then KillAuraTargetMode = cfg.KillAuraTargetMode end
        if cfg.WeaponReachSize then WeaponReachSize = cfg.WeaponReachSize end
        if cfg.PromptRadiusVal then PromptRadiusVal = cfg.PromptRadiusVal end
        if cfg.FOVRadiusVal then FOVRadiusVal = cfg.FOVRadiusVal end
        if cfg.SmoothnessVal then SmoothnessVal = cfg.SmoothnessVal end
        if cfg.PredictionScaleVal then PredictionScaleVal = cfg.PredictionScaleVal end
        if cfg.IgnoreTeams ~= nil then IgnoreTeams = cfg.IgnoreTeams end
        if cfg.WallCheck ~= nil then WallCheck = cfg.WallCheck end
    end)
end

addActionButton(UtilTab, "UNLOAD SCRIPT", Color3.fromRGB(60, 15, 15), function()
    if _G.FEUtilityCleanup then _G.FEUtilityCleanup() end
end)

-- 10. TOGGLE & CLEANUP BINDINGS
CloseBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false end)
ToggleBtn.MouseButton1Click:Connect(function() MainFrame.Visible = not MainFrame.Visible end)

_G.FEUtilityCleanup = function()
    AimbotEnabled = false
    KillAuraEnabled = false
    TPWalkEnabled = false
    WallTPEnabled = false
    AutoPromptEnabled = false
    ChamsEnabled = false
    FlyEnabled = false
    FullbrightEnabled = false
    NoFogEnabled = false
    InstantPromptEnabled = false

    stopFly()
    disableWallTP()
    removeChams()

    if InstantPromptConn then
        InstantPromptConn:Disconnect()
        InstantPromptConn = nil
    end

    for _, conn in pairs(FullbrightConns) do conn:Disconnect() end
    for _, conn in pairs(NoFogConns) do conn:Disconnect() end
    table.clear(FullbrightConns)
    table.clear(NoFogConns)

    if FOVCircle then
        pcall(function() FOVCircle:Remove() end)
    end

    for _, conn in pairs(Connections) do
        if conn and conn.Connected then conn:Disconnect() end
    end

    for _, e in pairs(ESPLabels) do e:Destroy() end

    if FloatBV then FloatBV:Destroy() end
    if FloatBG then FloatBG:Destroy() end
    if AirwalkPart then AirwalkPart:Destroy() end

    pcall(function() GuiService:SetGameplayPausedNotificationEnabled(true) end)

    ScreenGui:Destroy()
    _G.FEUtilityCleanup = nil
end
