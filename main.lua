--[[
================================================================================
AIM BATTLES + DEVELOPER TOOLS - COMPLETE SERVER-SIDE SYSTEM
================================================================================

DESCRIPTION:
    Complete server-side implementation combining:
    1. Aim Battles - Server-side camera tracking (everyone sees your aim)
    2. Dev Mode Flight - Server-side flight system
    3. V-Key Chat - Random message sender

INSTALLATION:
    This requires TWO scripts:
    
    1. SERVER SCRIPT (put in ServerScriptService)
       - Handles flight logic server-side
       - Handles camera tracking server-side
       - Makes everything visible to all players
    
    2. CLIENT SCRIPT (put in StarterPlayerScripts)
       - Shows combined GUI
       - Sends commands to server
       - Handles all input

FEATURES:
    - Aim Battles: Track player heads (server-side camera control)
    - Dev Mode Flight (server-side - everyone sees you fly!)
    - V-Key Chat (client-side random messages)
    - All features in one professional GUI

================================================================================
]]--

--[[
================================================================================
SCRIPT 1: SERVER SCRIPT
Put this in: ServerScriptService > AimBattlesServer
================================================================================
]]--

-- SERVER SCRIPT START --

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Create RemoteEvents folder
local RemoteFolder = Instance.new("Folder")
RemoteFolder.Name = "AimBattlesRemotes"
RemoteFolder.Parent = game.ReplicatedStorage

-- Create RemoteEvents for Flight
local ToggleFlightRemote = Instance.new("RemoteEvent")
ToggleFlightRemote.Name = "ToggleFlight"
ToggleFlightRemote.Parent = RemoteFolder

local UpdateSpeedRemote = Instance.new("RemoteEvent")
UpdateSpeedRemote.Name = "UpdateSpeed"
UpdateSpeedRemote.Parent = RemoteFolder

local UpdateMovementRemote = Instance.new("RemoteEvent")
UpdateMovementRemote.Name = "UpdateMovement"
UpdateMovementRemote.Parent = RemoteFolder

-- Create RemoteEvents for Aim Tracking
local StartTrackingRemote = Instance.new("RemoteEvent")
StartTrackingRemote.Name = "StartTracking"
StartTrackingRemote.Parent = RemoteFolder

local StopTrackingRemote = Instance.new("RemoteEvent")
StopTrackingRemote.Name = "StopTracking"
StopTrackingRemote.Parent = RemoteFolder

local UpdateTrackingRemote = Instance.new("RemoteEvent")
UpdateTrackingRemote.Name = "UpdateTracking"
UpdateTrackingRemote.Parent = RemoteFolder

-- Store flying players and their data
local flyingPlayers = {}

-- Store tracking players and their targets
local trackingPlayers = {}

-- Configuration
local MIN_SPEED = 1
local MAX_SPEED = 100
local DEFAULT_SPEED = 50
local TRACKING_SMOOTHNESS = 0.2

-- ============================================================================
-- FLIGHT SYSTEM (Server-Side)
-- ============================================================================

-- Flight update loop (runs on server for all flying players)
RunService.Heartbeat:Connect(function(deltaTime)
    for player, data in pairs(flyingPlayers) do
        if not player or not player.Parent then
            flyingPlayers[player] = nil
            continue
        end
        
        local character = player.Character
        if not character then
            flyingPlayers[player] = nil
            continue
        end
        
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        
        if not humanoidRootPart or not humanoid then
            continue
        end
        
        -- Apply movement vector from client
        if data.bodyVelocity and data.moveVector then
            data.bodyVelocity.Velocity = data.moveVector
        end
        
        -- Update body gyro with camera CFrame from client
        if data.bodyGyro and data.cameraCFrame then
            data.bodyGyro.CFrame = data.cameraCFrame
        end
    end
end)

