--!strict
-- server/Services/DataService.luau — Blueprint §10.4 (persistance).
--   * ProfileStore (MadStudio) with session-locking: zero item duplication;
--   * versioned schema (dataVersion) + ordered migration functions, same
--     discipline as Prisma migrations;
--   * autosave every 60 s + save on leave + SaveNow() hook for post-Robux
--     transaction saves (used by MonetizationService from Sprint 5).
-- The ProfileStore implementation is injectable so tests can run against
-- tests/Mocks/MockProfileStore without touching real DataStores.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Economy = require(ReplicatedStorage.Shared.Config.Economy)

local DataService = {}

-- Bump this when adding a migration below.
DataService.DATA_VERSION = 1
DataService.AUTOSAVE_INTERVAL_SECONDS = Economy.AUTOSAVE_INTERVAL_SECONDS

-- Schéma joueur v1 (§10.4). ProfileStore deep-copies this template per
-- profile and Reconcile() fills any missing keys on old saves.
-- Starting balance: §3.2 amendment (Sprint 1) — enables the D0 hook.
local TEMPLATE: Types.PlayerData = {
	dataVersion = 1,
	shells = Economy.STARTING_SHELLS,
	moonShards = 0,
	hype = 0,
	prestigeCount = 0,
	plots = {},
	staff = {},
	stats = {
		totalEarned = 0,
		fullMoonsAttended = 0,
		visits = 0,
	},
	passes = {},
	lastSeen = 0,
}

DataService.TEMPLATE = TEMPLATE

--------------------------------------------------------------------------
-- Migrations
--------------------------------------------------------------------------

-- MIGRATIONS[n] upgrades a profile from dataVersion n-1 to n, mutating
-- `data` in place. Applied in order by Migrate() after Reconcile().
--
-- Stub example for the day v2 ships:
--   MIGRATIONS[2] = function(data)
--       data.newField = defaultValue
--   end
local MIGRATIONS: { [number]: (data: any) -> () } = {}

-- Pure engine, exposed for tests: upgrades `data` step by step until
-- `targetVersion`, erroring loudly if a step is missing (a hole in the
-- migration chain must never be silent).
function DataService.MigrateTo(
	data: any,
	targetVersion: number,
	migrations: { [number]: (data: any) -> () }
): any
	local version = if type(data.dataVersion) == "number" then data.dataVersion else 1

	while version < targetVersion do
		local nextVersion = version + 1
		local migration = migrations[nextVersion]
		if migration == nil then
			error(`[DataService] missing migration to dataVersion {nextVersion}`)
		end
		migration(data)
		version = nextVersion
		data.dataVersion = nextVersion
	end

	return data
end

function DataService.Migrate(data: any): any
	return DataService.MigrateTo(data, DataService.DATA_VERSION, MIGRATIONS)
end

--------------------------------------------------------------------------
-- Session lifecycle
--------------------------------------------------------------------------

local playerStore: any = nil
local profiles: { [Player]: any } = {}
-- lastSeen value as it was in the SAVED data, captured before this session
-- stamps it — the basis for offline earnings (§2.4).
local previousLastSeen: { [Player]: number } = {}

export type InitOptions = {
	-- ProfileStore-compatible module (tests inject a mock here).
	profileStore: any?,
	storeName: string?,
}

function DataService.Init(options: InitOptions?)
	if playerStore ~= nil then
		return
	end

	local opts: InitOptions = options or {}
	local profileStoreModule = opts.profileStore
		or require(script.Parent.Parent.Packages.ProfileStore) :: any
	playerStore = profileStoreModule.New(opts.storeName or "PlayerData", TEMPLATE)
end

local function startAutosave(player: Player, profile: any)
	-- §10.4 — autosave 60 s. ProfileStore has its own periodic save; this
	-- explicit loop enforces the Blueprint interval regardless of its default.
	task.spawn(function()
		while profiles[player] == profile do
			task.wait(DataService.AUTOSAVE_INTERVAL_SECONDS)
			if profiles[player] == profile and profile:IsActive() then
				profile.Data.lastSeen = os.time()
				profile:Save()
			end
		end
	end)
end

-- Loads (or creates) the player's profile with session-locking.
-- Returns nil if the session could not be claimed — the player is kicked.
function DataService.LoadAsync(player: Player): any?
	assert(playerStore ~= nil, "[DataService] Init() must be called before LoadAsync()")

	local profile = playerStore:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		-- Another server still holds the session lock (§10.4: zéro duplication).
		player:Kick("[FMF] Your data is locked by another session. Please rejoin in a moment.")
		return nil
	end

	profile:AddUserId(player.UserId) -- GDPR / right-to-erasure traceability
	profile:Reconcile() -- fill missing keys from TEMPLATE
	DataService.Migrate(profile.Data)

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("[FMF] Data session ended. Please rejoin.")
	end)

	if player.Parent ~= Players then
		-- Player left while the session was being claimed.
		profile:EndSession()
		return nil
	end

	profiles[player] = profile
	previousLastSeen[player] = profile.Data.lastSeen
	profile.Data.lastSeen = os.time()
	startAutosave(player, profile)
	return profile
end

-- Returns the lastSeen timestamp from the loaded save (0 on first join),
-- i.e. the offline-earnings basis — LoadAsync overwrites Data.lastSeen.
function DataService.GetPreviousLastSeen(player: Player): number?
	return previousLastSeen[player]
end

function DataService.Get(player: Player): Types.PlayerData?
	local profile = profiles[player]
	return if profile ~= nil then profile.Data else nil
end

-- §10.4 — save post-transaction Robux (called by MonetizationService, S5).
function DataService.SaveNow(player: Player)
	local profile = profiles[player]
	if profile ~= nil and profile:IsActive() then
		profile.Data.lastSeen = os.time()
		profile:Save()
	end
end

-- §10.4 — save on leave. EndSession flushes to the DataStore and releases
-- the session lock.
function DataService.Release(player: Player)
	local profile = profiles[player]
	previousLastSeen[player] = nil
	if profile ~= nil then
		profiles[player] = nil
		profile.Data.lastSeen = os.time()
		profile:EndSession()
	end
end

function DataService.ReleaseAll()
	for player in profiles do
		DataService.Release(player)
	end
end

-- Test hook: forget the singleton store/profiles so specs can re-Init with
-- a mock. Never call from game code.
function DataService._resetForTests()
	for player in profiles do
		profiles[player] = nil
	end
	for player in previousLastSeen do
		previousLastSeen[player] = nil
	end
	playerStore = nil
end

return DataService
