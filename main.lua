--==================================================
-- Xeno-Compatible Dev Fly GUI
-- Pure Client-Side
--==================================================

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

--==================================================
-- CONFIG
--==================================================
local CONFIG = {
    GUI_POSITION = UDim2.new(0.5, -175, 0.5, -150),
    GUI_SIZE = UDim2.new(0, 350, 0, 280),
    DEFAULT_SPEED = 50
}

--==================================================
-- STATE
--==================================================
local devModeEnabled = false
local flySpeed = CONFIG.DEFAULT_SPEED
local bodyVelocity, bodyGyro
local movementConnection

--==================================================
-- GUI CREATION
--==================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DevFlyGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
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
UIStroke.Color = Color3.fromRGB(255, 255, 255)
UIStroke.Thickness = 2
UIStroke.Transparency = 0.8
UIStroke.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, 0, 0, 40)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "Dev Fly GUI - Client-Side"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 18
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Parent = MainFrame

-- Fly Section
local FlySection = Instance.new("Frame")
FlySection.Size = UDim2.new(1, -20, 0, 120)
FlySection.Position = UDim2.new(0, 10, 0, 50)
FlySection.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
FlySection.BorderSizePixel = 0
FlySection.Parent = MainFrame

local FlyCorner = Instance.new("UICorner")
FlyCorner.CornerRadius = UDim.new(0, 8)
FlyCorner.Parent = FlySection

local FlyLabel = Instance.new("TextLabel")
FlyLabel.Size = UDim2.new(1, -20, 0, 25)
FlyLabel.Position = UDim2.new(0, 10, 0, 5)
FlyLabel.BackgroundTransparency = 1
FlyLabel.Text = "Dev Fly - Client-Side"
FlyLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
FlyLabel.TextSize = 14
FlyLabel.Font = Enum.Font.GothamBold
FlyLabel.TextXAlignment = Enum.TextXAlignment.Left
FlyLabel.Parent = FlySection

local FlyInstructions = Instance.new("TextLabel")
FlyInstructions.Size = UDim2.new(1, -20, 0, 20)
FlyInstructions.Position = UDim2.new(0, 10, 0, 30)
FlyInstructions.BackgroundTransparency = 1
FlyInstructions.Text = "WASD to move, Space/Shift for up/down"
FlyInstructions.TextColor3 = Color3.fromRGB(150, 150, 150)
FlyInstructions.TextSize = 11
FlyInstructions.Font = Enum.Font.Gotham
FlyInstructions.TextXAlignment = Enum.TextXAlignment.Left
FlyInstructions.Parent = FlySection

local SpeedLabel = Instance.new("TextLabel")
SpeedLabel.Size = UDim2.new(0, 80, 0, 20)
SpeedLabel.Position = UDim2.new(0, 10, 0, 55)
SpeedLabel.BackgroundTransparency = 1
SpeedLabel.Text = "Fly Speed:"
SpeedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
SpeedLabel.TextSize = 12
SpeedLabel.Font = Enum.Font.Gotham
SpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
SpeedLabel.Parent = FlySection

local SpeedInput = Instance.new("TextBox")
SpeedInput.Size = UDim2.new(0, 60, 0, 25)
SpeedInput.Position = UDim2.new(0, 90, 0, 53)
SpeedInput.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
SpeedInput.BorderSizePixel = 0
SpeedInput.Text = tostring(flySpeed)
SpeedInput.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedInput.TextSize = 14
SpeedInput.Font = Enum.Font.GothamBold
SpeedInput.ClearTextOnFocus = false
SpeedInput.Parent = FlySection

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
SpeedDisplay.Parent = FlySection

local FlyToggle = Instance.new("TextButton")
FlyToggle.Size = UDim2.new(0, 100, 0, 30)
FlyToggle.Position = UDim2.new(1, -110, 1, -35)
FlyToggle.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
FlyToggle.BorderSizePixel = 0
FlyToggle.Text = "Disabled"
FlyToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
FlyToggle.TextSize = 14
FlyToggle.Font = Enum.Font.GothamBold
FlyToggle.Parent = FlySection

local FlyToggleCorner = Instance.new("UICorner")
FlyToggleCorner.CornerRadius = UDim.new(0, 6)
FlyToggleCorner.Parent = FlyToggle

--==================================================
-- FLY FUNCTIONS
--==================================================
local function startFlying()
    local character = LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end

    -- Physics objects
    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(1e5,1e5,1e5)
    bodyVelocity.Velocity = Vector3.new(0,0,0)
    bodyVelocity.Parent = hrp

    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(1e5,1e5,1e5)
    bodyGyro.P = 1e4
    bodyGyro.CFrame = hrp.CFrame
    bodyGyro.Parent = hrp

    humanoid.PlatformStand = true

    movementConnection = RunService.RenderStepped:Connect(function()
        if not devModeEnabled then return end
        if not hrp or not humanoid then return end

        local cam = workspace.CurrentCamera
        local moveVec = Vector3.new(0,0,0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveVec = moveVec + cam.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveVec = moveVec - cam.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveVec = moveVec - cam.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveVec = moveVec + cam.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveVec = moveVec + Vector3.new(0,1,0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            moveVec = moveVec - Vector3.new(0,1,0)
        end

        bodyVelocity.Velocity = moveVec.Unit * flySpeed
        bodyGyro.CFrame = CFrame.new(hrp.Position, hrp.Position + cam.CFrame.LookVector)
    end)
end

local function stopFlying()
    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then humanoid.PlatformStand = false end
    if bodyVelocity then bodyVelocity:Destroy() bodyVelocity=nil end
    if bodyGyro then bodyGyro:Destroy() bodyGyro=nil end
    if movementConnection then movementConnection:Disconnect() movementConnection=nil end
end

--==================================================
-- GUI HANDLERS
--==================================================
FlyToggle.MouseButton1Click:Connect(function()
    devModeEnabled = not devModeEnabled
    if devModeEnabled then
        FlyToggle.Text = "Enabled"
        FlyToggle.BackgroundColor3 = Color3.fromRGB(50,220,50)
        FlyInstructions.TextColor3 = Color3.fromRGB(50,255,50)
        startFlying()
    else
        FlyToggle.Text = "Disabled"
        FlyToggle.BackgroundColor3 = Color3.fromRGB(220,50,50)
        FlyInstructions.TextColor3 = Color3.fromRGB(150,150,150)
        stopFlying()
    end
end)

SpeedInput.FocusLost:Connect(function()
    local value = tonumber(SpeedInput.Text)
    if value then
        value = math.clamp(value,1,200)
        flySpeed = value
        SpeedInput.Text = tostring(value)
        SpeedDisplay.Text = "(Current: "..value..")"
    else
        SpeedInput.Text = tostring(flySpeed)
    end
end)

print("Client-Side Dev Fly GUI loaded!")