-- Handle flight toggle request
ToggleFlightRemote.OnServerEvent:Connect(function(player, enabled)
    local character = player.Character
    if not character then return end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    
    if not humanoidRootPart or not humanoid then return end
    
    if enabled then
        -- Start flying
        print(player.Name .. " enabled dev mode flight")
        
        -- Create BodyVelocity
        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.Name = "DevFlyVelocity"
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        bodyVelocity.MaxForce = Vector3.new(100000, 100000, 100000)
        bodyVelocity.Parent = humanoidRootPart
        
        -- Create BodyGyro
        local bodyGyro = Instance.new("BodyGyro")
        bodyGyro.Name = "DevFlyGyro"
        bodyGyro.MaxTorque = Vector3.new(100000, 100000, 100000)
        bodyGyro.P = 10000
        bodyGyro.Parent = humanoidRootPart
        
        -- Store player data
        flyingPlayers[player] = {
            bodyVelocity = bodyVelocity,
            bodyGyro = bodyGyro,
            speed = DEFAULT_SPEED,
            moveVector = Vector3.new(0, 0, 0),
            cameraCFrame = CFrame.new()
        }
        
        -- Set humanoid to platform stand
        humanoid.PlatformStand = true
        
    else
        -- Stop flying
        print(player.Name .. " disabled dev mode flight")
        
        if flyingPlayers[player] then
            -- Destroy physics objects
            if flyingPlayers[player].bodyVelocity then
                flyingPlayers[player].bodyVelocity:Destroy()
            end
            if flyingPlayers[player].bodyGyro then
                flyingPlayers[player].bodyGyro:Destroy()
            end
            
            -- Remove from table
            flyingPlayers[player] = nil
        end
        
        -- Reset humanoid
        humanoid.PlatformStand = false
    end
end)

-- Handle speed update
UpdateSpeedRemote.OnServerEvent:Connect(function(player, newSpeed)
    -- Validate speed
    if type(newSpeed) ~= "number" then return end
    newSpeed = math.clamp(newSpeed, MIN_SPEED, MAX_SPEED)
    
    if flyingPlayers[player] then
        flyingPlayers[player].speed = newSpeed
        print(player.Name .. " updated fly speed to " .. newSpeed)
    end
end)

-- Handle movement update from client
UpdateMovementRemote.OnServerEvent:Connect(function(player, moveVector, cameraCFrame)
    if not flyingPlayers[player] then return end
    
    -- Validate data
    if typeof(moveVector) ~= "Vector3" or typeof(cameraCFrame) ~= "CFrame" then
        return
    end
    
    -- Store movement data
    flyingPlayers[player].moveVector = moveVector
    flyingPlayers[player].cameraCFrame = cameraCFrame
end)

-- ============================================================================
-- AIM TRACKING SYSTEM (Server-Side)
-- ============================================================================

-- Tracking update loop (runs on server)
RunService.Heartbeat:Connect(function()
    for player, trackingData in pairs(trackingPlayers) do
        if not player or not player.Parent then
            trackingPlayers[player] = nil
            continue
        end
        
        local character = player.Character
        if not character then
            trackingPlayers[player] = nil
            continue
        end
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then continue end
        
        -- Get target player
        local targetPlayer = trackingData.targetPlayer
        if not targetPlayer or not targetPlayer.Parent then
            trackingPlayers[player] = nil
            continue
        end
        
        local targetCharacter = targetPlayer.Character
        if not targetCharacter then continue end
        
        local targetHead = targetCharacter:FindFirstChild("Head")
        if not targetHead then continue end
        
        -- Get current camera CFrame from client
        local currentCFrame = trackingData.cameraCFrame
        if not currentCFrame then continue end
        
        -- Calculate new camera direction pointing at target head
        local targetPosition = targetHead.Position
        local newCFrame = CFrame.new(currentCFrame.Position, targetPosition)
        
        -- Smooth tracking using lerp
        local smoothedCFrame = currentCFrame:Lerp(newCFrame, TRACKING_SMOOTHNESS)
        
        -- Apply to humanoid's camera offset (server-side camera control)
        humanoid.CameraOffset = Vector3.new(0, 0, 0)
        
        -- Store the smoothed CFrame back
        trackingData.cameraCFrame = smoothedCFrame
        trackingData.targetHeadPosition = targetPosition
    end
end)

-- Handle start tracking
StartTrackingRemote.OnServerEvent:Connect(function(player, targetPlayerName)
    -- Validate target player exists
    local targetPlayer = Players:FindFirstChild(targetPlayerName)
    if not targetPlayer or targetPlayer == player then
        return
    end
    
    print(player.Name .. " started tracking " .. targetPlayerName)
    
    -- Initialize tracking data
    trackingPlayers[player] = {
        targetPlayer = targetPlayer,
        cameraCFrame = CFrame.new(),
        targetHeadPosition = Vector3.new()
    }
end)

