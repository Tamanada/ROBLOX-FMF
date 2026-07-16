--!strict
-- server/Services/EventService.luau — Blueprint §2.2, §3.3, §7 (monde vivant).
-- Sprint 2 scope: this service owns the world heartbeat.
--   * Day/night cycle (§2.2): 16 min = 10 min Day / 6 min Night, per server.
--     The phase drives the revenue multiplier (BuildService reads it: day pays
--     ½ the night rate → night is ×2), NPC crowd density (NPCService), and the
--     client ambiance (§9) via replicated Workspace attributes.
--   * Per-cycle Hype decay (§3.3): −5 at each cycle boundary if the beach is
--     dirty OR any equipment is broken.
--   * Beach Cleanup Flash (§7): after each night, spawn 10 trash on every
--     plot; collect them within 60 s → +5 Hype.
-- The weather / monkeys / VIP boat events (§7) are added to this same service
-- in Sprint 4 (Roadmap §12).
--
-- Server-authoritative (§10.3): trash pickup is validated server-side against
-- the trash's real owner (ProximityPrompt.Triggered carries the true player,
-- so no client-supplied id can forge a pickup); the +5 Hype is granted only
-- once, on genuine completion inside the window.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Net = require(ReplicatedStorage.Shared.Util.Net)

local DataService = require(script.Parent.DataService)
local HypeService = require(script.Parent.HypeService)
local PlotService = require(script.Parent.PlotService)

local EventService = {}

-- Replicated to clients for ambiance (§9). Read-only display channel. The
-- server reads the live phase via GetPhase()/IsNight(); NPCService polls it.
local ATTR_PHASE = "FMF_Phase"
local ATTR_IS_NIGHT = "FMF_IsNight"
local ATTR_PHASE_ENDS_AT = "FMF_PhaseEndsAt"

type Cleanup = {
	active: boolean,
	completed: boolean, -- finished the flash this cycle? (true before any night)
	collected: number,
	folder: Folder,
	trash: { [number]: BasePart },
}

local tracked: { [Player]: boolean } = {}
local cleanups: { [Player]: Cleanup } = {}
local cleanupContainer: Folder? = nil

local currentPhase: Types.CyclePhase = "Day"
local startClock = 0
local started = false

-- §7 live events. Handlers are pushed IN by BuildService (equipment damage /
-- Shells theft) so EventService never requires it back — no cycles.
local rng = Random.new()
local damageHandler: ((player: Player, count: number) -> ())? = nil
local stealHandler: ((player: Player, fraction: number) -> ())? = nil
local stormActiveUntil = 0 -- os.clock() timeline
local vipActiveUntil = 0

--------------------------------------------------------------------------
-- Pure helpers (unit-tested in tests/World.spec.luau)
--------------------------------------------------------------------------

-- §2.2 — phase from the position inside a single cycle. `secondsIntoCycle`
-- is expected in [0, CYCLE_DURATION_SECONDS). Local (used by the cycle driver's
-- change detection) plus a thin table wrapper for tests.
local function phaseAt(secondsIntoCycle: number): Types.CyclePhase
	return if secondsIntoCycle < Economy.DAY_DURATION_SECONDS then "Day" else "Night"
end

