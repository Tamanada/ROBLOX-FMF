--!strict
-- server/Services/UnlockService.luau — Blueprint §14.2 / §14.6.
-- Vérité serveur sur les zones débloquées : évaluation PURE (UnlockRules)
-- des faits persistés (island.completedVenues, island.zoneVisits), jamais
-- d'état dérivé en dur. CompleteVenue est une API MODULE appelée par les
-- futures implémentations de venues côté serveur ; le seul chemin client
-- passe par DebugAdminService (allowlist) — zéro confiance client (§10.3).
-- La liste débloquée est répliquée en attribut joueur, display-only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Island = require(ReplicatedStorage.Shared.Config.Island)
local Unlocks = require(ReplicatedStorage.Shared.Config.Unlocks)
local UnlockRules = require(ReplicatedStorage.Shared.Util.UnlockRules)
local Net = require(ReplicatedStorage.Shared.Util.Net)

local UnlockService = {}

local ATTR_UNLOCKED = "FMF_UnlockedZones"

-- venueId -> true quand la venue compte pour les règles d'unlock.
local completableVenueSet: { [string]: boolean } = {}
for _, venueIds in Island.completableVenuesByZone do
	for _, venueId in venueIds do
		completableVenueSet[venueId] = true
	end
end

--------------------------------------------------------------------------
-- Lecture
--------------------------------------------------------------------------

function UnlockService.IsUnlocked(data: Types.PlayerData, zoneId: string): boolean
	return UnlockRules.isZoneUnlocked(zoneId, Unlocks.rules, data.island, Island.completableVenuesByZone)
end

function UnlockService.GetUnlockedList(data: Types.PlayerData): { string }
	local list: { string } = {}
	for _, zone in Island.list do
		if UnlockService.IsUnlocked(data, zone.id) then
			table.insert(list, zone.id)
		end
	end
	return list
end

--------------------------------------------------------------------------
-- Réplication display-only + notifications de déblocage
--------------------------------------------------------------------------

function UnlockService.Push(player: Player, data: Types.PlayerData)
	player:SetAttribute(ATTR_UNLOCKED, table.concat(UnlockService.GetUnlockedList(data), ","))
end

local function snapshotUnlocked(data: Types.PlayerData): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for _, zoneId in UnlockService.GetUnlockedList(data) do
		set[zoneId] = true
	end
	return set
end

local function notifyNewUnlocks(player: Player, data: Types.PlayerData, before: { [string]: boolean })
	for _, zone in Island.list do
		if not before[zone.id] and UnlockService.IsUnlocked(data, zone.id) then
			Net.Server.Fire("Notify", player, `Nouvelle zone débloquée : {zone.displayName} ! 🌴`)
		end
	end
end

--------------------------------------------------------------------------
-- Mutations (serveur uniquement)
--------------------------------------------------------------------------

-- Marque une venue comme complétée. Appelée par les implémentations de
-- venues (sprints futurs) et par le Dev Panel (allowlist).
-- Retourne false + raison quand l'id est invalide.
function UnlockService.CompleteVenue(player: Player, data: Types.PlayerData, venueId: string): (boolean, string?)
	if Island.venueZone[venueId] == nil then
		return false, "unknown_venue"
	end
	if not completableVenueSet[venueId] then
		return false, "not_completable"
	end
	if data.island.completedVenues[venueId] == true then
		return true, "already_completed"
	end

	local before = snapshotUnlocked(data)
	data.island.completedVenues[venueId] = true
	notifyNewUnlocks(player, data, before)
	UnlockService.Push(player, data)
	return true, nil
end

-- Compte une visite de zone (base de la règle zoneVisited — §14.2).
function UnlockService.RegisterVisit(player: Player, data: Types.PlayerData, zoneId: string)
	if Island.byId[zoneId] == nil then
		return
	end
	local before = snapshotUnlocked(data)
	data.island.zoneVisits[zoneId] = (data.island.zoneVisits[zoneId] or 0) + 1
	notifyNewUnlocks(player, data, before)
	UnlockService.Push(player, data)
end

-- Dev Panel uniquement : remise à zéro de la progression île.
function UnlockService.ResetIsland(player: Player, data: Types.PlayerData)
	data.island.completedVenues = {}
	data.island.zoneVisits = {}
	UnlockService.Push(player, data)
end

--------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------

function UnlockService.Init()
	Net.Server.Declare("Notify")
end

function UnlockService.TrackPlayer(player: Player, data: Types.PlayerData)
	UnlockService.Push(player, data)
end

return UnlockService
