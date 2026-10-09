--!strict
-- server/Services/TransportService.luau — Blueprint §14.3.
-- Songthaew (terre) et longtail (mer) pilotés par des NPC serveur.
-- Chaîne §10.3 complète à l'embarquement : prompt physique dans la zone de
-- départ, zone courante vérifiée, unlock de la destination vérifié, fare
-- débité via EconomyService, siège verrouillé serveur, trajet scripté par
-- waypoints (pas de pathfinding, non-goal S7), skip payant, dépose au spawn
-- destination. Le client ne fait qu'afficher (countdown + bouton skip).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Island = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Island"))
local Routes = require(ReplicatedStorage.Shared.Config.Routes)
local Net = require(ReplicatedStorage.Shared.Util.Net)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local IslandZoneService = require(script.Parent.IslandZoneService)
local UnlockService = require(script.Parent.UnlockService)

local TransportService = {}

local MOVE_STEP_SECONDS = 0.1

type Trip = {
	routeId: string,
	carrier: Model,
	progress: number, -- 0..1
	totalLength: number,
	walkSpeed: number,
	jumpHeight: number,
}

local trips: { [Player]: Trip } = {}
local stations: { [string]: Model } = {}
local started = false

--------------------------------------------------------------------------
-- Véhicules placeholder (primitives §10.6 ; modèles Studio plus tard §10.1)
--------------------------------------------------------------------------

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

local NAVY = Color3.fromRGB(11, 29, 58)
local GOLD = Color3.fromRGB(255, 209, 102)
local WOOD = Color3.fromRGB(122, 82, 48)
local WOOD_DARK = Color3.fromRGB(92, 59, 33)
local CYAN = Color3.fromRGB(0, 229, 255)
local SKIN = Color3.fromRGB(243, 197, 124)

-- Chauffeur NPC bloc (décoratif, aucune interaction).
local function addDriver(model: Model, origin: CFrame)
	makePart(model, "DriverLegs", Vector3.new(0.9, 0.9, 0.5), origin * CFrame.new(0, 0.45, 0), NAVY)
	makePart(model, "DriverTorso", Vector3.new(1.0, 1.0, 0.55), origin * CFrame.new(0, 1.4, 0), CYAN)
	makePart(model, "DriverHead", Vector3.new(0.6, 0.6, 0.6), origin * CFrame.new(0, 2.25, 0), SKIN)
	makePart(
		model,
		"DriverHat",
		Vector3.new(0.9, 0.18, 0.9),
		origin * CFrame.new(0, 2.62, 0),
		WOOD,
		Enum.Material.Fabric
	)
end

local function buildVehicle(vehicleKind: string): Model
	local model = Instance.new("Model")
	model.Name = vehicleKind

	local root = makePart(model, "Root", Vector3.new(1, 1, 1), CFrame.new(), NAVY)
	root.Transparency = 1
	model.PrimaryPart = root

	local seat = Instance.new("Seat")
	seat.Name = "PassengerSeat"
	seat.Anchored = true
	seat.Size = Vector3.new(2, 0.4, 2)
	seat.Color = GOLD
	seat.Material = Enum.Material.Fabric
	seat.Parent = model

	if vehicleKind == "songthaew" then
		makePart(model, "Bed", Vector3.new(7, 0.5, 3.4), CFrame.new(0, 1.4, 0), NAVY)
		makePart(model, "Cab", Vector3.new(2.2, 2.2, 3.2), CFrame.new(3.4, 2.5, 0), GOLD)
		makePart(model, "Roof", Vector3.new(5.2, 0.3, 3.4), CFrame.new(-1, 3.9, 0), WOOD)
		makePart(model, "BenchLeft", Vector3.new(4.6, 0.4, 0.7), CFrame.new(-1, 2.0, 1.2), WOOD_DARK)
		makePart(model, "BenchRight", Vector3.new(4.6, 0.4, 0.7), CFrame.new(-1, 2.0, -1.2), WOOD_DARK)
		for index, offset in
			{
				Vector3.new(2.4, 0.8, 1.7),
				Vector3.new(2.4, 0.8, -1.7),
				Vector3.new(-2.4, 0.8, 1.7),
				Vector3.new(-2.4, 0.8, -1.7),
			}
		do
			local wheel = makePart(
				model,
				`Wheel{index}`,
				Vector3.new(1.6, 1.6, 0.5),
				CFrame.new(offset),
				Color3.fromRGB(25, 28, 34)
			)
			wheel.Shape = Enum.PartType.Cylinder
			-- Axe du cylindre = X ; on l'oriente le long de Z (roue qui roule).
			wheel.CFrame = CFrame.new(offset) * CFrame.Angles(0, math.rad(90), 0)
		end
		seat.CFrame = CFrame.new(-1, 1.9, 0)
		addDriver(model, CFrame.new(3.4, 1.6, -0.8))
	else -- longtail
		makePart(model, "Hull", Vector3.new(6, 0.9, 1.8), CFrame.new(0, 0.8, 0), WOOD, Enum.Material.Wood)
		makePart(
			model,
			"Prow",
			Vector3.new(1.4, 0.8, 1.4),
			CFrame.new(3.3, 1.35, 0) * CFrame.Angles(0, 0, math.rad(30)),
			WOOD,
			Enum.Material.Wood
		)
		makePart(
			model,
			"Stern",
			Vector3.new(1.0, 0.7, 1.3),
			CFrame.new(-3.2, 1.0, 0) * CFrame.Angles(0, 0, math.rad(-16)),
			WOOD_DARK,
			Enum.Material.Wood
		)
		makePart(model, "TrimL", Vector3.new(6.1, 0.12, 0.14), CFrame.new(0, 1.3, 0.88), CYAN, Enum.Material.Neon)
		makePart(
			model,
			"TrimR",
			Vector3.new(6.1, 0.12, 0.14),
			CFrame.new(0, 1.3, -0.88),
			Color3.fromRGB(255, 46, 146),
			Enum.Material.Neon
		)
		makePart(
			model,
			"TailPole",
			Vector3.new(0.15, 2.6, 0.15),
			CFrame.new(-3.9, 1.9, 0) * CFrame.Angles(0, 0, math.rad(-38)),
			WOOD_DARK
		)
		makePart(model, "Lantern", Vector3.new(0.3, 0.3, 0.3), CFrame.new(3.9, 2.2, 0), GOLD, Enum.Material.Neon)
		seat.CFrame = CFrame.new(-0.6, 1.5, 0)
		addDriver(model, CFrame.new(1.6, 1.25, 0))
	end

	return model