-- Thin wrapper exposed for tests (a direct field assignment would widen the
-- local's singleton-union return to `string` for internal callers too).
function EventService._phaseAt(secondsIntoCycle: number): Types.CyclePhase
	return phaseAt(secondsIntoCycle)
end

-- Seconds remaining until the next phase boundary.
function EventService._phaseRemaining(secondsIntoCycle: number): number
	if secondsIntoCycle < Economy.DAY_DURATION_SECONDS then
		return Economy.DAY_DURATION_SECONDS - secondsIntoCycle
	end
	return Economy.CYCLE_DURATION_SECONDS - secondsIntoCycle
end

-- §2.2 — multiplier applied to the catalogue NIGHT rate: night pays it in
-- full (×1), day pays half → night is ×2 of day.
function EventService._revenueMultiplierFor(phase: Types.CyclePhase): number
	return if phase == "Night" then 1 else Economy.DAY_REVENUE_MULTIPLIER
end

-- §7 — the flash is won when enough trash is collected before the window ends.
function EventService._isCleanupComplete(collected: number, threshold: number): boolean
	return collected >= threshold
end

--------------------------------------------------------------------------
-- Public phase API
--------------------------------------------------------------------------

function EventService.GetPhase(): Types.CyclePhase
	return currentPhase
end

function EventService.IsNight(): boolean
	return currentPhase == "Night"
end

-- BuildService multiplies its accrual by this each tick (§2.2 night ×2).
function EventService.GetRevenueMultiplier(): number
	return EventService._revenueMultiplierFor(currentPhase)
end

-- §7 — server-wide temporary event multiplier: storm halves revenue, a VIP
-- boat boosts it. BuildService stacks this on the phase/Full Moon multipliers.
function EventService.GetEventRevenueMultiplier(): number
	local now = os.clock()
	local multiplier = 1
	if now < stormActiveUntil then
		multiplier *= Economy.STORM_REVENUE_MULTIPLIER
	end
	if now < vipActiveUntil then
		multiplier *= Economy.VIP_REVENUE_MULTIPLIER
	end
	return multiplier
end

-- §7 — BuildService injects the equipment-damage / Shells-theft handlers.
function EventService.SetDamageHandler(handler: (player: Player, count: number) -> ())
	damageHandler = handler
end

function EventService.SetStealHandler(handler: (player: Player, fraction: number) -> ())
	stealHandler = handler
end

--------------------------------------------------------------------------
-- Beach Cleanup Flash (§7)
--------------------------------------------------------------------------

local function pushCleanupState(player: Player, cleanup: Cleanup)
	Net.Server.Fire("CleanupState", player, {
		active = cleanup.active,
		collected = cleanup.collected,
		total = Economy.CLEANUP_TRASH_COUNT,
	})
end

local function closeCleanup(player: Player)
	local cleanup = cleanups[player]
	if cleanup == nil then
		return
	end
	cleanup.active = false
	for _, part in cleanup.trash do
		part:Destroy()
	end
	table.clear(cleanup.trash)
	pushCleanupState(player, cleanup)
end

local function onTrashTriggered(player: Player, trashId: number)
	local cleanup = cleanups[player]
	if cleanup == nil or not cleanup.active then
		return
	end
	local part: BasePart? = cleanup.trash[trashId]
	if part == nil then
		return
	end

	cleanup.trash[trashId] = nil
	part:Destroy()
	cleanup.collected += 1

	if not cleanup.completed and EventService._isCleanupComplete(cleanup.collected, Economy.CLEANUP_TRASH_COUNT) then
		cleanup.completed = true
		local data = DataService.Get(player)
		if data ~= nil then
			-- §7 — +5 Hype, granted once per flash.
			HypeService.AddCleanupBonus(player, data, Economy.CLEANUP_HYPE_BONUS)
		end
		Net.Server.Fire("Notify", player, `Beach cleaned! +{Economy.CLEANUP_HYPE_BONUS} Hype 🧹`)
		closeCleanup(player)
	else
		pushCleanupState(player, cleanup)
	end
end

local function spawnTrash(player: Player)
	local cleanup = cleanups[player]
	local origin = PlotService.GetPlotOrigin(player)
	if cleanup == nil or origin == nil then
		return
	end

	-- Fresh window: a night just ended, the beach is dirty again (§7).
	closeCleanup(player)
	cleanup.active = true
	cleanup.completed = false
	cleanup.collected = 0

	local size = PlotService.PLOT_SIZE
	local halfX = size.X / 2 - 6
	local halfZ = size.Z / 2 - 6

	for id = 1, Economy.CLEANUP_TRASH_COUNT do
		-- Scatter without a per-call RNG dependency: hash the id across the
		-- plot area (deterministic, exploit-irrelevant placement).
		local fx = ((id * 37) % 100) / 100 - 0.5
		local fz = ((id * 61) % 100) / 100 - 0.5
		local part = Instance.new("Part")
		part.Name = "Trash"
		part.Anchored = true
		part.CanCollide = false
		part.Size = Vector3.new(1.4, 1.4, 1.4)
		part.Material = Enum.Material.Grass
		part.Color = Color3.fromRGB(120, 110, 70)
		part.CFrame = origin * CFrame.new(fx * 2 * halfX, 1, fz * 2 * halfZ)
		part:SetAttribute("TrashId", id)
		part:SetAttribute("OwnerUserId", player.UserId)

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Pick up"
		prompt.ObjectText = "Trash"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = part

		local capturedId = id
		prompt.Triggered:Connect(function(triggerPlayer: Player)
			-- §10.3 — server-authoritative: only the plot owner can clean it.
			if triggerPlayer == player then
				onTrashTriggered(player, capturedId)
			end
		end)

		part.Parent = cleanup.folder
		cleanup.trash[id] = part
	end

	pushCleanupState(player, cleanup)

	-- Auto-close the flash when the 60 s window elapses (§7).
	task.delay(Economy.CLEANUP_WINDOW_SECONDS, function()
		local current = cleanups[player]
		if current == cleanup and cleanup.active then
			closeCleanup(player)
		end
	end)
end

--------------------------------------------------------------------------
-- Cycle transitions
--------------------------------------------------------------------------

local function anyEquipmentBroken(data: Types.PlayerData): boolean
	local slot = data.plots[Economy.MAIN_PLOT_SLOT]
	if slot == nil then
		return false
	end
	for _, entry in slot.equipment do
		if entry.broken then
			return true
		end
	end
	return false
end

-- Night → Day: open the Beach Cleanup Flash on every plot (§7).
local function onNightEnded()
	for player in tracked do
		spawnTrash(player)
	end
end

-- Day → Night: the cycle just completed. Apply Hype decay (§3.3) — dirty
-- (cleanup unfinished) OR broken equipment costs −5 — then expire any leftover
-- cleanup window.
local function onDayEnded()
	for player in tracked do
		local cleanup = cleanups[player]
		local data = DataService.Get(player)
		if data ~= nil then
			local isDirty = cleanup ~= nil and not cleanup.completed
			HypeService.ApplyCycleDecay(player, data, isDirty, anyEquipmentBroken(data))
		end
		if cleanup ~= nil and cleanup.active then
			closeCleanup(player)
		end
		-- §4 — ambient wear: a small chance one equipment breaks each cycle.
		if damageHandler ~= nil and rng:NextNumber() < Economy.AMBIENT_BREAK_CHANCE then
			damageHandler(player, 1)
		end
	end
end

-- Computes the phase itself from `secondsIntoCycle` so callers never pass a
-- refined value (inside `if phase ~= currentPhase`, Luau widens the refined
-- `phase` to `string`). The literals are pinned to CyclePhase via the local's
-- annotation.
local function applyPhase(secondsIntoCycle: number)
	local isNight = secondsIntoCycle >= Economy.DAY_DURATION_SECONDS
	local phase: Types.CyclePhase = if isNight then "Night" else "Day"
	currentPhase = phase
	Workspace:SetAttribute(ATTR_PHASE, phase)
	Workspace:SetAttribute(ATTR_IS_NIGHT, isNight)
	local remaining = EventService._phaseRemaining(secondsIntoCycle)
	Workspace:SetAttribute(ATTR_PHASE_ENDS_AT, os.time() + math.floor(remaining + 0.5))
end

--------------------------------------------------------------------------
-- Live events (§7 — tempête, singes, VIP)
--------------------------------------------------------------------------

-- Next trigger time with ±50 % jitter around the average interval.
local function scheduleNext(intervalSeconds: number): number
	return os.clock() + intervalSeconds * (0.5 + rng:NextNumber())
end

-- §7 — Tropical storm: 60 s warning, then 1-3 equipment damaged per festival
-- and revenue −50 % for 90 s.
local function triggerStorm()
	Net.Server.FireAll("Notify", "⛈️ Storm warning — a tropical storm rolls in within 60s!")
	task.delay(Economy.STORM_WARNING_SECONDS, function()
		stormActiveUntil = os.clock() + Economy.STORM_DURATION_SECONDS
		Net.Server.FireAll("Notify", "⛈️ The storm hits — revenue halved, equipment at risk!")
		if damageHandler ~= nil then
			for player in tracked do
				damageHandler(player, rng:NextInteger(Economy.STORM_MIN_DAMAGE, Economy.STORM_MAX_DAMAGE))
			end
		end
	end)
end

-- §7 — Robber monkeys steal from every festival's uncollected pool.
local function triggerMonkeys()
	Net.Server.FireAll("Notify", "🐒 Robber monkeys raid the beach — collect your Shells!")
	if stealHandler ~= nil then
		for player in tracked do
			stealHandler(player, Economy.MONKEY_STEAL_FRACTION)
		end
	end
end

-- §7 — VIP boat arrives only if the server's festival is hot (Hype ≥ 50).
local function serverMeetsVIP(): boolean
	for player in tracked do
		local data = DataService.Get(player)
		if data ~= nil and data.hype >= Economy.VIP_HYPE_REQUIREMENT then
			return true
		end
	end
	return false
end

local function triggerVIP()
	vipActiveUntil = os.clock() + Economy.VIP_DURATION_SECONDS
	Net.Server.FireAll("Notify", "🛥️ A VIP boat docks — big spenders for the next minute!")
end

local function startEventScheduler()
	local stormAt = scheduleNext(Economy.STORM_INTERVAL_SECONDS)
	local monkeyAt = scheduleNext(Economy.MONKEY_INTERVAL_SECONDS)
	local vipAt = scheduleNext(Economy.VIP_INTERVAL_SECONDS)

	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			if now >= stormAt then
				triggerStorm()
				stormAt = scheduleNext(Economy.STORM_INTERVAL_SECONDS)
			end
			if now >= monkeyAt then
				triggerMonkeys()
				monkeyAt = scheduleNext(Economy.MONKEY_INTERVAL_SECONDS)
			end
			if now >= vipAt then
				if serverMeetsVIP() then
					triggerVIP()
				end
				vipAt = scheduleNext(Economy.VIP_INTERVAL_SECONDS)
			end
		end
	end)
