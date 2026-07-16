--!strict
-- server/init.server.luau — Sprint 2 bootstrap.
-- Core loop (§2.1): join → plot → campfire → buy/upgrade → revenue accrues
-- → collect → reinvest, now inside the living world (§2.2 day/night cycle,
-- §7 beach cleanup, NPC crowd). Remaining services stay stubs until their
-- sprint (§12).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Net"))
local DataService = require(script.Services.DataService)
local PlotService = require(script.Services.PlotService)
local EconomyService = require(script.Services.EconomyService)
local HypeService = require(script.Services.HypeService)
local EventService = require(script.Services.EventService)
local FullMoonService = require(script.Services.FullMoonService)
local NPCService = require(script.Services.NPCService)
local BuildService = require(script.Services.BuildService)

Net.Server.Start()
DataService.Init()
PlotService.Init()
EconomyService.Init()
HypeService.Init()
EventService.Init() -- §2.2 day/night cycle + §7 cleanup — the world heartbeat
FullMoonService.Init() -- §2.3 global UTC Full Moon clock + multipliers
NPCService.Init() -- §2.1 living crowd
BuildService.Init()

local function onPlayerAdded(player: Player)
	local profile = DataService.LoadAsync(player)
	if profile == nil then
		-- Session could not be claimed; the player was kicked by DataService.
		return
	end

	local data = DataService.Get(player)
	if data == nil then
		-- Player left between load and assignment.
		return
	end

	if PlotService.Assign(player, data) == nil then
		return
	end
	EconomyService.SetupPlayer(player, data)
	BuildService.TrackPlayer(player, data)
	-- §2.2/§7 — enrol in the cycle's cleanup flashes; §2.1 — start the crowd;
	-- §2.3 — count toward Full Moon attendance/rewards.
	EventService.TrackPlayer(player)
	FullMoonService.TrackPlayer(player)
	NPCService.TrackPlayer(player, data)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player: Player)
	-- Order matters: bank the uncollected pool into the profile BEFORE the
	-- session is released and saved.
	NPCService.UntrackPlayer(player)
	FullMoonService.UntrackPlayer(player)
	EventService.UntrackPlayer(player)
	BuildService.UntrackPlayer(player)
	HypeService.CleanupPlayer(player)
	EconomyService.CleanupPlayer(player)
	PlotService.Release(player)
	DataService.Release(player) -- §10.4 — save on leave
end)

game:BindToClose(function()
	DataService.ReleaseAll()
end)

print("[FMF] Sprint 3 server ready — Full Moon online (UTC-synced ×5, Moon Shards, sky transform).")
