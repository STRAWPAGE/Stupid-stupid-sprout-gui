--[[
    BWDecalMusic.lua
    ---------------------------------------------------------------
    A Roblox LocalScript that, when "turned on":
      1) Desaturates the screen (black & white) using a ColorCorrectionEffect
      2) Shows a decal image in the corner of the screen that spins slowly
      3) Plays a music track

    HOW TO USE
    ---------------------------------------------------------------
    1. Put this script inside StarterPlayer > StarterPlayerScripts
       (it must be a LocalScript, not a Script).
    2. Set DECAL_ID and SOUND_ID below to your own asset IDs
       (rbxassetid://XXXXXXXX form, or just the number).
    3. Call the module's Toggle/On/Off functions from elsewhere,
       e.g. from a ProximityPrompt, a GUI button, or a RemoteEvent
       fired by the server. An example trigger (press "B") is
       included at the bottom — remove it if you don't need it.
--]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ==================== CONFIG ====================
local DECAL_ID = "rbxassetid://0000000000"   -- << put your decal asset id here
local SOUND_ID = "rbxassetid://0000000000"   -- << put your music asset id here
local DECAL_SIZE = UDim2.new(0, 120, 0, 120) -- size of the corner decal
local SPIN_SPEED_DEG_PER_SEC = 15            -- "slowly" spinning speed
local CORNER_PADDING = UDim2.new(0, 16, 0, 16)
local MUSIC_VOLUME = 0.5
-- ==================================================

local isOn = false
local spinConnection = nil

-- ---- Color correction (black & white) ----
local colorCorrection = Lighting:FindFirstChild("BWDecalMusic_ColorCorrection")
if not colorCorrection then
    colorCorrection = Instance.new("ColorCorrectionEffect")
    colorCorrection.Name = "BWDecalMusic_ColorCorrection"
    colorCorrection.Saturation = 0 -- start neutral (off)
    colorCorrection.Parent = Lighting
end

-- ---- Corner decal GUI ----
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BWDecalMusicGui"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.Parent = playerGui

local decalImage = Instance.new("ImageLabel")
decalImage.Name = "CornerDecal"
decalImage.BackgroundTransparency = 1
decalImage.Size = DECAL_SIZE
decalImage.AnchorPoint = Vector2.new(1, 1) -- bottom-right corner
decalImage.Position = UDim2.new(1, -CORNER_PADDING.X.Offset, 1, -CORNER_PADDING.Y.Offset)
decalImage.Image = DECAL_ID
decalImage.Parent = screenGui

-- ---- Music ----
local music = Instance.new("Sound")
music.Name = "BWDecalMusic_Sound"
music.SoundId = SOUND_ID
music.Looped = true
music.Volume = MUSIC_VOLUME
music.Parent = screenGui

-- ---- Core toggle logic ----
local function startSpinning()
    spinConnection = RunService.RenderStepped:Connect(function(dt)
        decalImage.Rotation = (decalImage.Rotation + SPIN_SPEED_DEG_PER_SEC * dt) % 360
    end)
end

local function stopSpinning()
    if spinConnection then
        spinConnection:Disconnect()
        spinConnection = nil
    end
end

local function turnOn()
    if isOn then return end
    isOn = true

    -- Fade saturation down to -1 (fully desaturated / black & white)
    local satTween = TweenService:Create(
        colorCorrection,
        TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
        { Saturation = -1 }
    )
    satTween:Play()

    screenGui.Enabled = true
    startSpinning()

    music:Play()
end

local function turnOff()
    if not isOn then return end
    isOn = false

    local satTween = TweenService:Create(
        colorCorrection,
        TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
        { Saturation = 0 }
    )
    satTween:Play()

    stopSpinning()
    screenGui.Enabled = false

    music:Stop()
end

local function toggle()
    if isOn then
        turnOff()
    else
        turnOn()
    end
end

-- ==================== OPTIONAL TRIGGER ====================
-- Example: press "B" to toggle the effect on/off.
-- Remove this block if you're triggering it another way
-- (e.g. a RemoteEvent from the server, a GUI button, a ProximityPrompt).
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.B then
        toggle()
    end
end)
-- =============================================================

-- Expose functions in case another local script wants to require this one
-- as a ModuleScript instead (rename file extension / wrap in `return {}`
-- if you want that pattern).
_G.BWDecalMusic = {
    On = turnOn,
    Off = turnOff,
    Toggle = toggle,
}
