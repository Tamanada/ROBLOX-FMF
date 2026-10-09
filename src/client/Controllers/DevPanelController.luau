--!strict
-- client/Controllers/DevPanelController.luau — Dev Panel S7.
-- Visible UNIQUEMENT si le serveur confirme l'autorisation (allowlist ou
-- Studio) ; de toute façon chaque requête est re-vérifiée serveur
-- (DebugAdminService, §10.3). Permet de valider les venues placeholder et
-- de reset la progression île pendant les tests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Island = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Island"))
local Net = require(ReplicatedStorage.Shared.Util.Net)

local DevPanelController = {}

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

function DevPanelController.Start()
	task.spawn(function()
		if Net.Client.Invoke("DevIsAdmin") ~= true then
			return
		end

		local player = Players.LocalPlayer
		local playerGui = player:WaitForChild("PlayerGui")
		local gui = create("ScreenGui", { Name = "FMF_DevPanel", ResetOnSpawn = false }, playerGui) :: ScreenGui

		local toggle = create("TextButton", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -12, 1, -12),
			Size = UDim2.fromOffset(64, 30),
			BackgroundColor3 = Color3.fromRGB(255, 46, 146),
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Text = "DEV",
		}, gui) :: TextButton
		create("UICorner", { CornerRadius = UDim.new(0, 8) }, toggle)

		local panel = create("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -12, 1, -50),
			Size = UDim2.fromOffset(300, 360),
			BackgroundColor3 = Color3.fromRGB(11, 29, 58),
			BackgroundTransparency = 0.05,
			BorderSizePixel = 0,
			Visible = false,
		}, gui) :: Frame
		create("UICorner", { CornerRadius = UDim.new(0, 10) }, panel)
		create("TextLabel", {
			Position = UDim2.fromOffset(0, 6),
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextColor3 = Color3.fromRGB(255, 46, 146),
			Text = "DEV PANEL — venues",
		}, panel)

		local list = create("ScrollingFrame", {
			Position = UDim2.fromOffset(8, 32),
			Size = UDim2.new(1, -16, 1, -76),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			CanvasSize = UDim2.fromOffset(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
		}, panel) :: ScrollingFrame
		create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, list)

		local order = 0
		for _, zone in Island.list do
			for _, slot in zone.venues do
				if not slot.completable then
					continue
				end
				order += 1
				local button = create("TextButton", {
					Size = UDim2.new(1, 0, 0, 30),
					LayoutOrder = order,
					BackgroundColor3 = Color3.fromRGB(20, 45, 85),
					BorderSizePixel = 0,
					Font = Enum.Font.GothamMedium,
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = Color3.fromRGB(240, 240, 240),
					Text = `  ✅ {zone.displayName} / {slot.id}`,
				}, list) :: TextButton
				create("UICorner", { CornerRadius = UDim.new(0, 6) }, button)
				button.Activated:Connect(function()
					Net.Client.Fire("DevCompleteVenue", slot.id)
				end)
			end
		end

		local reset = create("TextButton", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -16, 0, 30),
			BackgroundColor3 = Color3.fromRGB(255, 46, 146),
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Text = "Reset progression île",
		}, panel) :: TextButton
		create("UICorner", { CornerRadius = UDim.new(0, 8) }, reset)
		reset.Activated:Connect(function()
			Net.Client.Fire("DevResetIsland")
		end)

		toggle.Activated:Connect(function()
			panel.Visible = not panel.Visible
		end)
	end)
end

return DevPanelController
