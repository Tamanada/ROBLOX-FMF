--!strict
-- client/Controllers/MoonCycleController.luau — Blueprint §14.4 (HUD).
-- Chip top-bar : phase lunaire + compte à rebours. Pur affichage : la math
-- vient du module partagé MoonCycle (même horloge UTC que le serveur) et
-- l'événement serveur MoonPhaseChanged ne sert qu'à resynchroniser.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MoonCycle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("MoonCycle"))
local Net = require(ReplicatedStorage.Shared.Util.Net)

local MoonCycleController = {}

local PHASE_LABELS: { [string]: string } = {
	FULL_MOON = "🌕 Pleine lune",
	POST_FULL = "🌖 Après-fête",
	HALF_MOON = "🌗 Demi-lune",
	NEW_MOON = "🌑 Nouvelle lune",
	FULL_MOON_EVE = "🌔 Veille de pleine lune",
}

local function formatCountdown(seconds: number): string
	local clamped = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", clamped // 60, clamped % 60)
end

function MoonCycleController.Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "FMF_MoonHUD"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local chip = Instance.new("TextLabel")
	chip.Name = "MoonChip"
	chip.Position = UDim2.fromOffset(210, 12)
	chip.Size = UDim2.fromOffset(230, 34)
	chip.BackgroundColor3 = Color3.fromRGB(11, 29, 58)
	chip.BackgroundTransparency = 0.15
	chip.BorderSizePixel = 0
	chip.Font = Enum.Font.GothamBold
	chip.TextSize = 14
	chip.TextColor3 = Color3.fromRGB(255, 209, 102)
	chip.Text = ""
	chip.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = chip

	local function refresh()
		local info = MoonCycle.GetPhase(nil)
		local label = PHASE_LABELS[info.phase] or info.phase
		chip.Text = `{label} · {formatCountdown(info.endsAt - os.time())}`
	end

	task.spawn(function()
		while gui.Parent ~= nil do
			refresh()
			task.wait(1)
		end
	end)

	-- Resync sur transition poussée par le serveur (même horloge, ceinture
	-- et bretelles).
	task.spawn(function()
		Net.Client.On("MoonPhaseChanged", function()
			refresh()
		end)
	end)
end

return MoonCycleController
