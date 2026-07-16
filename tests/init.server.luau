--!strict
-- tests/init.server.luau — TestEZ runner.
-- To run: in Studio, set the Workspace attribute `FMF_RunTests` to true,
-- then Play (F5) or Run (F8). Requires `wally install` (TestEZ package).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

if workspace:GetAttribute("FMF_RunTests") ~= true then
	return
end

local packages = ReplicatedStorage:FindFirstChild("Packages")
local testEZModule = if packages ~= nil then packages:FindFirstChild("TestEZ") else nil
if testEZModule == nil or not testEZModule:IsA("ModuleScript") then
	warn("[FMF] TestEZ is not installed — run `wally install`, then `rojo serve` again.")
	return
end

local TestEZ = require(testEZModule) :: any

print("[FMF] running TestEZ specs...")
TestEZ.TestBootstrap:run({ script })
