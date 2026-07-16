--!strict
-- client/Controllers/AmbienceController.luau — Blueprint §9 (direction
-- artistique & audio) + §2.2 / §7 HUD. Pure presentation: it only READS the
-- server-replicated world state (Workspace phase attributes, the CleanupState
-- push) and drives Lighting, audio crossfade, and a small HUD. It never sends
-- gameplay intents and holds no authority (§10.3.4).
--
-- The day/night cycle is server-owned (EventService); this controller tweens
-- Lighting to match and crossfades two zone audio loops (§9: chill day /
-- house-tribal night). Audio asset IDs are royalty-free loops assigned in
-- Studio via the AssetRegistry (§9/§10.1 — never real commercial music), so
-- the SoundId fields are left blank here and the crossfade logic is wired.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Net"))

local ATTR_PHASE = "FMF_Phase"
local ATTR_PHASE_ENDS_AT = "FMF_PhaseEndsAt"

local COLOR_NAVY = Color3.fromRGB(11, 29, 58) -- #0B1D3A (§9)
local COLOR_GOLD = Color3.fromRGB(255, 209, 102) -- #FFD166
local COLOR_CYAN = Color3.fromRGB(0, 229, 255) -- #00E5FF
local COLOR_WHITE = Color3.fromRGB(240, 240, 240)

local PHASE_TWEEN = TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local AUDIO_TWEEN = TweenInfo.new(3, Enum.EasingStyle.Linear)

-- §9 — night is a deep tropical blue with a giant moon; day is bright sand.
local DAY_LIGHTING = {
	ClockTime = 13,
	Brightness = 2,
	OutdoorAmbient = Color3.fromRGB(140, 140, 140),
	FogEnd = 2000,
	FogColor = Color3.fromRGB(200, 210, 220),
}
local NIGHT_LIGHTING = {
	ClockTime = 0,
	Brightness = 0.6,
	OutdoorAmbient = COLOR_NAVY,
	FogEnd = 900,
	FogColor = COLOR_NAVY,
}

local player = Players.LocalPlayer

local AmbienceController = {}

local function create(className: string, props: { [string]: any }, parent: Instance?): Instance
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	if parent ~= nil then
		instance.Parent = parent
	end
	return instance
end

local function currentPhase(): string
	local phase = Workspace:GetAttribute(ATTR_PHASE)
	return if type(phase) == "string" then phase else "Day"
end

function AmbienceController.Start()
	----------------------------------------------------------------------
	-- Lighting + audio crossfade
	----------------------------------------------------------------------
	local group = Instance.new("SoundGroup")
	group.Name = "FMF_Ambience"
	group.Parent = SoundService

	-- Royalty-free loops — SoundId assigned in Studio (§9, AssetRegistry).
	local daySound = create("Sound", {
		Name = "DayLoop",
		Looped = true,
		Volume = 0,
		SoundGroup = group,
	}, group) :: Sound
	local nightSound = create("Sound", {
		Name = "NightLoop",
		Looped = true,
		Volume = 0,
		SoundGroup = group,
	}, group) :: Sound
	pcall(function()
		daySound:Play()
		nightSound:Play()
	end)

	-- §9 — audio intensity rises with Hype (0..1 scaling on the active loop).
	local function hypeGain(): number
		local hype = player:GetAttribute("Hype")
		local value = if type(hype) == "number" then hype else 0
		return 0.4 + 0.6 * math.clamp(value / 100, 0, 1)
	end

	local function applyPhase()
		local isNight = currentPhase() == "Night"
		local target = if isNight then NIGHT_LIGHTING else DAY_LIGHTING
		TweenService:Create(Lighting, PHASE_TWEEN, target):Play()

		local gain = hypeGain()
		TweenService:Create(daySound, AUDIO_TWEEN, { Volume = if isNight then 0 else gain }):Play()
		TweenService:Create(nightSound, AUDIO_TWEEN, { Volume = if isNight then gain else 0 }):Play()
	end

	Workspace:GetAttributeChangedSignal(ATTR_PHASE):Connect(applyPhase)
	player:GetAttributeChangedSignal("Hype"):Connect(applyPhase)
	applyPhase()

	----------------------------------------------------------------------
	-- Phase HUD (top-center, below the toast) — countdown to next phase
	----------------------------------------------------------------------
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = create("ScreenGui", {
		Name = "FMF_Ambience_HUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
	}, playerGui) :: ScreenGui

	local phaseLabel = create("TextLabel", {
		Name = "Phase",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 58),
		Size = UDim2.fromOffset(200, 30),
		BackgroundColor3 = COLOR_NAVY,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = COLOR_GOLD,
		Text = "☀️ Day",
	}, gui) :: TextLabel
	create("UICorner", { CornerRadius = UDim.new(0, 8) }, phaseLabel)

	local function updatePhaseLabel()
		local isNight = currentPhase() == "Night"
		local endsAt = Workspace:GetAttribute(ATTR_PHASE_ENDS_AT)
		local remaining = 0
		if type(endsAt) == "number" then
			remaining = math.max(0, endsAt - os.time())
		end
		local minutes = math.floor(remaining / 60)
		local seconds = remaining % 60
		phaseLabel.TextColor3 = if isNight then COLOR_CYAN else COLOR_GOLD
		phaseLabel.Text = string.format(
			"%s %s  %d:%02d",
			if isNight then "🌙" else "☀️",
			if isNight then "Night" else "Day",
			minutes,
			seconds
		)
	end
	Workspace:GetAttributeChangedSignal(ATTR_PHASE):Connect(updatePhaseLabel)
	Workspace:GetAttributeChangedSignal(ATTR_PHASE_ENDS_AT):Connect(updatePhaseLabel)
	task.spawn(function()
		while true do
			updatePhaseLabel()
			task.wait(1)
		end
	end)

	----------------------------------------------------------------------
	-- Beach Cleanup banner (§7) — driven by the server CleanupState push
	----------------------------------------------------------------------
	local cleanupBanner = create("TextLabel", {
		Name = "Cleanup",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 94),
		Size = UDim2.fromOffset(260, 30),
		BackgroundColor3 = Color3.fromRGB(20, 45, 85),
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = COLOR_WHITE,
		Text = "",
		Visible = false,
	}, gui) :: TextLabel
	create("UICorner", { CornerRadius = UDim.new(0, 8) }, cleanupBanner)

	Net.Client.On("CleanupState", function(state: any)
		if type(state) ~= "table" or state.active ~= true then
			cleanupBanner.Visible = false
			return
		end
		local collected = if type(state.collected) == "number" then state.collected else 0
		local total = if type(state.total) == "number" then state.total else 0
		cleanupBanner.Visible = true
		cleanupBanner.Text = `🧹 Beach Cleanup — {collected}/{total}`
	end)
end

return AmbienceController
