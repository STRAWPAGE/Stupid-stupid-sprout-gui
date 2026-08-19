--[[
    BloodyFirstPerson.lua
    ---------------------------------------------------------------
    A Roblox LocalScript that, when "turned on":
      1) Tints the screen a bloody red (ColorCorrectionEffect + a
         subtle red vignette overlay for extra intensity)
      2) Plays a music track
      3) Locks the camera into first person
      4) Adds a camera "bounce" (head-bob) that reacts to the
         player's movement

    HOW TO USE
    ---------------------------------------------------------------
    1. Put this script inside StarterPlayer > StarterPlayerScripts
       (it must be a LocalScript, not a Script).
    2. Set SOUND_ID below to your music asset id.
    3. Call On() / Off() / Toggle() from wherever you want to
       trigger this (GUI button, ProximityPrompt, RemoteEvent from
       the server, etc). A placeholder keybind ("N") is included
       at the bottom — remove it if you don't need it.
--]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ==================== CONFIG ====================
local SOUND_ID = "rbxassetid://0000000000" -- << put your music asset id here
local MUSIC_VOLUME = 0.5

-- Red filter intensity
local TINT_COLOR = Color3.fromRGB(255, 60, 60)
local VIGNETTE_TRANSPARENCY = 0.55 -- lower = more intense red overlay

-- Camera bounce ("bounce for every movement the player makes")
local BOB_FREQUENCY = 8      -- how fast the bob cycles while moving
local BOB_AMPLITUDE = 0.12   -- how far the camera bounces (studs)
local BOB_SIDE_AMPLITUDE = 0.06
local BOB_SMOOTHING = 10     -- higher = snappier response to start/stop moving
-- ==================================================

local isOn = false
local bobConnection = nil
local bobTime = 0
local currentBobStrength = 0

local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    humanoid = character:WaitForChild("Humanoid")
end)

-- ---- Color correction (bloody red tint) ----
local colorCorrection = Lighting:FindFirstChild("BloodyFirstPerson_ColorCorrection")
if not colorCorrection then
    colorCorrection = Instance.new("ColorCorrectionEffect")
    colorCorrection.Name = "BloodyFirstPerson_ColorCorrection"
    colorCorrection.TintColor = Color3.new(1, 1, 1)
    colorCorrection.Saturation = 0
    colorCorrection.Contrast = 0
    colorCorrection.Parent = Lighting
end

-- ---- Red vignette overlay GUI ----
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BloodyFirstPersonGui"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.Parent = playerGui

local vignette = Instance.new("Frame")
vignette.Name = "RedVignette"
vignette.Size = UDim2.new(1, 0, 1, 0)
vignette.Position = UDim2.new(0, 0, 0, 0)
vignette.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
vignette.BackgroundTransparency = 1 -- starts invisible, tweened in on()
vignette.BorderSizePixel = 0
vignette.ZIndex = 1
vignette.Parent = screenGui

-- ---- Music ----
local music = Instance.new("Sound")
music.Name = "BloodyFirstPerson_Sound"
music.SoundId = SOUND_ID
music.Looped = true
music.Volume = MUSIC_VOLUME
music.Parent = screenGui

-- ---- Camera bounce ----
local function startBounce()
    bobTime = 0
    currentBobStrength = 0
    bobConnection = RunService.RenderStepped:Connect(function(dt)
        if not humanoid then return end

        local speed = humanoid.MoveDirection.Magnitude > 0 and humanoid.WalkSpeed or 0
        local targetStrength = (humanoid.MoveDirection.Magnitude > 0) and 1 or 0

        -- smoothly ease the bob in/out so it doesn't snap when you stop/start
        currentBobStrength = currentBobStrength
            + (targetStrength - currentBobStrength) * math.clamp(BOB_SMOOTHING * dt, 0, 1)

        bobTime = bobTime + dt * (speed > 0 and (speed / 16) or 1)

        local verticalBob = math.sin(bobTime * BOB_FREQUENCY) * BOB_AMPLITUDE * currentBobStrength
        local sideBob = math.cos(bobTime * BOB_FREQUENCY * 0.5) * BOB_SIDE_AMPLITUDE * currentBobStrength

        -- Humanoid.CameraOffset nudges the camera without fighting the
        -- default Roblox camera script (works great with first person)
        humanoid.CameraOffset = Vector3.new(sideBob, verticalBob, 0)
    end)
end

local function stopBounce()
    if bobConnection then
        bobConnection:Disconnect()
        bobConnection = nil
    end
    if humanoid then
        humanoid.CameraOffset = Vector3.new(0, 0, 0)
    end
end

-- ---- Core toggle logic ----
local function turnOn()
    if isOn then return end
    isOn = true

    -- Bloody red tint
    local tintTween = TweenService:Create(
        colorCorrection,
        TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
        { TintColor = TINT_COLOR, Saturation = -0.2, Contrast = 0.15 }
    )
    tintTween:Play()

    screenGui.Enabled = true
    local vignetteTween = TweenService:Create(
        vignette,
        TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
        { BackgroundTransparency = VIGNETTE_TRANSPARENCY }
    )
    vignetteTween:Play()

    music:Play()

    -- Force first person
    player.CameraMode = Enum.CameraMode.LockFirstPerson
    player.CameraMinZoomDistance = 0.5
    player.CameraMaxZoomDistance = 0.5

    startBounce()
end

local function turnOff()
    if not isOn then return end
    isOn = false

    local tintTween = TweenService:Create(
        colorCorrection,
        TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
        { TintColor = Color3.new(1, 1, 1), Saturation = 0, Contrast = 0 }
    )
    tintTween:Play()

    local vignetteTween = TweenService:Create(
        vignette,
        TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
        { BackgroundTransparency = 1 }
    )
    vignetteTween:Play()
    vignetteTween.Completed:Connect(function()
        if not isOn then
            screenGui.Enabled = false
        end
    end)

    music:Stop()

    -- Restore normal camera
    player.CameraMode = Enum.CameraMode.Classic
    player.CameraMinZoomDistance = 0.5
    player.CameraMaxZoomDistance = 128

    stopBounce()
end

local function toggle()
    if isOn then
        turnOff()
    else
        turnOn()
    end
end

-- ==================== OPTIONAL TRIGGER ====================
-- Example: press "N" to toggle the effect on/off.
-- Remove this block if you're triggering it another way
-- (e.g. a RemoteEvent from the server, a GUI button, a ProximityPrompt).
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.N then
        toggle()
    end
end)
-- =============================================================

_G.BloodyFirstPerson = {
    On = turnOn,
    Off = turnOff,
    Toggle = toggle,
}
