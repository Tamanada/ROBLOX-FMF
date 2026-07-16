--!strict
-- server/Services/PlotService.luau — Blueprint §6 / §10.2.
-- 12 plots per server: assignment on join, release on leave, reload of the
-- player's saved equipment onto their plot.
-- Sprint 0 scope: equipment is reloaded as placeholder anchored parts —
-- real equipment models/logic belong to BuildService (Sprint 1).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Serde = require(ReplicatedStorage.Shared.Util.Serde)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)

local PLOT_COUNT: number = Economy.PLOTS_PER_SERVER -- 12 (§6)
local PLOT_SIZE = Vector3.new(96, 1, 96)
local PLOT_GAP = 32
local PLOTS_PER_ROW = 4

-- Save slot key inside PlayerData.plots. The "Extra Plot Slot" Game Pass
-- (§8.1) introduces additional slots in Sprint 5.
local MAIN_SLOT = "main"

type PlotRuntime = {
	index: number,
	model: Model,
	origin: CFrame,
	equipmentFolder: Folder,
	spawnPart: BasePart,
	ownerUserId: number?,
}

local plots: { PlotRuntime } = {}
local plotByPlayer: { [Player]: PlotRuntime } = {}
local initialized = false

local PlotService = {}

--------------------------------------------------------------------------
-- World setup
--------------------------------------------------------------------------

local function buildPlot(index: number, parent: Folder): PlotRuntime
	-- Grid layout along the beach; Studio-authored plots replace this
	-- procedural placeholder later (Studio = placement 3D only, §10.1).
	local row = math.floor((index - 1) / PLOTS_PER_ROW)
	local column = (index - 1) % PLOTS_PER_ROW
	local origin = CFrame.new(
		column * (PLOT_SIZE.X + PLOT_GAP),
		PLOT_SIZE.Y / 2,
		row * (PLOT_SIZE.Z + PLOT_GAP)
	)

	local model = Instance.new("Model")
	model.Name = `Plot_{index}`

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Anchored = true -- §10.6 — parts anchored
	base.Size = PLOT_SIZE
	base.CFrame = origin
	base.Material = Enum.Material.Sand
	base.Color = Color3.fromRGB(232, 220, 192) -- sable lunaire #E8DCC0 (§9)
	base.Parent = model

	local spawnPart = Instance.new("Part")
	spawnPart.Name = "PlayerSpawn"
	spawnPart.Anchored = true
	spawnPart.CanCollide = false
	spawnPart.Transparency = 1
	spawnPart.Size = Vector3.new(4, 1, 4)
	spawnPart.CFrame = origin * CFrame.new(0, 3, PLOT_SIZE.Z / 2 - 6)
	spawnPart.Parent = model

	local equipmentFolder = Instance.new("Folder")
	equipmentFolder.Name = "Equipment"
	equipmentFolder.Parent = model

	model.PrimaryPart = base
	model:SetAttribute("PlotIndex", index)
	model.Parent = parent

	return {
		index = index,
		model = model,
		origin = origin,
		equipmentFolder = equipmentFolder,
		spawnPart = spawnPart,
		ownerUserId = nil,
	}
end

function PlotService.Init()
	if initialized then
		return
	end
	initialized = true

	local container = Workspace:FindFirstChild("Plots")
	if container == nil or not container:IsA("Folder") then
		local folder = Instance.new("Folder")
		folder.Name = "Plots"
		folder.Parent = Workspace
		container = folder
	end

	for index = 1, PLOT_COUNT do
		table.insert(plots, buildPlot(index, container :: Folder))
	end
end

--------------------------------------------------------------------------
-- Equipment reload (Sprint 0: placeholders)
--------------------------------------------------------------------------

local function spawnEquipmentPlaceholder(plot: PlotRuntime, entry: Types.EquipmentInstance)
	local part = Instance.new("Part")
	part.Name = entry.id
	part.Anchored = true
	part.Size = Vector3.new(4, 4, 4)
	-- Saved CFrames are relative to the plot origin (§10.4 note in Types).
	part.CFrame = plot.origin * Serde.deserializeCFrame(entry.cframe)
	part.Color = if entry.broken
		then Color3.fromRGB(120, 120, 120)
		else Color3.fromRGB(0, 229, 255) -- néon cyan #00E5FF (§9)
	part:SetAttribute("EquipmentId", entry.id)
	part:SetAttribute("Level", entry.level)
	part:SetAttribute("Broken", entry.broken)
	part.Parent = plot.equipmentFolder
end

local function loadSavedEquipment(plot: PlotRuntime, data: Types.PlayerData)
	local slot = data.plots[MAIN_SLOT]
	if slot == nil then
		-- First join: initialize the main save slot.
		data.plots[MAIN_SLOT] = { equipment = {} }
		return
	end

	for _, entry in slot.equipment do
		spawnEquipmentPlaceholder(plot, entry)
	end
end

--------------------------------------------------------------------------
-- Assignment lifecycle
--------------------------------------------------------------------------

local function teleportToPlot(player: Player, plot: PlotRuntime)
	local function place(character: Model)
		character:PivotTo(plot.spawnPart.CFrame + Vector3.new(0, 3, 0))
	end

	player.CharacterAdded:Connect(place)
	if player.Character ~= nil then
		place(player.Character)
	end
end

-- Assigns the first free plot and reloads saved equipment onto it.
-- Returns nil if no plot is free (cannot happen while server size == 12).
function PlotService.Assign(player: Player, data: Types.PlayerData): number?
	assert(initialized, "[PlotService] Init() must be called before Assign()")

	if plotByPlayer[player] ~= nil then
		return plotByPlayer[player].index
	end

	local freePlot: PlotRuntime? = nil
	for _, plot in plots do
		if plot.ownerUserId == nil then
			freePlot = plot
			break
		end
	end

	if freePlot == nil then
		warn(`[PlotService] no free plot for {player.Name} (server misconfigured?)`)
		player:Kick("[FMF] No free festival plot on this server. Please rejoin.")
		return nil
	end

	local plot = freePlot :: PlotRuntime
	plot.ownerUserId = player.UserId
	plot.model:SetAttribute("OwnerUserId", player.UserId)
	plotByPlayer[player] = plot

	loadSavedEquipment(plot, data)
	teleportToPlot(player, plot)

	return plot.index
end

function PlotService.Release(player: Player)
	local plot = plotByPlayer[player]
	if plot == nil then
		return
	end

	plotByPlayer[player] = nil
	plot.ownerUserId = nil
	plot.model:SetAttribute("OwnerUserId", nil)
	plot.equipmentFolder:ClearAllChildren()
end

function PlotService.GetPlotIndex(player: Player): number?
	local plot = plotByPlayer[player]
	return if plot ~= nil then plot.index else nil
end

function PlotService.GetPlotOrigin(player: Player): CFrame?
	local plot = plotByPlayer[player]
	return if plot ~= nil then plot.origin else nil
end

return PlotService
