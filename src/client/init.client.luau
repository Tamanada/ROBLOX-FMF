--!strict
-- client/init.client.luau — Sprint 1 bootstrap.
-- Controllers per §10.2: UI (S1). Camera, Ambience, Placement and SFX
-- land with their sprints (S2+).

local UIController = require(script.Controllers.UIController)

UIController.Start()

print("[FMF] client ready — HUD online.")
