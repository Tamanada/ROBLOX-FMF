--!strict
-- client/Controllers/MapController.luau — Blueprint §14.2 / §14.3.
-- Carte de l'île : liste des 5 zones, état verrouillé grisé (la destination
-- verrouillée reste VISIBLE — §14.3), zone courante surlignée, et comment
-- s'y rendre (dérivé de Config/Routes). Aucune action de téléport ici :
-- on voyage uniquement via les transports et sentiers (fares préservés).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Island = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Island"))
local Routes = require(ReplicatedStorage.Shared.Config.Routes)

local MapController = {}

local ATTR_UNLOCKED = "FMF_UnlockedZones"
local ATTR_CURRENT = "FMF_CurrentZone"

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

-- "Songthaew depuis Haad Rin", "Longtail depuis Haad Rin", "Sentier depuis ..."
local function reachDescription(zoneId: string): string
	if zoneId == Island.HUB_ZONE then
		return "Hub : tu y apparais"
	end
	local parts: { string } = {}
	for _, route in Routes.list do
		if route.to == zoneId then
			local fromName = Island.byId[route.from].displayName
			if route.vehicle == "songthaew" then
				table.insert(parts, `Songthaew depuis {fromName}`)
			elseif route.vehicle == "longtail" then
				table.insert(parts, `Longtail depuis {fromName}`)
			else
				table.insert(parts, `Sentier depuis {fromName}`)
			end
		end
	end
	return table.concat(parts, " ou ")
end

function MapController.Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = create("ScreenGui", { Name = "FMF_Map", ResetOnSpawn = false }, playerGui) :: ScreenGui

	local toggle = create("TextButton", {
		Name = "MapToggle",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(96, 34),
		BackgroundColor3 = Color3.fromRGB(11, 29, 58),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(0, 229, 255),
		Text = "🗺 Carte",
	}, gui) :: TextButton
	create("UICorner", { CornerRadius = UDim.new(0, 8) }, toggle)

	local panel = create("Frame", {
		Name = "MapPanel",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 54),
		Size = UDim2.fromOffset(280, 5 * 64 + 16),
		BackgroundColor3 = Color3.fromRGB(11, 29, 58),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Visible = false,
	}, gui) :: Frame
	create("UICorner", { CornerRadius = UDim.new(0, 10) }, panel)
	create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, panel)

	local rows: { [string]: { frame: Frame, name: TextLabel, reach: TextLabel } } = {}
	for order, zone in Island.list do
		local row = create("Frame", {
			Size = UDim2.new(1, -16, 0, 58),
			LayoutOrder = order,
			BackgroundColor3 = Color3.fromRGB(20, 45, 85),
			BorderSizePixel = 0,
		}, panel) :: Frame
		create("UICorner", { CornerRadius = UDim.new(0, 8) }, row)

		local nameLabel = create("TextLabel", {
			Position = UDim2.fromOffset(10, 6),
			Size = UDim2.new(1, -20, 0, 22),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(240, 240, 240),
			Text = zone.displayName,
		}, row) :: TextLabel

		local reachLabel = create("TextLabel", {
			Position = UDim2.fromOffset(10, 30),
			Size = UDim2.new(1, -20, 0, 20),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(159, 176, 204),
			Text = reachDescription(zone.id),
		}, row) :: TextLabel

		rows[zone.id] = { frame = row, name = nameLabel, reach = reachLabel }
	end

	local function refresh()
		local unlockedCsv = player:GetAttribute(ATTR_UNLOCKED)
		local currentId = player:GetAttribute(ATTR_CURRENT)
		local unlocked: { [string]: boolean } = {}
		if type(unlockedCsv) == "string" then
			for _, zoneId in string.split(unlockedCsv, ",") do
				unlocked[zoneId] = true
			end
		end

		for zoneId, row in rows do
			local isUnlocked = unlocked[zoneId] == true
			local isCurrent = currentId == zoneId
			row.frame.BackgroundTransparency = if isUnlocked then 0 else 0.5
			row.name.TextColor3 = if not isUnlocked
				then Color3.fromRGB(120, 130, 148) -- §14.3 : visible mais grisée
				elseif isCurrent then Color3.fromRGB(255, 209, 102)
				else Color3.fromRGB(240, 240, 240)
			row.name.Text = (if isCurrent then "📍 " else "")
				.. Island.byId[zoneId].displayName
				.. (if isUnlocked then "" else "  🔒")
			row.reach.TextColor3 = if isUnlocked then Color3.fromRGB(159, 176, 204) else Color3.fromRGB(100, 110, 128)
		end
	end

	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			refresh()
		end
	end)
	player:GetAttributeChangedSignal(ATTR_UNLOCKED):Connect(refresh)
	player:GetAttributeChangedSignal(ATTR_CURRENT):Connect(refresh)
	refresh()
end

return MapController
