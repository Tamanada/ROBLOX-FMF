--!strict
-- client/init.client.luau — Sprint 2 bootstrap.
-- Controllers per §10.2: UI (S1), Ambience (S2 — lighting/audio + phase HUD +
-- cleanup banner). Camera, Placement and SFX land with their sprints.

local UIController = require(script.Controllers.UIController)
local AmbienceController = require(script.Controllers.AmbienceController)

UIController.Start()
AmbienceController.Start()

print("[FMF] client ready — HUD + ambiance online.")
