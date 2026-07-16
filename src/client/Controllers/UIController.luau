--!strict
-- client/Controllers/UIController.luau — Sprint 1 HUD (§10.2).
-- Pure display + intent-sending (§10.3.4): balances come from leaderstats,
-- Hype from a player attribute, the uncollected pool from a plot attribute.
-- Every button only FIRES an intent through Net — the server re-validates
-- everything. Prices shown here are display-only (recomputed server-side).
-- Palette §9: deep navy #0B1D3A, lunar gold #FFD166, neon cyan #00E5FF.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Net"))
local Equipment = require(ReplicatedStorage.Shared.Config.Equipment)
local EconomyMath = require(ReplicatedStorage.Shared.Util.EconomyMath)
local Formatter = require(ReplicatedStorage.Shared.Util.Formatter)

local COLOR_NAVY = Color3.fromRGB(11, 29, 58) -- #0B1D3A
local COLOR_GOLD = Color3.fromRGB(255, 209, 102) -- #FFD166
local COLOR_CYAN = Color3.fromRGB(0, 229, 255) -- #00E5FF
local COLOR_WHITE = Color3.fromRGB(240, 240, 240)
local COLOR_DANGER = Color3.fromRGB(255, 46, 146) -- #FF2E92

local SHOP_GRID_COLUMNS = 7
local SHOP_GRID_SPACING = 12
local SHOP_GRID_ORIGIN = -36

local player = Players.LocalPlayer

local UIController = {}

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

-- Blocks until this player's plot model exists and is attributed.
local function waitForMyPlot(): Model
	local container = Workspace:WaitForChild("Plots")
	while true do
		for _, child in container:GetChildren() do
			if child:IsA("Model") and child:GetAttribute("OwnerUserId") == player.UserId then
				return child
			end
		end
		task.wait(0.5)
	end
end