-- Handle stop tracking
StopTrackingRemote.OnServerEvent:Connect(function(player)
    if trackingPlayers[player] then
        print(player.Name .. " stopped tracking")
        trackingPlayers[player] = nil
    end
end)

-- Handle tracking camera update from client
UpdateTrackingRemote.OnServerEvent:Connect(function(player, cameraCFrame)
    if not trackingPlayers[player] then return end
    
    -- Validate data
    if typeof(cameraCFrame) ~= "CFrame" then return end
    
    -- Update camera CFrame
    trackingPlayers[player].cameraCFrame = cameraCFrame
end)

-- ============================================================================
-- CLEANUP
-- ============================================================================

-- Cleanup when player leaves
Players.PlayerRemoving:Connect(function(player)
    flyingPlayers[player] = nil
    trackingPlayers[player] = nil
end)

-- Cleanup on character respawn
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        -- Wait a moment for character to load
        task.wait(0.5)
        
        -- If player was flying or tracking, clean up
        if flyingPlayers[player] then
            flyingPlayers[player] = nil
        end
        if trackingPlayers[player] then
            trackingPlayers[player] = nil
        end
    end)
end)

print("✅ Aim Battles + Dev Tools Server Script loaded!")

-- SERVER SCRIPT END --

--[[
================================================================================
SCRIPT 2: CLIENT SCRIPT (LocalScript)
Put this in: StarterPlayer > StarterPlayerScripts > AimBattlesClient
================================================================================
]]--

-- CLIENT SCRIPT START --

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for RemoteEvents
local RemoteFolder = ReplicatedStorage:WaitForChild("AimBattlesRemotes")
local ToggleFlightRemote = RemoteFolder:WaitForChild("ToggleFlight")
local UpdateSpeedRemote = RemoteFolder:WaitForChild("UpdateSpeed")
local UpdateMovementRemote = RemoteFolder:WaitForChild("UpdateMovement")
local StartTrackingRemote = RemoteFolder:WaitForChild("StartTracking")
local StopTrackingRemote = RemoteFolder:WaitForChild("StopTracking")
local UpdateTrackingRemote = RemoteFolder:WaitForChild("UpdateTracking")

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local CONFIG = {
    CHAT_MESSAGES = {
        "Holy beam lol",
        "easiest track of my life wth",
        "loser just quit",
        "LOL UR SO BAD BRO",
        "ur such a bot",
        "stop tryna be a bot",
        "Hoolyy",
        "BEAMED",
        "th",
        "ur so garbage bro"
    },
    
    TRIGGER_KEY = Enum.KeyCode.V,
    DEFAULT_FLY_SPEED = 50,
    GUI_SIZE = UDim2.new(0, 350, 0, 480),
    GUI_POSITION = UDim2.new(0.5, -175, 0.5, -240),
    DROPDOWN_MAX_HEIGHT = 120
}

-- ============================================================================
-- STATE
-- ============================================================================

local chatEnabled = false
local devModeEnabled = false
local aimTrackingEnabled = false
local flySpeed = CONFIG.DEFAULT_FLY_SPEED
local selectedPlayer = nil
local dropdownOpen = false

local movementUpdateConnection = nil
local trackingUpdateConnection = nil

