--!strict
-- client/Controllers/UIController.luau — Sprint 1 HUD (§10.2).
-- Pure display + intent-sending (§10.3.4): balances come from leaderstats,
-- Hype from a player attribute, the uncollected pool from a plot attribute.
-- Every button only FIRES an intent through Net — the server re-validates
-- everything. Prices shown here are display-only (recomputed server-side).
-- Palette §9: deep navy #0B1D3A, lunar gold #FFD166, neon cyan #00E5FF.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Net"))
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Equipment = require(ReplicatedStorage.Shared.Config.Equipment)
local Staff = require(ReplicatedStorage.Shared.Config.Staff)
local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)
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
		Size = UDim2.fromOffset(190, 88),
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

	local moonShardsLabel = create("TextLabel", {
		Name = "MoonShards",
		Position = UDim2.fromOffset(10, 32),
		Size = UDim2.new(1, -20, 0, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLOR_WHITE,
		Text = "🌕 0",
	}, statsFrame) :: TextLabel

	local hypeLabel = create("TextLabel", {
		Name = "Hype",
		Position = UDim2.fromOffset(10, 58),
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

		local moonShards = leaderstats:WaitForChild("MoonShards") :: IntValue
		local function updateMoonShards()
			moonShardsLabel.Text = `🌕 {Formatter.abbreviate(moonShards.Value)}`
		end
		moonShards.Changed:Connect(updateMoonShards)
		updateMoonShards()
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

		-- §4 — the shop shows every equipment in an UNLOCKED zone, plus an
		-- unlock button for the next zone. Rebuilt when MaxUnlockedZone changes.
		local function currentMaxZone(): number
			local zone = player:GetAttribute("MaxUnlockedZone")
			return if type(zone) == "number" then zone else 1
		end

		local function rebuildShop()
			for _, child in shopList:GetChildren() do
				if child:IsA("TextButton") then
					child:Destroy()
				end
			end

			local maxZone = currentMaxZone()
			for order, def in Equipment.list do
				if def.cost <= 0 or def.zone > maxZone then
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

			-- Next-zone unlock (§4). Server re-validates cost + Hype (§10.3).
			local nextZone = maxZone + 1
			local req = Economy.ZONE_UNLOCKS[nextZone]
			if req ~= nil then
				local unlockButton = create("TextButton", {
					Size = UDim2.new(1, 0, 0, 44),
					LayoutOrder = 1000,
					BackgroundColor3 = COLOR_GOLD,
					BorderSizePixel = 0,
					Font = Enum.Font.GothamBold,
					TextSize = 13,
					TextColor3 = COLOR_NAVY,
					Text = `🔓 Unlock Zone {nextZone}\n🐚 {Formatter.abbreviate(req.shells)} • needs Hype {req.hype}`,
				}, shopList) :: TextButton
				create("UICorner", { CornerRadius = UDim.new(0, 8) }, unlockButton)
				unlockButton.Activated:Connect(function()
					Net.Client.Fire("RequestUnlockZone", nextZone)
				end)
			end
		end

		player:GetAttributeChangedSignal("MaxUnlockedZone"):Connect(rebuildShop)
		rebuildShop()

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

	----------------------------------------------------------------------
	-- Bottom-left: Recruitment + Staff (§5). Drop odds are DISPLAYED in-game
	-- (§5.1 / §11.2 — regulated-gacha transparency). All rolls are intents;
	-- the server debits currency and decides the result (§10.3).
	----------------------------------------------------------------------
	local RARITY_COLORS: { [string]: Color3 } = {
		Common = Color3.fromRGB(180, 190, 200),
		Rare = COLOR_CYAN,
		Epic = COLOR_DANGER,
		Legendary = COLOR_GOLD,
	}

	local staffFrame = create("Frame", {
		Name = "Staff",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(280, 300),
		BackgroundColor3 = COLOR_NAVY,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, gui)
	create("UICorner", { CornerRadius = UDim.new(0, 10) }, staffFrame)
	create("TextLabel", {
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextColor3 = COLOR_GOLD,
		Text = "👷 Recruitment",
	}, staffFrame)

	local function oddsText(banner: any): string
		local parts = {}
		for _, rarity in { "Common", "Rare", "Epic", "Legendary" } do
			local probability = banner.odds[rarity]
			if probability ~= nil then
				table.insert(parts, `{rarity} {math.floor(probability * 100 + 0.5)}%`)
			end
		end
		return table.concat(parts, " · ")
	end

	for bannerOrder, banner in Staff.banners do
		local symbol = if banner.costCurrency == "moonShards" then "🌕" else "🐚"
		local rollButton = create("TextButton", {
			Position = UDim2.fromOffset(8, 30 + (bannerOrder - 1) * 46),
			Size = UDim2.new(1, -16, 0, 40),
			BackgroundColor3 = Color3.fromRGB(20, 45, 85),
			BorderSizePixel = 0,
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextColor3 = COLOR_WHITE,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = `  {banner.displayName} — {symbol}{banner.cost}\n  {oddsText(banner)}`,
		}, staffFrame) :: TextButton
		create("UICorner", { CornerRadius = UDim.new(0, 8) }, rollButton)
		rollButton.Activated:Connect(function()
			Net.Client.Fire("RequestRoll", banner.id)
		end)
	end

	local staffList = create("ScrollingFrame", {
		Position = UDim2.fromOffset(8, 128),
		Size = UDim2.new(1, -16, 1, -136),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, staffFrame) :: ScrollingFrame
	create("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, staffList)

	local function maxZone(): number
		local zone = player:GetAttribute("MaxUnlockedZone")
		return if type(zone) == "number" then zone else 1
	end

	Net.Client.On("StaffState", function(roster: any)
		for _, child in staffList:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		if type(roster) ~= "table" then
			return
		end

		-- Duplicate counts for the fusion sink (§5.2 — 3 → 1).
		local counts: { [string]: number } = {}
		for _, entry in roster do
			counts[entry.staffId] = (counts[entry.staffId] or 0) + 1
		end

		for _, entry in roster do
			local def = Staff.byId[entry.staffId]
			if def == nil then
				continue
			end
			local row = create("Frame", {
				Size = UDim2.new(1, 0, 0, 30),
				LayoutOrder = entry.index,
				BackgroundColor3 = Color3.fromRGB(20, 45, 85),
				BorderSizePixel = 0,
			}, staffList)
			create("UICorner", { CornerRadius = UDim.new(0, 6) }, row)

			local zoneSuffix = if entry.assignedZone ~= nil then ` • Z{entry.assignedZone}` else ""
			create("TextLabel", {
				Position = UDim2.fromOffset(6, 0),
				Size = UDim2.new(1, -120, 1, 0),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = RARITY_COLORS[entry.rarity] or COLOR_WHITE,
				Text = `{def.displayName}{zoneSuffix}`,
			}, row)

			-- Assign: cycles 0 (off) → 1 → … → maxZone → 0. Server validates.
			local assignButton = create("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -60, 0.5, 0),
				Size = UDim2.fromOffset(50, 24),
				BackgroundColor3 = COLOR_CYAN,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBold,
				TextSize = 11,
				TextColor3 = COLOR_NAVY,
				Text = "Assign",
			}, row) :: TextButton
			create("UICorner", { CornerRadius = UDim.new(0, 6) }, assignButton)
			assignButton.Activated:Connect(function()
				local current = tonumber(entry.assignedZone) or 0
				local nextZone = if current >= maxZone() then 0 else current + 1
				Net.Client.Fire("RequestAssignStaff", entry.index, nextZone)
			end)

			if (counts[entry.staffId] or 0) >= Economy.STAFF_FUSION_COUNT and Staff.fusionNext[entry.rarity] ~= nil then
				local fuseButton = create("TextButton", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -6, 0.5, 0),
					Size = UDim2.fromOffset(48, 24),
					BackgroundColor3 = COLOR_GOLD,
					BorderSizePixel = 0,
					Font = Enum.Font.GothamBold,
					TextSize = 11,
					TextColor3 = COLOR_NAVY,
					Text = "Fuse",
				}, row) :: TextButton
				create("UICorner", { CornerRadius = UDim.new(0, 6) }, fuseButton)
				fuseButton.Activated:Connect(function()
					Net.Client.Fire("RequestFuseStaff", entry.staffId)
				end)
			end
		end
	end)

	----------------------------------------------------------------------
	-- Top-right toggles: 💎 Store (§8) and 🌐 Hub (§6). Panels are hidden
	-- until toggled to keep the HUD uncluttered.
	----------------------------------------------------------------------
	local function makePanel(titleText: string): Frame
		local frame = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(320, 380),
			BackgroundColor3 = COLOR_NAVY,
			BackgroundTransparency = 0.05,
			BorderSizePixel = 0,
			Visible = false,
		}, gui) :: Frame
		create("UICorner", { CornerRadius = UDim.new(0, 12) }, frame)
		create("TextLabel", {
			Position = UDim2.fromOffset(0, 8),
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 18,
			TextColor3 = COLOR_GOLD,
			Text = titleText,
		}, frame)
		local close = create("TextButton", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 8),
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = COLOR_DANGER,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			TextColor3 = COLOR_WHITE,
			Text = "✕",
		}, frame) :: TextButton
		create("UICorner", { CornerRadius = UDim.new(0, 6) }, close)
		close.Activated:Connect(function()
			frame.Visible = false
		end)
		return frame
	end

	local function makeToggle(icon: string, order: number, panel: Frame)
		local button = create("TextButton", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 12 + (order - 1) * 44),
			Size = UDim2.fromOffset(40, 40),
			BackgroundColor3 = COLOR_NAVY,
			BackgroundTransparency = 0.1,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			TextSize = 20,
			TextColor3 = COLOR_GOLD,
			Text = icon,
		}, gui) :: TextButton
		create("UICorner", { CornerRadius = UDim.new(0, 10) }, button)
		button.Activated:Connect(function()
			panel.Visible = not panel.Visible
		end)
	end

	-- 💎 Store (§8) — Game Passes + Developer Products (accelerators, §8.4).
	local storePanel = makePanel("💎 Store")
	local storeList = create("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 40),
		Size = UDim2.new(1, -20, 1, -48),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, storePanel) :: ScrollingFrame
	create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, storeList)

	local function storeRow(order: number, label: string, robux: number, onBuy: () -> ())
		local button = create("TextButton", {
			Size = UDim2.new(1, 0, 0, 40),
			LayoutOrder = order,
			BackgroundColor3 = Color3.fromRGB(20, 45, 85),
			BorderSizePixel = 0,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextColor3 = COLOR_WHITE,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = `  {label}\n  R$ {robux}`,
		}, storeList) :: TextButton
		create("UICorner", { CornerRadius = UDim.new(0, 8) }, button)
		button.Activated:Connect(onBuy)
	end

	local storeOrder = 0
	for _, pass in Monetization.passes do
		storeOrder += 1
		storeRow(storeOrder, `🎟️ {pass.displayName}`, pass.robux, function()
			if pass.gamePassId == 0 then
				showToast("This pass isn't published yet.")
			else
				MarketplaceService:PromptGamePassPurchase(player, pass.gamePassId)
			end
		end)
	end
	for _, product in Monetization.products do
		storeOrder += 1
		storeRow(storeOrder, `🛒 {product.displayName}`, product.robux, function()
			if product.productId == 0 then
				showToast("This product isn't published yet.")
			else
				MarketplaceService:PromptProductPurchase(player, product.productId)
			end
		end)
	end

	-- 🌐 Hub (§6) — visit other festivals, rate them, return home.
	local hubPanel = makePanel("🌐 Festivals")
	local hubList = create("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 40),
		Size = UDim2.new(1, -20, 1, -86),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, hubPanel) :: ScrollingFrame
	create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, hubList)

	local returnHome = create("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(200, 34),
		BackgroundColor3 = COLOR_GOLD,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = COLOR_NAVY,
		Text = "🏠 Return Home",
	}, hubPanel) :: TextButton
	create("UICorner", { CornerRadius = UDim.new(0, 8) }, returnHome)
	returnHome.Activated:Connect(function()
		Net.Client.Fire("RequestReturnHome")
	end)

	local function rebuildHub()
		for _, child in hubList:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local container = Workspace:FindFirstChild("Plots")
		if container == nil then
			return
		end
		for _, plotModel in container:GetChildren() do
			local ownerId = plotModel:GetAttribute("OwnerUserId")
			local plotIndex = plotModel:GetAttribute("PlotIndex")
			if type(ownerId) ~= "number" or type(plotIndex) ~= "number" or ownerId == player.UserId then
				continue
			end
			local rating = plotModel:GetAttribute("Rating")
			local stars = if type(rating) == "number" and rating > 0 then string.format(" • %.1f★", rating) else ""

			local row = create("Frame", {
				Size = UDim2.new(1, 0, 0, 52),
				LayoutOrder = plotIndex,
				BackgroundColor3 = Color3.fromRGB(20, 45, 85),
				BorderSizePixel = 0,
			}, hubList)
			create("UICorner", { CornerRadius = UDim.new(0, 8) }, row)
			create("TextLabel", {
				Position = UDim2.fromOffset(8, 4),
				Size = UDim2.new(1, -80, 0, 20),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = COLOR_WHITE,
				Text = `Festival #{plotIndex}{stars}`,
			}, row)
			local visitButton = create("TextButton", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -6, 0, 4),
				Size = UDim2.fromOffset(64, 20),
				BackgroundColor3 = COLOR_CYAN,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBold,
				TextSize = 11,
				TextColor3 = COLOR_NAVY,
				Text = "Visit",
			}, row) :: TextButton
			create("UICorner", { CornerRadius = UDim.new(0, 6) }, visitButton)
			visitButton.Activated:Connect(function()
				Net.Client.Fire("RequestVisit", plotIndex)
			end)

			-- 1-5 star rating row (§6 — 1 vote/host/day, server-enforced).
			for star = 1, 5 do
				local starButton = create("TextButton", {
					Position = UDim2.fromOffset(8 + (star - 1) * 30, 28),
					Size = UDim2.fromOffset(26, 20),
					BackgroundColor3 = COLOR_NAVY,
					BorderSizePixel = 0,
					Font = Enum.Font.GothamBold,
					TextSize = 12,
					TextColor3 = COLOR_GOLD,
					Text = `{star}★`,
				}, row) :: TextButton
				create("UICorner", { CornerRadius = UDim.new(0, 4) }, starButton)
				starButton.Activated:Connect(function()
					Net.Client.Fire("RequestRate", ownerId, star)
				end)
			end
		end
	end
	hubPanel:GetPropertyChangedSignal("Visible"):Connect(function()
		if hubPanel.Visible then
			rebuildHub()
		end
	end)

	makeToggle("💎", 1, storePanel)
	makeToggle("🌐", 2, hubPanel)
end

return UIController
