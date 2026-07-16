--!strict
-- server/Services/NPCService.luau — Blueprint §2.1, §3.3, §10.6 (living crowd).
-- NPC partygoers arrive by boat-taxi, walk to a working equipment, linger,
-- then leave. They are the VISUALISATION of the Hype-driven throughput — the
-- authoritative Shells still accrue in BuildService at the §4 night rate
-- (server-authoritative economy, §10.3), so the crowd density and the revenue
-- are two views of the same Hype signal and stay in sync without letting NPC
-- spawns drive (or be exploited into) the economy.
--
-- Performance budget (§10.6):
--   * hard cap NPC_MAX_PER_PLOT (40) partygoers per plot;
--   * ONE Heartbeat connection moves every NPC (no per-NPC Heartbeat), ONE
--     top-up loop spawns them (no PathfindingService per NPC per tick —
--     movement is a straight waypoint walk);
--   * movement freezes beyond NPC_ANIMATION_LOD_STUDS from the owner (the LOD
--     gate that will also disable rig Animators once real models land).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Economy = require(ReplicatedStorage.Shared.Config.Economy)

local EventService = require(script.Parent.EventService)
local FullMoonService = require(script.Parent.FullMoonService)
local PlotService = require(script.Parent.PlotService)

local NPCService = {}

-- §9 — neon palette for the crowd (cyan / magenta / lime / gold).
local PALETTE = {
	Color3.fromRGB(0, 229, 255),
	Color3.fromRGB(255, 46, 146),
	Color3.fromRGB(180, 255, 57),
	Color3.fromRGB(255, 209, 102),
}

local GROUND_OFFSET = 3
local REACH_THRESHOLD = 2

type NPC = {
	model: Model,
	waypoints: { Vector3 },
	index: number,
	stayUntil: number,
}

type PlotCrowd = {
	player: Player,
	data: Types.PlayerData,
	origin: CFrame,
	folder: Folder,
	npcs: { NPC },
}

local crowds: { [Player]: PlotCrowd } = {}
local container: Folder? = nil
-- Server-lifetime singletons: stored (never orphaned) rather than read back.
local _managerConnection: RBXScriptConnection? = nil
local _topupThread: thread? = nil
local started = false

--------------------------------------------------------------------------
-- Pure helper (unit-tested in tests/World.spec.luau)
--------------------------------------------------------------------------

-- §3.3 — crowd target = base × (1 + Hype/50) × phase density × Full Moon
-- multiplier, capped at the per-plot limit (§10.6). Night is a dense crowd,
-- day is calm (§2.2); the Full Moon spawns ×3 (§2.3).
function NPCService._spawnTarget(hype: number, isNight: boolean, fullMoonMultiplier: number): number
	local density = if isNight then Economy.NPC_NIGHT_DENSITY else Economy.NPC_DAY_DENSITY
	local target = Economy.NPC_SPAWN_BASE * (1 + hype / Economy.HYPE_SPAWN_DIVISOR) * density * fullMoonMultiplier
	return math.min(Economy.NPC_MAX_PER_PLOT, math.floor(target))
end

--------------------------------------------------------------------------
-- NPC construction
--------------------------------------------------------------------------

local function makeNPCModel(spawnPosition: Vector3, color: Color3): Model
	local model = Instance.new("Model")
	model.Name = "Partygoer"

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.CanCollide = false
	body.Size = Vector3.new(1.6, 3, 1.2)
	body.Color = color
	body.Material = Enum.Material.Neon
	body.CFrame = CFrame.new(spawnPosition)
	body.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Anchored = true
	head.CanCollide = false
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.2, 1.2, 1.2)
	head.Color = Color3.fromRGB(232, 220, 192) -- sable lunaire (§9)
	head.CFrame = CFrame.new(spawnPosition + Vector3.new(0, 2.1, 0))
	head.Parent = model

	model.PrimaryPart = body
	return model
end

local function pivotNPC(npc: NPC, position: Vector3, facing: Vector3?)
	local cframe: CFrame
	if facing ~= nil and (facing - position).Magnitude > 0.01 then
		cframe = CFrame.lookAt(position, Vector3.new(facing.X, position.Y, facing.Z))
	else
		cframe = CFrame.new(position)
	end
	npc.model:PivotTo(cframe)
end

