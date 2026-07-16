--!strict
-- server/Services/SocialService.luau — Blueprint §6 (social & multijoueur).
-- Server-authoritative (§10.3):
--   * RequestVisit(plotIndex): teleport to another player's plot; the first
--     visit to a distinct host today counts toward the daily "Visit 3" quest.
--   * RequestReturnHome(): teleport back to your own plot.
--   * RequestRate(hostUserId, stars): 1-5 stars, 1 vote/host/day, aggregated on
--     the host's profile and replicated to their plot for the hub board.
--   * Friend bonus: +5 % revenue while a friend is on the server.
-- Effects are pushed to BuildService/EconomyService (SocialService is a leaf).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Net = require(ReplicatedStorage.Shared.Util.Net)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local BuildService = require(script.Parent.BuildService)
local PlotService = require(script.Parent.PlotService)

local SocialService = {}

local started = false

--------------------------------------------------------------------------
-- Pure helpers (unit-tested in tests/Social.spec.luau)
--------------------------------------------------------------------------

function SocialService._todayIndex(unixTime: number): number
	return math.floor(unixTime / Economy.SECONDS_PER_DAY)
end

function SocialService._averageRating(rating: Types.FestivalRating): number
	if rating.count <= 0 then
		return 0
	end
	return rating.sum / rating.count
end

function SocialService._visitedCount(social: Types.SocialState): number
	local count = 0
	for _ in social.visitedHosts do
		count += 1
	end
	return count
end

function SocialService._canRate(social: Types.SocialState, hostKey: string): boolean
	return social.ratedHosts[hostKey] ~= true
end

--------------------------------------------------------------------------
-- Internals
--------------------------------------------------------------------------

local function isIndexNumber(value: any): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value >= 1
		and value == math.floor(value)
end

local function isStarNumber(value: any): boolean
	return type(value) == "number"
		and value == value
		and value >= Economy.RATING_MIN
		and value <= Economy.RATING_MAX
		and value == math.floor(value)
end

local function notify(player: Player, message: string)
	Net.Server.Fire("Notify", player, message)
end

-- Resets the per-day social bucket when the UTC day changes (§6).
local function ensureDay(data: Types.PlayerData)
	local today = SocialService._todayIndex(os.time())
	if data.social.day ~= today then
		data.social.day = today
		data.social.visitedHosts = {}
		data.social.ratedHosts = {}
		data.social.questClaimed = false
	end
end

local function updateRatingAttribute(player: Player, data: Types.PlayerData)
	PlotService.SetPlotAttribute(player, "Rating", SocialService._averageRating(data.festivalRating))
	PlotService.SetPlotAttribute(player, "RatingCount", data.festivalRating.count)
end

-- §6 — +5 % revenue while a friend is on the server (yields on IsFriendsWith).
local function recomputeFriendBonus(player: Player)
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	local hasFriend = false
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local ok, isFriend = pcall(function()
				return player:IsFriendsWith(other.UserId)
			end)
			if ok and isFriend then
				hasFriend = true
				break
			end
		end
	end
	local multiplier = if hasFriend then Economy.FRIEND_BONUS_MULTIPLIER else 1
	BuildService.SetExternalMultiplier(player, data, "friend", multiplier)
end

local function recomputeAllFriendBonuses()
	for _, player in Players:GetPlayers() do
		task.spawn(recomputeFriendBonus, player)
	end
end

--------------------------------------------------------------------------
-- Intent handlers (§10.3.1)
--------------------------------------------------------------------------

local function onRequestVisit(player: Player, plotIndex: number)
	local ownerUserId = PlotService.GetOwnerUserId(plotIndex)
	if ownerUserId == nil then
		notify(player, "No festival on that plot yet.")
		return
	end
	if ownerUserId == player.UserId then
		notify(player, "That's your own festival!")
		return
	end
	local spawnCFrame = PlotService.GetSpawnCFrame(plotIndex)
	local character = player.Character
	if spawnCFrame == nil or character == nil then
		return
	end
	character:PivotTo(spawnCFrame)

	local data = DataService.Get(player)
	if data == nil then
		return
	end
	ensureDay(data)

	local hostKey = tostring(ownerUserId)
	if not data.social.visitedHosts[hostKey] then
		data.social.visitedHosts[hostKey] = true
		data.stats.visits += 1
		-- §6 — daily "Visit 3 festivals" quest.
		if not data.social.questClaimed and SocialService._visitedCount(data.social) >= Economy.VISIT_QUEST_TARGET then
			data.social.questClaimed = true
			EconomyService.Credit(player, Economy.VISIT_QUEST_REWARD_SHELLS, "quest")
			notify(player, `Daily quest done — Visit 3 festivals! +{Economy.VISIT_QUEST_REWARD_SHELLS} 🐚`)
		end
	end
	notify(player, "Welcome to a fellow islander's festival! 🌴")
end

local function onRequestReturnHome(player: Player)
	local plotIndex = PlotService.GetPlotIndex(player)
	if plotIndex == nil then
		return
	end
	local spawnCFrame = PlotService.GetSpawnCFrame(plotIndex)
	local character = player.Character
	if spawnCFrame ~= nil and character ~= nil then
		character:PivotTo(spawnCFrame)
	end
end

local function onRequestRate(player: Player, hostUserId: number, stars: number)
	if stars < Economy.RATING_MIN or stars > Economy.RATING_MAX then
		return
	end
	if hostUserId == player.UserId then
		notify(player, "You can't rate your own festival.")
		return
	end
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	ensureDay(data)

	local hostKey = tostring(hostUserId)
	if not SocialService._canRate(data.social, hostKey) then
		notify(player, "You already rated this festival today.")
		return
	end
	local host = Players:GetPlayerByUserId(hostUserId)
	local hostData = if host ~= nil then DataService.Get(host) else nil
	if host == nil or hostData == nil then
		notify(player, "That host isn't around right now.")
		return
	end

	hostData.festivalRating.sum += stars
	hostData.festivalRating.count += 1
	data.social.ratedHosts[hostKey] = true
	updateRatingAttribute(host, hostData)
	notify(player, `You rated this festival {stars}★!`)
end

--------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------

function SocialService.Init()
	if started then
		return
	end
	started = true

	Net.Server.Handle("RequestVisit", { isIndexNumber }, onRequestVisit)
	Net.Server.Handle("RequestReturnHome", {}, onRequestReturnHome)
	Net.Server.Handle("RequestRate", { isIndexNumber, isStarNumber }, onRequestRate)
end

function SocialService.TrackPlayer(player: Player, data: Types.PlayerData)
	updateRatingAttribute(player, data)
	-- A joining player may be a friend of someone already here (and vice-versa).
	recomputeAllFriendBonuses()
end

function SocialService.UntrackPlayer(_player: Player)
	-- Someone's on-server friend may have just left → re-evaluate the rest.
	recomputeAllFriendBonuses()
end

return SocialService
