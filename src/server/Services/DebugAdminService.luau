--!strict
-- server/Services/DebugAdminService.luau — Dev Panel S7.
-- SEUL chemin client vers CompleteVenue / ResetIsland, verrouillé par une
-- allowlist de UserIds + autorisation automatique en Studio. Toute action
-- admin est loggée. Zéro confiance client (§10.3) : hors allowlist, les
-- requêtes sont ignorées et loggées.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Net"))

local DataService = require(script.Parent.DataService)
local UnlockService = require(script.Parent.UnlockService)

local DebugAdminService = {}

-- TODO(David) : ajoute ton UserId Roblox ici, par exemple [123456789] = true.
-- Tant que la liste est vide, le Dev Panel n'est utilisable qu'en Studio.
local ALLOWLIST: { [number]: boolean } = {}

local started = false

local function isAdmin(player: Player): boolean
	return ALLOWLIST[player.UserId] == true or RunService:IsStudio()
end

function DebugAdminService.Init()
	if started then
		return
	end
	started = true

	Net.Server.Declare("Notify")

	Net.Server.Callback("DevIsAdmin", {}, function(player: Player)
		return isAdmin(player)
	end)

	Net.Server.Handle("DevCompleteVenue", { "string" }, function(player: Player, venueId: string)
		if not isAdmin(player) then
			warn(`[FMF][DEV] refused DevCompleteVenue from non-admin {player.Name} ({player.UserId})`)
			return
		end
		local data = DataService.Get(player)
		if data == nil then
			return
		end

		local ok, reason = UnlockService.CompleteVenue(player, data, venueId)
		warn(`[FMF][DEV] {player.Name} ({player.UserId}) CompleteVenue "{venueId}" -> {tostring(ok)} {reason or ""}`)
		if ok then
			Net.Server.Fire("Notify", player, `DEV : venue "{venueId}" validée.`)
		else
			Net.Server.Fire("Notify", player, `DEV : venue "{venueId}" refusée ({reason}).`)
		end
	end)

	Net.Server.Handle("DevResetIsland", {}, function(player: Player)
		if not isAdmin(player) then
			warn(`[FMF][DEV] refused DevResetIsland from non-admin {player.Name} ({player.UserId})`)
			return
		end
		local data = DataService.Get(player)
		if data == nil then
			return
		end

		UnlockService.ResetIsland(player, data)
		warn(`[FMF][DEV] {player.Name} ({player.UserId}) reset island progress`)
		Net.Server.Fire("Notify", player, "DEV : progression de l'île réinitialisée.")
	end)
end

return DebugAdminService