function UIController.Start()
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = create("ScreenGui", {
		Name = "FMF_HUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
	}, playerGui) :: ScreenGui

	----------------------------------------------------------------------
	-- Top-left: Shells + Hype
	----------------------------------------------------------------------
	local statsFrame = create("Frame", {
		Name = "Stats",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(190, 64),
		BackgroundColor3 = COLOR_NAVY,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, gui)
	create("UICorner", { CornerRadius = UDim.new(0, 10) }, statsFrame)

	local shellsLabel = create("TextLabel", {
		Name = "Shells",
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 0, 24),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLOR_GOLD,
		Text = "🐚 …",
	}, statsFrame) :: TextLabel

	local hypeLabel = create("TextLabel", {
		Name = "Hype",
		Position = UDim2.fromOffset(10, 34),
		Size = UDim2.new(1, -20, 0, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLOR_CYAN,
		Text = "🔥 Hype 0/100",
	}, statsFrame) :: TextLabel

	task.spawn(function()
		local leaderstats = player:WaitForChild("leaderstats")
		local shells = leaderstats:WaitForChild("Shells") :: IntValue
		local function updateShells()
			shellsLabel.Text = `🐚 {Formatter.abbreviate(shells.Value)}`
		end
		shells.Changed:Connect(updateShells)
		updateShells()
	end)

	local function updateHype()
		local hype = player:GetAttribute("Hype")
		hypeLabel.Text = `🔥 Hype {if type(hype) == "number" then hype else 0}/100`
	end
	player:GetAttributeChangedSignal("Hype"):Connect(updateHype)
	updateHype()

	----------------------------------------------------------------------
	-- Toast (server "Notify" pushes)
	----------------------------------------------------------------------
	local toast = create("TextLabel", {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(420, 34),
		BackgroundColor3 = COLOR_NAVY,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamMedium,
		TextSize = 16,
		TextColor3 = COLOR_WHITE,
		Text = "",
		Visible = false,
	}, gui) :: TextLabel
	create("UICorner", { CornerRadius = UDim.new(0, 8) }, toast)

	local toastToken = 0
	local function showToast(message: string)
		toastToken += 1
		local token = toastToken
		toast.Text = message
		toast.Visible = true
		task.delay(2.5, function()
			if toastToken == token then
				toast.Visible = false
			end
		end)
	end

	task.spawn(function()
		Net.Client.On("Notify", function(message: any)
			if type(message) == "string" then
				showToast(message)
			end
		end)
	end)

	----------------------------------------------------------------------
	-- Bottom-center: Collect button
	----------------------------------------------------------------------
	local collectButton = create("TextButton", {
		Name = "Collect",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(240, 48),
		BackgroundColor3 = COLOR_GOLD,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		TextColor3 = COLOR_NAVY,
		Text = "Collect 🐚 0",
		AutoButtonColor = true,
	}, gui) :: TextButton
	create("UICorner", { CornerRadius = UDim.new(0, 12) }, collectButton)

	collectButton.Activated:Connect(function()
		Net.Client.Fire("RequestCollect")
	end)

	----------------------------------------------------------------------
	-- Right: Zone 1 shop
	----------------------------------------------------------------------
	local shopFrame = create("Frame", {
		Name = "Shop",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(240, 420),
		BackgroundColor3 = COLOR_NAVY,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, gui)
	create("UICorner", { CornerRadius = UDim.new(0, 10) }, shopFrame)
	create("TextLabel", {
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = COLOR_GOLD,
		Text = "🏗️ Build — Haad Rin",
	}, shopFrame)

	local shopList = create("ScrollingFrame", {
		Position = UDim2.fromOffset(8, 36),
		Size = UDim2.new(1, -16, 1, -44),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, shopFrame) :: ScrollingFrame
	create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, shopList)

	----------------------------------------------------------------------
	-- Left: My Festival (owned equipment: upgrade / repair)
	----------------------------------------------------------------------
	local ownedFrame = create("Frame", {
		Name = "MyFestival",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 40),
		Size = UDim2.fromOffset(260, 340),
		BackgroundColor3 = COLOR_NAVY,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, gui)
	create("UICorner", { CornerRadius = UDim.new(0, 10) }, ownedFrame)
	create("TextLabel", {
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = COLOR_GOLD,
		Text = "🌕 My Festival",
	}, ownedFrame)

	local ownedList = create("ScrollingFrame", {
		Position = UDim2.fromOffset(8, 36),
		Size = UDim2.new(1, -16, 1, -44),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, ownedFrame) :: ScrollingFrame
	create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, ownedList)

	----------------------------------------------------------------------
	-- Plot wiring (after assignment replicates)
	----------------------------------------------------------------------
	task.spawn(function()
		local plotModel = waitForMyPlot()
		local basePart = plotModel:WaitForChild("Base") :: BasePart
		local equipmentFolder = plotModel:WaitForChild("Equipment")

		-- Collect button label mirrors the server-owned pool.
		local function updateUncollected()
			local uncollected = plotModel:GetAttribute("Uncollected")
			local amount = if type(uncollected) == "number" then uncollected else 0
			collectButton.Text = `Collect 🐚 {Formatter.abbreviate(amount)}`
		end
		plotModel:GetAttributeChangedSignal("Uncollected"):Connect(updateUncollected)
		updateUncollected()

		-- Shop buttons: intent = RequestBuy(equipmentId, worldCFrame).
		-- Placement suggestion is a simple free-grid slot; the server
		-- validates bounds regardless (§10.3.2).
		local function nextSlotCFrame(): CFrame
			local count = #equipmentFolder:GetChildren()
			local column = count % SHOP_GRID_COLUMNS
			local row = math.floor(count / SHOP_GRID_COLUMNS)
			return basePart.CFrame
				* CFrame.new(
					SHOP_GRID_ORIGIN + column * SHOP_GRID_SPACING,
					3,
					SHOP_GRID_ORIGIN + row * SHOP_GRID_SPACING
				)
		end

		for order, def in Equipment.list do
			if def.zone ~= 1 or def.cost <= 0 then
				continue
			end
			local button = create("TextButton", {
				Size = UDim2.new(1, 0, 0, 40),
				LayoutOrder = order,
				BackgroundColor3 = Color3.fromRGB(20, 45, 85),
				BorderSizePixel = 0,
				Font = Enum.Font.GothamMedium,
				TextSize = 14,
				TextColor3 = COLOR_WHITE,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = `  {def.displayName}\n  🐚 {Formatter.abbreviate(def.cost)}  •  +{def.revenuePerMinuteNight}/min`,
			}, shopList) :: TextButton
			create("UICorner", { CornerRadius = UDim.new(0, 8) }, button)
			button.Activated:Connect(function()
				Net.Client.Fire("RequestBuy", def.id, nextSlotCFrame())
			end)
		end

		-- Owned list rebuild (server refreshes recreate the parts).
		local rebuildPending = false
		local function rebuildOwned()
			if rebuildPending then
				return
			end
			rebuildPending = true
			task.defer(function()
				rebuildPending = false

				for _, child in ownedList:GetChildren() do
					if child:IsA("Frame") then
						child:Destroy()
					end
				end

				local parts = equipmentFolder:GetChildren()
				table.sort(parts, function(a, b)
					local ia = a:GetAttribute("Index")
					local ib = b:GetAttribute("Index")
					return (if type(ia) == "number" then ia else 0) < (if type(ib) == "number" then ib else 0)
				end)

				for _, part in parts do
					local id = part:GetAttribute("EquipmentId")
					local index = part:GetAttribute("Index")
					local level = part:GetAttribute("Level")
					local broken = part:GetAttribute("Broken") == true
					if type(id) ~= "string" or type(index) ~= "number" then
						continue
					end
					local def = Equipment.byId[id]
					if def == nil then
						continue
					end
					local displayLevel = if type(level) == "number" then level else 1

					local row = create("Frame", {
						Size = UDim2.new(1, 0, 0, 34),
						LayoutOrder = index,
						BackgroundColor3 = Color3.fromRGB(20, 45, 85),
						BorderSizePixel = 0,
					}, ownedList)
					create("UICorner", { CornerRadius = UDim.new(0, 8) }, row)

					create("TextLabel", {
						Position = UDim2.fromOffset(8, 0),
						Size = UDim2.new(1, -100, 1, 0),
						BackgroundTransparency = 1,
						Font = Enum.Font.GothamMedium,
						TextSize = 13,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextColor3 = if broken then COLOR_DANGER else COLOR_WHITE,
						Text = `{def.displayName}  Lv{displayLevel}{if broken then " 💥" else ""}`,
					}, row)

					if broken then
						local repairButton = create("TextButton", {
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -6, 0.5, 0),
							Size = UDim2.fromOffset(86, 26),
							BackgroundColor3 = COLOR_DANGER,
							BorderSizePixel = 0,
							Font = Enum.Font.GothamBold,
							TextSize = 12,
							TextColor3 = COLOR_WHITE,
							Text = `🔧 {Formatter.abbreviate(EconomyMath.repairCost(def.cost))}`,
						}, row) :: TextButton
						create("UICorner", { CornerRadius = UDim.new(0, 6) }, repairButton)
						repairButton.Activated:Connect(function()
							Net.Client.Fire("RequestRepair", index)
						end)
					elseif def.cost > 0 and displayLevel < EconomyMath.maxLevel() then
						local upgradeButton = create("TextButton", {
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -6, 0.5, 0),
							Size = UDim2.fromOffset(86, 26),
							BackgroundColor3 = COLOR_CYAN,
							BorderSizePixel = 0,
							Font = Enum.Font.GothamBold,
							TextSize = 12,
							TextColor3 = COLOR_NAVY,
							Text = `⚡ {Formatter.abbreviate(EconomyMath.upgradeCost(def.cost))}`,
						}, row) :: TextButton
						create("UICorner", { CornerRadius = UDim.new(0, 6) }, upgradeButton)
						upgradeButton.Activated:Connect(function()
							Net.Client.Fire("RequestUpgrade", index)
						end)
					end
				end
			end)
		end

		equipmentFolder.ChildAdded:Connect(rebuildOwned)
		equipmentFolder.ChildRemoved:Connect(rebuildOwned)
		rebuildOwned()
	end)
end

return UIController