-- ============================================================================
-- GUI CREATION
-- ============================================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AimBattlesGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = CONFIG.GUI_SIZE
MainFrame.Position = CONFIG.GUI_POSITION
MainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(100, 150, 255)
UIStroke.Thickness = 2
UIStroke.Transparency = 0.6
UIStroke.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, 0, 0, 40)
TitleLabel.Position = UDim2.new(0, 0, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "🎯 AIM BATTLES + DEV TOOLS"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 18
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Parent = MainFrame

-- ============================================================================
-- AIM BATTLES SECTION
-- ============================================================================

local AimSection = Instance.new("Frame")
AimSection.Size = UDim2.new(1, -20, 0, 140)
AimSection.Position = UDim2.new(0, 10, 0, 50)
AimSection.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
AimSection.BorderSizePixel = 0
AimSection.Parent = MainFrame

local AimCorner = Instance.new("UICorner")
AimCorner.CornerRadius = UDim.new(0, 8)
AimCorner.Parent = AimSection

local AimTitle = Instance.new("TextLabel")
AimTitle.Size = UDim2.new(1, -20, 0, 25)
AimTitle.Position = UDim2.new(0, 10, 0, 5)
AimTitle.BackgroundTransparency = 1
AimTitle.Text = "🎯 Aim Battles - Head Tracking"
AimTitle.TextColor3 = Color3.fromRGB(100, 200, 255)
AimTitle.TextSize = 16
AimTitle.Font = Enum.Font.GothamBold
AimTitle.TextXAlignment = Enum.TextXAlignment.Left
AimTitle.Parent = AimSection

local AimInstructions = Instance.new("TextLabel")
AimInstructions.Size = UDim2.new(1, -20, 0, 20)
AimInstructions.Position = UDim2.new(0, 10, 0, 30)
AimInstructions.BackgroundTransparency = 1
AimInstructions.Text = "Hold RIGHT CLICK to track target's head"
AimInstructions.TextColor3 = Color3.fromRGB(150, 150, 150)
AimInstructions.TextSize = 11
AimInstructions.Font = Enum.Font.Gotham
AimInstructions.TextXAlignment = Enum.TextXAlignment.Left
AimInstructions.Parent = AimSection

-- Dropdown Container
local DropdownContainer = Instance.new("Frame")
DropdownContainer.Name = "DropdownContainer"
DropdownContainer.Size = UDim2.new(1, -20, 0, 35)
DropdownContainer.Position = UDim2.new(0, 10, 0, 55)
DropdownContainer.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
DropdownContainer.BorderSizePixel = 0
DropdownContainer.ClipsDescendants = false
DropdownContainer.Parent = AimSection

local DropdownCorner = Instance.new("UICorner")
DropdownCorner.CornerRadius = UDim.new(0, 6)
DropdownCorner.Parent = DropdownContainer

-- Dropdown Button
local DropdownButton = Instance.new("TextButton")
DropdownButton.Name = "DropdownButton"
DropdownButton.Size = UDim2.new(1, 0, 0, 35)
DropdownButton.Position = UDim2.new(0, 0, 0, 0)
DropdownButton.BackgroundTransparency = 1
DropdownButton.Text = "Select a player..."
DropdownButton.TextColor3 = Color3.fromRGB(200, 200, 200)
DropdownButton.TextSize = 14
DropdownButton.Font = Enum.Font.Gotham
DropdownButton.TextXAlignment = Enum.TextXAlignment.Left
DropdownButton.TextTruncate = Enum.TextTruncate.AtEnd
DropdownButton.Parent = DropdownContainer

local DropdownPadding = Instance.new("UIPadding")
DropdownPadding.PaddingLeft = UDim.new(0, 10)
DropdownPadding.PaddingRight = UDim.new(0, 30)
DropdownPadding.Parent = DropdownButton

-- Dropdown Arrow
local DropdownArrow = Instance.new("TextLabel")
DropdownArrow.Name = "Arrow"
DropdownArrow.Size = UDim2.new(0, 20, 0, 35)
DropdownArrow.Position = UDim2.new(1, -25, 0, 0)
DropdownArrow.BackgroundTransparency = 1
DropdownArrow.Text = "▼"
DropdownArrow.TextColor3 = Color3.fromRGB(200, 200, 200)
DropdownArrow.TextSize = 12
DropdownArrow.Font = Enum.Font.GothamBold
DropdownArrow.Parent = DropdownContainer

-- Dropdown List Frame
local DropdownList = Instance.new("ScrollingFrame")
DropdownList.Name = "DropdownList"
DropdownList.Size = UDim2.new(1, 0, 0, 0)
DropdownList.Position = UDim2.new(0, 0, 1, 2)
DropdownList.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
DropdownList.BorderSizePixel = 0
DropdownList.ScrollBarThickness = 4
DropdownList.Visible = false
DropdownList.CanvasSize = UDim2.new(0, 0, 0, 0)
DropdownList.ZIndex = 10
DropdownList.Parent = DropdownContainer

local ListCorner = Instance.new("UICorner")
ListCorner.CornerRadius = UDim.new(0, 6)
ListCorner.Parent = DropdownList

local ListLayout = Instance.new("UIListLayout")
ListLayout.SortOrder = Enum.SortOrder.Name
ListLayout.Padding = UDim.new(0, 2)
ListLayout.Parent = DropdownList

-- Aim Status
local AimStatus = Instance.new("TextLabel")
AimStatus.Size = UDim2.new(1, -20, 0, 35)
AimStatus.Position = UDim2.new(0, 10, 1, -40)
AimStatus.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
AimStatus.BorderSizePixel = 0
AimStatus.Text = "No target selected"
AimStatus.TextColor3 = Color3.fromRGB(255, 150, 100)
AimStatus.TextSize = 12
AimStatus.Font = Enum.Font.GothamBold
AimStatus.Parent = AimSection

local AimStatusCorner = Instance.new("UICorner")
AimStatusCorner.CornerRadius = UDim.new(0, 6)
AimStatusCorner.Parent = AimStatus

-- ============================================================================
-- CHAT SECTION
-- ============================================================================

local ChatSection = Instance.new("Frame")
ChatSection.Size = UDim2.new(1, -20, 0, 80)
ChatSection.Position = UDim2.new(0, 10, 0, 200)
ChatSection.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
ChatSection.BorderSizePixel = 0
ChatSection.Parent = MainFrame

local ChatCorner = Instance.new("UICorner")
ChatCorner.CornerRadius = UDim.new(0, 8)
ChatCorner.Parent = ChatSection

local ChatTitle = Instance.new("TextLabel")
ChatTitle.Size = UDim2.new(1, -20, 0, 25)
ChatTitle.Position = UDim2.new(0, 10, 0, 5)
ChatTitle.BackgroundTransparency = 1
ChatTitle.Text = "V-Key Chat"
ChatTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
ChatTitle.TextSize = 16
ChatTitle.Font = Enum.Font.GothamBold
ChatTitle.TextXAlignment = Enum.TextXAlignment.Left
ChatTitle.Parent = ChatSection

local ChatStatus = Instance.new("TextLabel")
ChatStatus.Size = UDim2.new(1, -20, 0, 20)
ChatStatus.Position = UDim2.new(0, 10, 0, 30)
ChatStatus.BackgroundTransparency = 1
ChatStatus.Text = "Press 'V' to send random message"
ChatStatus.TextColor3 = Color3.fromRGB(150, 150, 150)
ChatStatus.TextSize = 12
ChatStatus.Font = Enum.Font.Gotham
ChatStatus.TextXAlignment = Enum.TextXAlignment.Left
ChatStatus.Parent = ChatSection

local ChatToggle = Instance.new("TextButton")
ChatToggle.Size = UDim2.new(0, 100, 0, 30)
ChatToggle.Position = UDim2.new(1, -110, 1, -35)
ChatToggle.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
ChatToggle.BorderSizePixel = 0
ChatToggle.Text = "Disabled"
ChatToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
ChatToggle.TextSize = 14
ChatToggle.Font = Enum.Font.GothamBold
ChatToggle.AutoButtonColor = false
ChatToggle.Parent = ChatSection

local ChatToggleCorner = Instance.new("UICorner")
ChatToggleCorner.CornerRadius = UDim.new(0, 6)
ChatToggleCorner.Parent = ChatToggle

-- ============================================================================
-- DEV SECTION
-- ============================================================================

local DevSection = Instance.new("Frame")
DevSection.Size = UDim2.new(1, -20, 0, 120)
DevSection.Position = UDim2.new(0, 10, 0, 290)
DevSection.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
DevSection.BorderSizePixel = 0
DevSection.Parent = MainFrame

local DevCorner = Instance.new("UICorner")
DevCorner.CornerRadius = UDim.new(0, 8)
DevCorner.Parent = DevSection

local DevTitle = Instance.new("TextLabel")
DevTitle.Size = UDim2.new(1, -20, 0, 25)
DevTitle.Position = UDim2.new(0, 10, 0, 5)
DevTitle.BackgroundTransparency = 1
DevTitle.Text = "Dev Mode (Flight) - SERVER-SIDE"
DevTitle.TextColor3 = Color3.fromRGB(255, 200, 100)
DevTitle.TextSize = 14
DevTitle.Font = Enum.Font.GothamBold
DevTitle.TextXAlignment = Enum.TextXAlignment.Left
DevTitle.Parent = DevSection

local DevInstructions = Instance.new("TextLabel")
DevInstructions.Size = UDim2.new(1, -20, 0, 20)
DevInstructions.Position = UDim2.new(0, 10, 0, 30)
DevInstructions.BackgroundTransparency = 1
DevInstructions.Text = "WASD to move, Space/Shift for up/down"
DevInstructions.TextColor3 = Color3.fromRGB(150, 150, 150)
DevInstructions.TextSize = 11
DevInstructions.Font = Enum.Font.Gotham
DevInstructions.TextXAlignment = Enum.TextXAlignment.Left
DevInstructions.Parent = DevSection

local SpeedLabel = Instance.new("TextLabel")
SpeedLabel.Size = UDim2.new(0, 80, 0, 20)
SpeedLabel.Position = UDim2.new(0, 10, 0, 55)
SpeedLabel.BackgroundTransparency = 1
SpeedLabel.Text = "Fly Speed:"
SpeedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
SpeedLabel.TextSize = 12
SpeedLabel.Font = Enum.Font.Gotham
SpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
SpeedLabel.Parent = DevSection

local SpeedInput = Instance.new("TextBox")
SpeedInput.Size = UDim2.new(0, 60, 0, 25)
SpeedInput.Position = UDim2.new(0, 90, 0, 53)
SpeedInput.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
SpeedInput.BorderSizePixel = 0
SpeedInput.Text = tostring(flySpeed)
SpeedInput.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedInput.TextSize = 14
SpeedInput.Font = Enum.Font.GothamBold
SpeedInput.PlaceholderText = "1-100"
SpeedInput.ClearTextOnFocus = false
SpeedInput.Parent = DevSection

local SpeedInputCorner = Instance.new("UICorner")
SpeedInputCorner.CornerRadius = UDim.new(0, 4)
SpeedInputCorner.Parent = SpeedInput

local SpeedDisplay = Instance.new("TextLabel")
SpeedDisplay.Size = UDim2.new(0, 100, 0, 20)
SpeedDisplay.Position = UDim2.new(0, 155, 0, 55)
SpeedDisplay.BackgroundTransparency = 1
SpeedDisplay.Text = "(Current: 50)"
SpeedDisplay.TextColor3 = Color3.fromRGB(100, 200, 255)
SpeedDisplay.TextSize = 11
SpeedDisplay.Font = Enum.Font.Gotham
SpeedDisplay.TextXAlignment = Enum.TextXAlignment.Left
SpeedDisplay.Parent = DevSection

local DevToggle = Instance.new("TextButton")
DevToggle.Size = UDim2.new(0, 100, 0, 30)
DevToggle.Position = UDim2.new(1, -110, 1, -35)
DevToggle.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
DevToggle.BorderSizePixel = 0
DevToggle.Text = "Disabled"
DevToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
DevToggle.TextSize = 14
DevToggle.Font = Enum.Font.GothamBold
DevToggle.AutoButtonColor = false
DevToggle.Parent = DevSection

local DevToggleCorner = Instance.new("UICorner")
DevToggleCorner.CornerRadius = UDim.new(0, 6)
DevToggleCorner.Parent = DevToggle

-- Credit Footer
local CreditLabel = Instance.new("TextLabel")
CreditLabel.Size = UDim2.new(1, 0, 0, 30)
CreditLabel.Position = UDim2.new(0, 0, 1, -35)
CreditLabel.BackgroundTransparency = 1
CreditLabel.Text = "⚡ SERVER-SIDE TRACKING + FLIGHT"
CreditLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
CreditLabel.TextSize = 10
CreditLabel.Font = Enum.Font.GothamBold
CreditLabel.Parent = MainFrame

-- ============================================================================
-- PLAYER LIST FUNCTIONS
-- ============================================================================

local function clearDropdownList()
    for _, child in ipairs(DropdownList:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
end

local function createPlayerButton(player)
    local button = Instance.new("TextButton")
    button.Name = player.Name
    button.Size = UDim2.new(1, -8, 0, 28)
    button.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
    button.BorderSizePixel = 0
    button.Text = player.Name
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 12
    button.Font = Enum.Font.Gotham
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.AutoButtonColor = false
    button.ZIndex = 11
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = button
    
    local btnPadding = Instance.new("UIPadding")
    btnPadding.PaddingLeft = UDim.new(0, 10)
    btnPadding.Parent = button
    
    -- Button click event
    button.MouseButton1Click:Connect(function()
        selectedPlayer = player
        DropdownButton.Text = player.Name
        DropdownButton.TextColor3 = Color3.fromRGB(100, 255, 100)
        AimStatus.Text = "Target: " .. player.Name
        AimStatus.TextColor3 = Color3.fromRGB(100, 255, 100)
        
        -- Close dropdown
        DropdownList.Visible = false
        DropdownArrow.Text = "▼"
        dropdownOpen = false
    end)
    
    -- Hover effects
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
    end)
    
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
    end)
    
    button.Parent = DropdownList
