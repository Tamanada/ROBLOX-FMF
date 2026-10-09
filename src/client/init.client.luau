--!strict
-- client/init.client.luau — Sprint 2 bootstrap.
-- Controllers per §10.2: UI (S1), Ambience (S2 — lighting/audio + phase HUD +
-- cleanup banner). Camera, Placement and SFX land with their sprints.

local UIController = require(script.Controllers.UIController)
local AmbienceController = require(script.Controllers.AmbienceController)
local MoonCycleController = require(script.Controllers.MoonCycleController)
local MapController = require(script.Controllers.MapController)
local TransportController = require(script.Controllers.TransportController)
local DevPanelController = require(script.Controllers.DevPanelController)

UIController.Start()
AmbienceController.Start()
MoonCycleController.Start() -- §14.4 phase + countdown
MapController.Start() -- §14.2 carte, zones verrouillées grisées
TransportController.Start() -- §14.3 bandeau de trajet + skip
DevPanelController.Start() -- S7 dev panel (serveur décide)

print("[FMF] client ready — HUD, ambiance, île, transport.")
