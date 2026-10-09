--!strict
-- client/Controllers/TransportController.luau — Blueprint §14.3.
-- Bandeau de trajet : destination, compte à rebours, bouton skip. Pur
-- affichage + intent : le serveur a déjà débité le fare, verrouillé le
-- siège et pilote le véhicule ; le skip n'est qu'une requête (re-validée
-- et débitée côté serveur).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Island = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Island"))
local Routes = require(ReplicatedStorage.Shared.Config.Routes)
local Net = require(ReplicatedStorage.Shared.Util.Net)

local TransportController = {}

local function formatCountdown(seconds: number): string
	local clamped = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", clamped // 60, clamped % 60)
end

function TransportController.Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "FMF_Transport"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local banner = Instance.new("Frame")
	banner.Name = "TripBanner"
	banner.AnchorPoint = Vector2.new(0.5, 1)
	banner.Position = UDim2.new(0.5, 0, 1, -78)
	banner.Size = UDim2.fromOffset(360, 74)
	banner.BackgroundColor3 = Color3.fromRGB(11, 29, 58)
	banner.BackgroundTransparency = 0.08
	banner.BorderSizePixel = 0
	banner.Visible = false
	banner.Parent = gui

	local bannerCorner = Instance.new("UICorner")
	bannerCorner.CornerRadius = UDim.new(0, 12)
	bannerCorner.Parent = banner

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(12, 8)
	title.Size = UDim2.new(1, -24, 0, 24)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(0, 229, 255)
	title.Text = ""
	title.Parent = banner

	local skipButton = Instance.new("TextButton")
	skipButton.AnchorPoint = Vector2.new(1, 1)
	skipButton.Position = UDim2.new(1, -10, 1, -8)
	skipButton.Size = UDim2.fromOffset(190, 28)
	skipButton.BackgroundColor3 = Color3.fromRGB(255, 209, 102)
	skipButton.BorderSizePixel = 0
	skipButton.Font = Enum.Font.GothamBold
	skipButton.TextSize = 13
	skipButton.TextColor3 = Color3.fromRGB(11, 29, 58)
	skipButton.Text = ""
	skipButton.Parent = banner

	local skipCorner = Instance.new("UICorner")
	skipCorner.CornerRadius = UDim.new(0, 8)
	skipCorner.Parent = skipButton

	skipButton.Activated:Connect(function()
		Net.Client.Fire("RequestTransportSkip")
	end)

	local tripToken = 0

	task.spawn(function()
		Net.Client.On("TransportTripStarted", function(routeId: any, duration: any, skipExtra: any)
			local routeDef = if type(routeId) == "string" then Routes.byId[routeId] else nil
			if routeDef == nil or type(duration) ~= "number" then
				return
			end
			local destination = Island.byId[routeDef.to]

			tripToken += 1
			local token = tripToken
			local endsAt = os.clock() + duration

			skipButton.Text = `Arriver maintenant (+{if type(skipExtra) == "number" then skipExtra else 0} 🐚)`
			skipButton.Visible = type(skipExtra) == "number" and skipExtra > 0
			banner.Visible = true

			task.spawn(function()
				while tripToken == token and banner.Visible do
					title.Text =
						`🚐 En route vers {destination.displayName} · {formatCountdown(endsAt - os.clock())}`
					task.wait(0.25)
				end
			end)
		end)
	end)

	task.spawn(function()
		Net.Client.On("TransportTripEnded", function()
			tripToken += 1
			banner.Visible = false
		end)
	end)
end

return TransportController
