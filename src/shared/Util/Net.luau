--!strict
-- shared/Util/Net.luau — Blueprint §10.3 (règles serveur-autoritaire)
-- RemoteEvent/RemoteFunction wrapper:
--   * every incoming argument list is type-checked against a declared spec
--     before the handler runs (invalid requests are dropped and logged);
--   * one shared rate limiter per player across ALL remotes —
--     more than MAX_REQUESTS_PER_SECOND requests in a rolling 1 s window
--     kicks the player (§10.3.2).
-- The pure helpers Net._validate and Net._createLimiter are unit-tested in
-- tests/Net.spec.luau without touching real remote instances.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTES_FOLDER_NAME = "FMF_Remotes"
local MAX_REQUESTS_PER_SECOND = 10

-- A checker is either a typeof() name ("string", "number", "Vector3",
-- "CFrame", "Instance", ...) — suffix "?" makes it optional — or a custom
-- predicate function returning true for valid values.
export type Checker = string | (value: any) -> boolean
export type Spec = { Checker }
export type PackedArgs = { n: number, [number]: any }
export type Limiter = {
	check: (key: any) -> boolean,
	clear: (key: any) -> (),
}

local Net = {}

--------------------------------------------------------------------------
-- Pure helpers (testable)
--------------------------------------------------------------------------