local function spawnNPC(crowd: PlotCrowd)
	local arrivalCFrame = PlotService.GetArrivalCFrame(crowd.player)
	if arrivalCFrame == nil then
		return
	end

	local groundY = crowd.origin.Position.Y + GROUND_OFFSET
	local arrival = Vector3.new(arrivalCFrame.Position.X, groundY, arrivalCFrame.Position.Z)

	-- Route to a random working equipment; fall back to the plot centre.
	local equipment = PlotService.GetEquipmentPositions(crowd.player)
	local destination: Vector3
	if #equipment > 0 then
		local pick = equipment[(#crowd.npcs % #equipment) + 1]
		destination = Vector3.new(pick.X, groundY, pick.Z)
	else
		destination = Vector3.new(crowd.origin.Position.X, groundY, crowd.origin.Position.Z)
	end

	local color = PALETTE[(#crowd.npcs % #PALETTE) + 1]
	local npc: NPC = {
		model = makeNPCModel(arrival, color),
		-- walk in to the equipment, linger, then walk back out to the boat.
		waypoints = { destination, arrival },
		index = 1,
		stayUntil = 0,
	}
	npc.model.Parent = crowd.folder
	table.insert(crowd.npcs, npc)
end

--------------------------------------------------------------------------
-- Movement (single Heartbeat manager — §10.6)
--------------------------------------------------------------------------

local function ownerWithinLOD(crowd: PlotCrowd): boolean
	local character = crowd.player.Character
	if character == nil then
		-- No character yet: keep the crowd frozen (nobody is watching).
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	local plotCentre = crowd.origin.Position
	local radius = Economy.NPC_ANIMATION_LOD_STUDS + PlotService.PLOT_SIZE.X / 2
	return (root.Position - plotCentre).Magnitude <= radius
end

local function stepNPC(crowd: PlotCrowd, npc: NPC, dt: number, now: number): boolean
	-- Returns true when the NPC should be removed (reached the boat again).
	if npc.stayUntil > now then
		return false
	end

	local target: Vector3? = npc.waypoints[npc.index]
	if target == nil then
		return true
	end

	local position = npc.model:GetPivot().Position
	local delta = target - position
	local distance = delta.Magnitude

	if distance <= REACH_THRESHOLD then
		if npc.index == 1 then
			-- Arrived at the equipment: linger (§2.1 — they consume here).
			npc.stayUntil = now + Economy.NPC_STAY_SECONDS
			npc.index += 1
			return false
		end
		-- Reached the exit boat.
		return true
	end

	local stepDistance = math.min(Economy.NPC_WALK_SPEED * dt, distance)
	pivotNPC(npc, position + delta.Unit * stepDistance, target)
	return false
end

local function stepCrowd(crowd: PlotCrowd, dt: number, now: number)
	if not ownerWithinLOD(crowd) then
		return -- §10.6 — freeze distant crowds.
	end
	local survivors: { NPC } = {}
	for _, npc in crowd.npcs do
		if stepNPC(crowd, npc, dt, now) then
			npc.model:Destroy()
		else
			table.insert(survivors, npc)
		end
	end
	crowd.npcs = survivors
end

--------------------------------------------------------------------------
-- Top-up (single loop — §10.6)
--------------------------------------------------------------------------

local function topupCrowd(crowd: PlotCrowd)
	local fullMoon = if FullMoonService.IsActive() then Economy.FULL_MOON_SPAWN_MULTIPLIER else 1
	-- §8.1 — Golden Longtail Boat pass boosts NPC arrivals (attribute set by
	-- MonetizationService); the per-plot cap in _spawnTarget still applies.
	local arrivalAttr = crowd.player:GetAttribute("NPCArrivalMultiplier")
	local arrival = if type(arrivalAttr) == "number" then arrivalAttr else 1
	local target = NPCService._spawnTarget(crowd.data.hype, EventService.IsNight(), fullMoon * arrival)
	local deficit = target - #crowd.npcs
	if deficit <= 0 then
		return
	end
	local spawns = math.min(deficit, Economy.NPC_MAX_SPAWNS_PER_TOPUP)
	for _ = 1, spawns do
		if #crowd.npcs >= Economy.NPC_MAX_PER_PLOT then
			break
		end
		spawnNPC(crowd)
	end
end

--------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------

function NPCService.Init()
	if started then
		return
	end
	started = true

	local folder = Instance.new("Folder")
	folder.Name = "FMF_NPCs"
	folder.Parent = Workspace
	container = folder

	-- ONE Heartbeat drives every NPC's movement (§10.6).
	_managerConnection = RunService.Heartbeat:Connect(function(dt: number)
		local now = os.clock()
		for _, crowd in crowds do
			stepCrowd(crowd, dt, now)
		end
	end)

	-- ONE loop tops up every crowd toward its Hype/phase target.
	_topupThread = task.spawn(function()
		while true do
			task.wait(Economy.NPC_TOPUP_INTERVAL_SECONDS)
			for _, crowd in crowds do
				topupCrowd(crowd)
			end
		end
	end)
end

function NPCService.TrackPlayer(player: Player, data: Types.PlayerData)
	if crowds[player] ~= nil then
		return
	end
	local origin = PlotService.GetPlotOrigin(player)
	if origin == nil then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = `Crowd_{player.UserId}`
	folder.Parent = container

	crowds[player] = {
		player = player,
		data = data,
		origin = origin,
		folder = folder,
		npcs = {},
	}
end

function NPCService.UntrackPlayer(player: Player)
	local crowd = crowds[player]
	if crowd == nil then
		return
	end
	crowds[player] = nil
	crowd.folder:Destroy()
end

return NPCService
