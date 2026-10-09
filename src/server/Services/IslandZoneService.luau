--!strict
-- server/Services/IslandZoneService.luau — Blueprint §14.1 / §14.2.
-- Construit les 5 zones placeholder de l'île (sol, panneau, slots de venues
-- et d'activités), tient la zone courante de chaque joueur, applique
-- l'enforcement d'unlock sur TOUT téléport (§10.3) et câble les sentiers
-- pédestres (routes "footpath"). Les venues restent des pads vides : le
-- contenu arrive dans des sprints ultérieurs (non-goal S7).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Island = require(ReplicatedStorage.Shared.Config.Island)
local Routes = require(ReplicatedStorage.Shared.Config.Routes)
local Net = require(ReplicatedStorage.Shared.Util.Net)

local DataService = require(script.Parent.DataService)
local UnlockService = require(script.Parent.UnlockService)

local IslandZoneService = {}

local ATTR_CURRENT_ZONE = "FMF_CurrentZone"

local initialized = false
local spawnByZone: { [string]: CFrame } = {}
local currentZone: { [Player]: string } = {}

--------------------------------------------------------------------------
-- Construction placeholder (le placement final est un travail Studio §10.1)
--------------------------------------------------------------------------

local function makeLabel(parent: BasePart, text: string, color: Color3, height: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(240, 44)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 220

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = billboard

	billboard.Parent = parent
end

local function makePad(
	parent: Instance,
	position: Vector3,
	size: Vector3,
	color: Color3,
	labelText: string,
	labelColor: Color3
): BasePart
	local pad = Instance.new("Part")
	pad.Anchored = true -- §10.6
	pad.Size = size
	pad.Position = position
	pad.Color = color
	pad.Material = Enum.Material.SmoothPlastic
	pad.Parent = parent
	makeLabel(pad, labelText, labelColor, 4)
	return pad
end

local function buildZone(def: Island.ZoneDef, parent: Folder)
	local anchor = Vector3.new(def.spawn.x, 0, def.spawn.z)

	local zoneFolder = Instance.new("Folder")
	zoneFolder.Name = def.id
	zoneFolder.Parent = parent

	local ground = Instance.new("Part")
	ground.Name = "Ground"
	ground.Anchored = true
	ground.Shape = Enum.PartType.Cylinder
	-- Cylinder axis is X; rotate so it lies flat.
	ground.Size = Vector3.new(0.6, def.groundRadius * 2, def.groundRadius * 2)
	ground.CFrame = CFrame.new(anchor) * CFrame.Angles(0, 0, math.rad(90))
	ground.Color = Color3.fromHex(def.groundColor)
	ground.Material = if def.id == "baan_tai" then Enum.Material.Grass else Enum.Material.Sand
	ground.Parent = zoneFolder

	-- Panneau de zone.
	local signPost = makePad(
		zoneFolder,
		anchor + Vector3.new(0, 2.5, -8),
		Vector3.new(0.4, 5, 0.4),
		Color3.fromRGB(122, 82, 48),
		def.displayName,
		Color3.fromRGB(255, 209, 102)
	)
	signPost.Name = "ZoneSign"

	-- Slots de venues (pads vides, §14.5 : noms neutres).
	for index, slot in def.venues do
		local angle = math.rad((index - 1) * (360 / math.max(#def.venues, 1)))
		local radius = def.groundRadius * 0.55
		local pad = makePad(
			zoneFolder,
			anchor + Vector3.new(math.cos(angle) * radius, 0.8, math.sin(angle) * radius),
			Vector3.new(10, 1.2, 10),
			Color3.fromRGB(11, 29, 58),
			`{slot.displayName}\n(bientôt)`,
			Color3.fromRGB(0, 229, 255)
		)
		pad.Name = slot.id
		pad:SetAttribute("VenueId", slot.id)
		pad:SetAttribute("Completable", slot.completable)
	end

	-- Slots d'activités (stubs, non-goal S7).
	for index, slot in def.activities do
		local pad = makePad(
			zoneFolder,
			anchor + Vector3.new(-def.groundRadius * 0.75 + (index - 1) * 8, 0.6, def.groundRadius * 0.75),
			Vector3.new(6, 0.8, 6),
			Color3.fromRGB(180, 255, 57),
			slot.displayName,
			Color3.fromRGB(11, 29, 58)
		)
		pad.Name = slot.id
		pad:SetAttribute("ActivityId", slot.id)
	end

	local yaw = math.rad(def.spawn.yawDeg)
	spawnByZone[def.id] = CFrame.new(def.spawn.x, def.spawn.y, def.spawn.z) * CFrame.Angles(0, yaw, 0)
end

-- Sentiers pédestres (§14.2 : Haad Yuan <-> Haad Thien, gratuit).
local function buildFootpaths(parent: Folder)
	for _, routeDef in Routes.list do
		if routeDef.vehicle ~= "footpath" then
			continue
		end
		local start = routeDef.path[1]
		local destination = Island.byId[routeDef.to]

		local pad = Instance.new("Part")
		pad.Name = routeDef.id
		pad.Anchored = true
		pad.Size = Vector3.new(5, 0.6, 5)
		pad.Position = Vector3.new(start.x, start.y, start.z)
		pad.Color = Color3.fromRGB(139, 110, 72)
		pad.Material = Enum.Material.WoodPlanks
		pad.Parent = parent
		makeLabel(pad, `Sentier vers {destination.displayName}`, Color3.fromRGB(232, 220, 192), 3)

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Marcher"
		prompt.ObjectText = `Sentier vers {destination.displayName}`
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 8
		prompt.Parent = pad

		prompt.Triggered:Connect(function(player: Player)
			IslandZoneService.TeleportToZone(player, routeDef.to, false)
		end)
	end
end

--------------------------------------------------------------------------
-- API
--------------------------------------------------------------------------

function IslandZoneService.Init()
	if initialized then
		return
	end
	initialized = true

	local folder = Instance.new("Folder")
	folder.Name = "Island"
	folder.Parent = Workspace

	for _, def in Island.list do
		buildZone(def, folder)
	end
	buildFootpaths(folder)
end

function IslandZoneService.GetSpawnCFrame(zoneId: string): CFrame?
	return spawnByZone[zoneId]
end

function IslandZoneService.GetZone(player: Player): string?
	return currentZone[player]
end

-- Arrivée effective dans une zone : zone courante + compteur de visites
-- (base de la règle zoneVisited §14.2).
function IslandZoneService.RegisterArrival(player: Player, data: Types.PlayerData, zoneId: string)
	currentZone[player] = zoneId
	player:SetAttribute(ATTR_CURRENT_ZONE, zoneId)
	UnlockService.RegisterVisit(player, data, zoneId)
end

-- Téléporte vers le spawn d'une zone. `force` saute le check d'unlock
-- (réservé aux arrivées de transport déjà validées à l'embarquement).
-- §14.3 — destination verrouillée = refus localisé.
function IslandZoneService.TeleportToZone(player: Player, zoneId: string, force: boolean): boolean
	local data = DataService.Get(player)
	local spawn: CFrame? = spawnByZone[zoneId]
	if data == nil or spawn == nil then
		return false
	end

	if not force and not UnlockService.IsUnlocked(data, zoneId) then
		local zone = Island.byId[zoneId]
		Net.Server.Fire(
			"Notify",
			player,
			`🔒 {zone.displayName} est verrouillée. Complète d'autres venues pour la débloquer.`
		)
		return false
	end

	local character = player.Character
	if character == nil then
		return false
	end

	character:PivotTo(spawn + Vector3.new(0, 2, 0))
	IslandZoneService.RegisterArrival(player, data, zoneId)
	return true
end

function IslandZoneService.TrackPlayer(player: Player, data: Types.PlayerData)
	-- Spawn au hub (§14.2) — les joueurs apparaissent sur leur plot, qui vit
	-- dans la zone Haad Rin ; la visite du hub compte dès le join.
	IslandZoneService.RegisterArrival(player, data, Island.HUB_ZONE)
end

function IslandZoneService.UntrackPlayer(player: Player)
	currentZone[player] = nil
end

return IslandZoneService