function Net._validate(spec: Spec, args: PackedArgs): (boolean, string?)
	if args.n > #spec then
		return false, string.format("expected at most %d argument(s), got %d", #spec, args.n)
	end

	for index, checker in spec do
		local value = args[index]

		if type(checker) == "function" then
			local ok, result = pcall(checker, value)
			if not ok or result ~= true then
				return false, string.format("argument #%d failed custom check", index)
			end
		else
			local expected = checker
			local optional = false
			if string.sub(expected, -1) == "?" then
				optional = true
				expected = string.sub(expected, 1, -2)
			end

			if value == nil then
				if not optional then
					return false, string.format("argument #%d is required (expected %s)", index, expected)
				end
			elseif typeof(value) ~= expected then
				return false, string.format("argument #%d: expected %s, got %s", index, expected, typeof(value))
			elseif expected == "number" and (value ~= value or value == math.huge or value == -math.huge) then
				-- NaN/±inf are classic economy-exploit payloads: always reject.
				return false, string.format("argument #%d: number must be finite", index)
			end
		end
	end

	return true, nil
end

function Net._createLimiter(maxPerSecond: number, clock: (() -> number)?): Limiter
	local now: () -> number = clock or os.clock
	local windows: { [any]: { start: number, count: number } } = {}

	local limiter = {} :: Limiter

	function limiter.check(key: any): boolean
		local t = now()
		local window = windows[key]
		if window == nil or t - window.start >= 1 then
			windows[key] = { start = t, count = 1 }
			return true
		end
		window.count += 1
		return window.count <= maxPerSecond
	end

	function limiter.clear(key: any)
		windows[key] = nil
	end

	return limiter
end

--------------------------------------------------------------------------
-- Server API
--------------------------------------------------------------------------

local Server = {}
local serverLimiter = Net._createLimiter(MAX_REQUESTS_PER_SECOND)
local serverStarted = false

local function serverRemotesFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(REMOTES_FOLDER_NAME)
	if existing ~= nil and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = REMOTES_FOLDER_NAME
	folder.Parent = ReplicatedStorage
	return folder
end

local function createRemote(className: "RemoteEvent" | "RemoteFunction", name: string): Instance
	local folder = serverRemotesFolder()
	assert(folder:FindFirstChild(name) == nil, `[Net] remote "{name}" is already registered`)
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = folder
	return remote
end

-- Returns false (and reacts) when the request must be dropped.
local function guard(player: Player, spec: Spec, remoteName: string, args: PackedArgs): boolean
	if not serverLimiter.check(player) then
		-- §10.3.2: max 10 requêtes/s/joueur, kick au-delà.
		player:Kick(`[FMF] Too many requests (more than {MAX_REQUESTS_PER_SECOND}/s).`)
		return false
	end

	local ok, reason = Net._validate(spec, args)
	if not ok then
		warn(`[Net] rejected "{remoteName}" from {player.Name}: {reason}`)
		return false
	end

	return true
end

function Server.Start()
	assert(RunService:IsServer(), "[Net] Net.Server is server-only")
	if serverStarted then
		return
	end
	serverStarted = true

	serverRemotesFolder()
	Players.PlayerRemoving:Connect(function(player: Player)
		serverLimiter.clear(player)
	end)
end

-- Client -> server fire-and-forget intent (e.g. "RequestBuy").
function Server.Handle(name: string, spec: Spec, handler: (player: Player, ...any) -> ())
	assert(RunService:IsServer(), "[Net] Net.Server is server-only")
	local remote = createRemote("RemoteEvent", "RE_" .. name) :: RemoteEvent

	remote.OnServerEvent:Connect(function(player: Player, ...: any)
		local args = table.pack(...)
		if guard(player, spec, name, args) then
			handler(player, table.unpack(args, 1, args.n))
		end
	end)
end

-- Client -> server request/response. Invalid or rate-limited calls return nil.
function Server.Callback(name: string, spec: Spec, handler: (player: Player, ...any) -> ...any)
	assert(RunService:IsServer(), "[Net] Net.Server is server-only")
	local remote = createRemote("RemoteFunction", "RF_" .. name) :: RemoteFunction

	remote.OnServerInvoke = function(player: Player, ...: any)
		local args = table.pack(...)
		if not guard(player, spec, name, args) then
			return nil
		end
		return handler(player, table.unpack(args, 1, args.n))
	end
end

-- Declares a server->client RemoteEvent with no incoming handler (pushes
-- like "Notify"). Idempotent.
function Server.Declare(name: string)
	assert(RunService:IsServer(), "[Net] Net.Server is server-only")
	local folder = serverRemotesFolder()
	if folder:FindFirstChild("RE_" .. name) == nil then
		createRemote("RemoteEvent", "RE_" .. name)
	end
end

function Server.Fire(name: string, player: Player, ...: any)
	local remote = serverRemotesFolder():FindFirstChild("RE_" .. name)
	assert(remote ~= nil and remote:IsA("RemoteEvent"), `[Net] unknown remote "{name}"`)
	remote:FireClient(player, ...)
end

function Server.FireAll(name: string, ...: any)
	local remote = serverRemotesFolder():FindFirstChild("RE_" .. name)
	assert(remote ~= nil and remote:IsA("RemoteEvent"), `[Net] unknown remote "{name}"`)
	remote:FireAllClients(...)
end

--------------------------------------------------------------------------
-- Client API
--------------------------------------------------------------------------

local Client = {}

local function waitForRemote(name: string): Instance
	local folder = ReplicatedStorage:WaitForChild(REMOTES_FOLDER_NAME)
	return folder:WaitForChild(name)
end

function Client.Fire(name: string, ...: any)
	assert(RunService:IsClient(), "[Net] Net.Client is client-only")
	local remote = waitForRemote("RE_" .. name) :: RemoteEvent
	remote:FireServer(...)
end

function Client.Invoke(name: string, ...: any): ...any
	assert(RunService:IsClient(), "[Net] Net.Client is client-only")
	local remote = waitForRemote("RF_" .. name) :: RemoteFunction
	return remote:InvokeServer(...)
end

function Client.On(name: string, handler: (...any) -> ()): RBXScriptConnection
	assert(RunService:IsClient(), "[Net] Net.Client is client-only")
	local remote = waitForRemote("RE_" .. name) :: RemoteEvent
	return remote.OnClientEvent:Connect(handler)
end

Net.Server = Server
Net.Client = Client
Net.MAX_REQUESTS_PER_SECOND = MAX_REQUESTS_PER_SECOND

return Net