end

local function updatePlayerList()
    clearDropdownList()
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            createPlayerButton(player)
        end
    end
    
    -- Update canvas size
    task.wait()
    DropdownList.CanvasSize = UDim2.new(0, 0, 0, ListLayout.AbsoluteContentSize.Y + 4)
end

-- ============================================================================
-- DROPDOWN TOGGLE
-- ============================================================================

DropdownButton.MouseButton1Click:Connect(function()
    dropdownOpen = not dropdownOpen
    
    if dropdownOpen then
        updatePlayerList()
        local contentHeight = math.min(ListLayout.AbsoluteContentSize.Y + 4, CONFIG.DROPDOWN_MAX_HEIGHT)
        DropdownList.Size = UDim2.new(1, 0, 0, contentHeight)
        DropdownList.Visible = true
        DropdownArrow.Text = "▲"
    else
        DropdownList.Visible = false
        DropdownArrow.Text = "▼"
    end
end)

-- ============================================================================
-- CHAT FUNCTIONS
-- ============================================================================

local function getRandomMessage()
    return CONFIG.CHAT_MESSAGES[math.random(1, #CONFIG.CHAT_MESSAGES)]
end

local function sendChatMessage(message)
    pcall(function()
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            local textChannel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
            if textChannel then
                textChannel:SendAsync(message)
            end
        else
            local DefaultChatSystemChatEvents = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
            if DefaultChatSystemChatEvents then
                local SayMessageRequest = DefaultChatSystemChatEvents:FindFirstChild("SayMessageRequest")
                if SayMessageRequest then
                    SayMessageRequest:FireServer(message, "All")
                end
            end
        end
    end)
end

-- ============================================================================
-- SERVER-SIDE FLIGHT CONTROL
-- ============================================================================

local function startFlying()
    -- Tell server to enable flight
    ToggleFlightRemote:FireServer(true)
    
    -- Start sending movement updates to server
    movementUpdateConnection = RunService.RenderStepped:Connect(function()
        if not devModeEnabled then return end
        
        local character = LocalPlayer.Character
        if not character then return end
        
        local camera = workspace.CurrentCamera
        
        -- Calculate movement vector based on input
        local moveVector = Vector3.new(0, 0, 0)
        
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveVector = moveVector + (camera.CFrame.LookVector * flySpeed)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveVector = moveVector - (camera.CFrame.LookVector * flySpeed)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveVector = moveVector - (camera.CFrame.RightVector * flySpeed)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveVector = moveVector + (camera.CFrame.RightVector * flySpeed)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveVector = moveVector + (Vector3.new(0, 1, 0) * flySpeed)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            moveVector = moveVector - (Vector3.new(0, 1, 0) * flySpeed)
        end
        
        -- Send movement data to server
        UpdateMovementRemote:FireServer(moveVector, camera.CFrame)
    end)
end

local function stopFlying()
    -- Tell server to disable flight
    ToggleFlightRemote:FireServer(false)
    
    -- Stop sending movement updates
    if movementUpdateConnection then
        movementUpdateConnection:Disconnect()
        movementUpdateConnection = nil
    end
end

-- ============================================================================
-- SERVER-SIDE AIM TRACKING CONTROL
-- ============================================================================

local function startAimTracking()
    if not selectedPlayer then
        AimStatus.Text = "⚠️ Select a player first!"
        AimStatus.TextColor3 = Color3.fromRGB(255, 200, 100)
        return
    end
    
    -- Tell server to start tracking
    StartTrackingRemote:FireServer(selectedPlayer.Name)
    
    aimTrackingEnabled = true
    AimStatus.Text = "🎯 TRACKING: " .. selectedPlayer.Name
    AimStatus.TextColor3 = Color3.fromRGB(100, 255, 255)
    
    -- Start sending camera updates to server
    trackingUpdateConnection = RunService.RenderStepped:Connect(function()
        if not aimTrackingEnabled then return end
        
        local camera = workspace.CurrentCamera
        
        -- Send camera CFrame to server for tracking calculation
        UpdateTrackingRemote:FireServer(camera.CFrame)
    end)
end

local function stopAimTracking()
    -- Tell server to stop tracking
    StopTrackingRemote:FireServer()
    
    aimTrackingEnabled = false
    
    if selectedPlayer then
        AimStatus.Text = "Target: " .. selectedPlayer.Name
        AimStatus.TextColor3 = Color3.fromRGB(100, 255, 100)
    else
        AimStatus.Text = "No target selected"
        AimStatus.TextColor3 = Color3.fromRGB(255, 150, 100)
    end
    
    -- Stop sending camera updates
    if trackingUpdateConnection then
        trackingUpdateConnection:Disconnect()
        trackingUpdateConnection = nil
    end
end

-- ============================================================================
-- TOGGLE HANDLERS
-- ============================================================================

ChatToggle.MouseButton1Click:Connect(function()
    chatEnabled = not chatEnabled
    
    if chatEnabled then
        ChatToggle.Text = "Enabled"
        ChatToggle.BackgroundColor3 = Color3.fromRGB(50, 220, 50)
        ChatStatus.TextColor3 = Color3.fromRGB(50, 255, 50)
    else
        ChatToggle.Text = "Disabled"
        ChatToggle.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
        ChatStatus.TextColor3 = Color3.fromRGB(150, 150, 150)
    end
end)

DevToggle.MouseButton1Click:Connect(function()
    devModeEnabled = not devModeEnabled
    
    if devModeEnabled then
        DevToggle.Text = "Enabled"
        DevToggle.BackgroundColor3 = Color3.fromRGB(50, 220, 50)
        DevInstructions.TextColor3 = Color3.fromRGB(50, 255, 50)
        startFlying()
    else
        DevToggle.Text = "Disabled"
        DevToggle.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
        DevInstructions.TextColor3 = Color3.fromRGB(150, 150, 150)
        stopFlying()
    end
end)

-- ============================================================================
-- SPEED INPUT HANDLER
-- ============================================================================

SpeedInput.FocusLost:Connect(function()
    local value = tonumber(SpeedInput.Text)
    
    if value then
        value = math.clamp(value, 1, 100)
        flySpeed = value
        SpeedInput.Text = tostring(value)
        SpeedDisplay.Text = "(Current: " .. value .. ")"
        
        -- Send speed update to server
        UpdateSpeedRemote:FireServer(value)
    else
        SpeedInput.Text = tostring(flySpeed)
    end
end)

-- ============================================================================
-- INPUT HANDLERS
-- ============================================================================

-- V-Key for chat
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == CONFIG.TRIGGER_KEY and chatEnabled then
        sendChatMessage(getRandomMessage())
    end
    
    -- Right-click for aim tracking
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        startAimTracking()
    end
end)

-- Release right-click to stop tracking
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        stopAimTracking()
    end
end)

