--!strict
-- server/init.server.luau — Sprint 0 bootstrap.
-- DoD: un joueur rejoint, reçoit un plot, ses données persistent entre
-- deux sessions. Gameplay services stay stubs until their sprint (§12).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Net"))
local DataService = require(script.Services.DataService)
local PlotService = require(script.Services.PlotService)

Net.Server.Start()
DataService.Init()
PlotService.Init()

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

	PlotService.Assign(player, data)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player: Player)
	PlotService.Release(player)
	DataService.Release(player) -- §10.4 — save on leave
end)

game:BindToClose(function()
	DataService.ReleaseAll()
end)

print("[FMF] Sprint 0 server bootstrap ready — Net, DataService, PlotService up.")