end

--------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------

function EventService.Init()
	if started then
		return
	end
	started = true

	local container = Instance.new("Folder")
	container.Name = "FMF_Cleanup"
	container.Parent = Workspace
	cleanupContainer = container

	Net.Server.Declare("CleanupState")

	startClock = os.clock()
	-- §2.2 — start in Day (construction / preparation first): secondsIntoCycle 0.
	applyPhase(0)

	-- §7 — schedule the tropical storm / monkeys / VIP boat.
	startEventScheduler()

	-- Cycle driver: 1 s granularity is ample for a 16-minute cycle.
	task.spawn(function()
		while true do
			task.wait(1)
			local secondsIntoCycle = (os.clock() - startClock) % Economy.CYCLE_DURATION_SECONDS
			if phaseAt(secondsIntoCycle) ~= currentPhase then
				if currentPhase == "Night" then
					onNightEnded()
				else
					onDayEnded()
				end
				applyPhase(secondsIntoCycle)
			end
		end
	end)
end

function EventService.TrackPlayer(player: Player)
	if tracked[player] then
		return
	end
	tracked[player] = true

	local folder = Instance.new("Folder")
	folder.Name = `Cleanup_{player.UserId}`
	folder.Parent = cleanupContainer

	cleanups[player] = {
		active = false,
		completed = true, -- not dirty until the first night ends
		collected = 0,
		folder = folder,
		trash = {},
	}
end

function EventService.UntrackPlayer(player: Player)
	tracked[player] = nil
	local cleanup = cleanups[player]
	if cleanup ~= nil then
		cleanups[player] = nil
		cleanup.folder:Destroy()
	end
end

return EventService
