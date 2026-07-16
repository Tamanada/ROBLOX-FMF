--!strict
-- server/init.server.luau — Sprint 1 bootstrap.
-- Core loop (§2.1): join → plot → campfire → buy/upgrade → revenue accrues
-- → collect → reinvest. Remaining services stay stubs until their sprint
-- (§12).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Net"))
local DataService = require(script.Services.DataService)
local PlotService = require(script.Services.PlotService)
local EconomyService = require(script.Services.EconomyService)
local HypeService = require(script.Services.HypeService)
local BuildService = require(script.Services.BuildService)

Net.Server.Start()
DataService.Init()
PlotService.Init()
EconomyService.Init()
HypeService.Init()
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
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player: Player)
	-- Order matters: bank the uncollected pool into the profile BEFORE the
	-- session is released and saved.
	BuildService.UntrackPlayer(player)
	EconomyService.CleanupPlayer(player)
	PlotService.Release(player)
	DataService.Release(player) -- §10.4 — save on leave
end)

game:BindToClose(function()
	DataService.ReleaseAll()
end)

print("[FMF] Sprint 1 server ready — core loop online (buy → earn → collect → reinvest).")