end

--------------------------------------------------------------------------
-- Géométrie du trajet
--------------------------------------------------------------------------

local function pathPoints(routeDef: Routes.RouteDef): { Vector3 }
	local points: { Vector3 } = {}
	for _, waypoint in routeDef.path do
		table.insert(points, Vector3.new(waypoint.x, waypoint.y, waypoint.z))
	end
	return points
end

local function pathLength(points: { Vector3 }): number
	local total = 0
	for index = 2, #points do
		total += (points[index] - points[index - 1]).Magnitude
	end
	return total
end

-- Position + direction le long de la polyline à progress 0..1.
local function sampleAlong(points: { Vector3 }, totalLength: number, progress: number): (Vector3, Vector3)
	local target = math.clamp(progress, 0, 1) * totalLength
	local travelled = 0
	for index = 2, #points do
		local segment = points[index] - points[index - 1]
		local segmentLength = segment.Magnitude
		if travelled + segmentLength >= target and segmentLength > 0 then
			local alpha = (target - travelled) / segmentLength
			return points[index - 1] + segment * alpha, segment.Unit
		end
		travelled += segmentLength
	end
	local last = points[#points]
	local direction = (last - points[math.max(#points - 1, 1)])
	return last, if direction.Magnitude > 0 then direction.Unit else Vector3.new(0, 0, -1)
end

--------------------------------------------------------------------------
-- Cycle de vie du trajet (tout serveur)
--------------------------------------------------------------------------

local function restoreCharacter(player: Player, trip: Trip)
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid ~= nil then
		humanoid.Sit = false
		humanoid.WalkSpeed = trip.walkSpeed
		humanoid.JumpHeight = trip.jumpHeight
	end
end

local function finishTrip(player: Player, arrived: boolean)
	local trip = trips[player]
	if trip == nil then
		return
	end
	trips[player] = nil

	restoreCharacter(player, trip)
	trip.carrier:Destroy()

	local routeDef = Routes.byId[trip.routeId]
	if arrived and routeDef ~= nil then
		IslandZoneService.TeleportToZone(player, routeDef.to, true)
	end
	Net.Server.Fire("TransportTripEnded", player, trip.routeId, arrived)
end

local function runTrip(player: Player, routeDef: Routes.RouteDef)
	local points = pathPoints(routeDef)
	local carrier = buildVehicle(routeDef.vehicle)
	local startPosition, startDirection = sampleAlong(points, pathLength(points), 0)
	carrier:PivotTo(CFrame.lookAt(startPosition, startPosition + startDirection))
	carrier.Parent = Workspace

	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if character == nil or humanoid == nil then
		carrier:Destroy()
		return
	end

	local trip: Trip = {
		routeId = routeDef.id,
		carrier = carrier,
		progress = 0,
		totalLength = pathLength(points),
		walkSpeed = humanoid.WalkSpeed,
		jumpHeight = humanoid.JumpHeight,
	}
	trips[player] = trip

	-- Siège verrouillé (§14.3) : le joueur ne peut pas bouger pendant le trajet.
	humanoid.WalkSpeed = 0
	humanoid.JumpHeight = 0
	local seatPart = carrier:FindFirstChild("PassengerSeat")
	if seatPart ~= nil and seatPart:IsA("Seat") then
		character:PivotTo(seatPart.CFrame + Vector3.new(0, 2.5, 0))
		seatPart:Sit(humanoid)
	end

	local skipExtra = routeDef.fare * (routeDef.skipFareMultiplier - 1)
	Net.Server.Fire("TransportTripStarted", player, routeDef.id, routeDef.durationSeconds, skipExtra)

	task.spawn(function()
		while trips[player] == trip do
			task.wait(MOVE_STEP_SECONDS)
			if trips[player] ~= trip then
				return
			end
			trip.progress += MOVE_STEP_SECONDS / routeDef.durationSeconds
			local position, direction = sampleAlong(points, trip.totalLength, trip.progress)
			trip.carrier:PivotTo(CFrame.lookAt(position, position + direction))
			if trip.progress >= 1 then
				finishTrip(player, true)
				return
			end
		end
	end)
end

--------------------------------------------------------------------------
-- Embarquement (chaîne de validation §10.3)
--------------------------------------------------------------------------

local function onBoardRequested(player: Player, routeDef: Routes.RouteDef)
	if trips[player] ~= nil then
		return
	end

	local data = DataService.Get(player)
	if data == nil then
		return
	end

	-- Le joueur doit être dans la zone de départ (le prompt y est physiquement,
	-- la vérification serveur reste la référence).
	if IslandZoneService.GetZone(player) ~= routeDef.from then
		Net.Server.Fire("Notify", player, "Ce transport part d'une autre zone.")
		return
	end

	-- §14.3 — destination verrouillée = refus localisé.
	if not UnlockService.IsUnlocked(data, routeDef.to) then
		local zone = Island.byId[routeDef.to]
		Net.Server.Fire(
			"Notify",
			player,
			`🔒 {zone.displayName} est verrouillée. Complète d'autres venues pour la débloquer.`
		)
		return
	end

	if not EconomyService.Debit(player, routeDef.fare, "transport:" .. routeDef.id) then
		Net.Server.Fire("Notify", player, `Pas assez de Shells — le trajet coûte {routeDef.fare} 🐚.`)
		return
	end

	runTrip(player, routeDef)
end

local function buildStation(routeDef: Routes.RouteDef)
	local points = pathPoints(routeDef)
	local station = buildVehicle(routeDef.vehicle)
	local position, direction = sampleAlong(points, pathLength(points), 0)
	station:PivotTo(CFrame.lookAt(position, position + direction))
	station.Parent = Workspace

	local destination = Island.byId[routeDef.to]
	local vehicleLabel = if routeDef.vehicle == "songthaew" then "Songthaew" else "Longtail"

	local root = station.PrimaryPart
	if root ~= nil then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Embarquer"
		prompt.ObjectText = `{vehicleLabel} vers {destination.displayName} ({routeDef.fare} Shells)`
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = root

		prompt.Triggered:Connect(function(player: Player)
			onBoardRequested(player, routeDef)
		end)
	end

	stations[routeDef.id] = station
end

--------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------

function TransportService.Init()
	if started then
		return
	end
	started = true

	Net.Server.Declare("Notify")
	Net.Server.Declare("TransportTripStarted")
	Net.Server.Declare("TransportTripEnded")

	for _, routeDef in Routes.list do
		if routeDef.vehicle ~= "footpath" then
			buildStation(routeDef)
		end
	end

	-- §14.3 — skip : supplément = fare × (multiplicateur - 1), soit un total
	-- payé de fare × multiplicateur. Serveur uniquement.
	Net.Server.Handle("RequestTransportSkip", {}, function(player: Player)
		local trip = trips[player]
		if trip == nil then
			return
		end
		local routeDef = Routes.byId[trip.routeId]
		if routeDef == nil then
			return
		end

		local extra = routeDef.fare * (routeDef.skipFareMultiplier - 1)
		if extra > 0 and not EconomyService.Debit(player, extra, "transport_skip:" .. routeDef.id) then
			Net.Server.Fire("Notify", player, `Pas assez de Shells — le skip coûte {extra} 🐚.`)
			return
		end
		trip.progress = 1
	end)
end

function TransportService.UntrackPlayer(player: Player)
	finishTrip(player, false)
end

return TransportService