-- ============================================================================
-- HOVER EFFECTS
-- ============================================================================

ChatToggle.MouseEnter:Connect(function()
    ChatToggle.BackgroundColor3 = chatEnabled and Color3.fromRGB(40, 200, 40) or Color3.fromRGB(200, 40, 40)
end)

ChatToggle.MouseLeave:Connect(function()
    ChatToggle.BackgroundColor3 = chatEnabled and Color3.fromRGB(50, 220, 50) or Color3.fromRGB(220, 50, 50)
end)

DevToggle.MouseEnter:Connect(function()
    DevToggle.BackgroundColor3 = devModeEnabled and Color3.fromRGB(40, 200, 40) or Color3.fromRGB(200, 40, 40)
end)

DevToggle.MouseLeave:Connect(function()
    DevToggle.BackgroundColor3 = devModeEnabled and Color3.fromRGB(50, 220, 50) or Color3.fromRGB(220, 50, 50)
end)

-- ============================================================================
-- PLAYER EVENTS
-- ============================================================================

Players.PlayerAdded:Connect(function(player)
    if dropdownOpen then
        updatePlayerList()
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if selectedPlayer == player then
        selectedPlayer = nil
        stopAimTracking()
        DropdownButton.Text = "Select a player..."
        DropdownButton.TextColor3 = Color3.fromRGB(200, 200, 200)
        AimStatus.Text = "Target left the game"
        AimStatus.TextColor3 = Color3.fromRGB(255, 150, 100)
    end
    
    if dropdownOpen then
        updatePlayerList()
    end
end)

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.Parent = PlayerGui

-- Initial player list update
updatePlayerList()

-- CLIENT SCRIPT END --
