--!nonstrict
-- tests/Mocks/MockProfileStore.luau — in-memory stand-in for ProfileStore.
-- Mirrors the subset of the API DataService relies on: New, StartSessionAsync
-- (with session-locking), AddUserId, Reconcile, IsActive, Save, EndSession,
-- OnSessionEnd. Data "persists" in store._saved between sessions, which lets
-- specs exercise the save/reload cycle without DataStores.

local MockProfileStore = {}

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[key] = deepCopy(child)
	end
	return copy
end

local function reconcile(target, template)
	for key, value in template do
		if target[key] == nil then
			target[key] = deepCopy(value)
		elseif type(target[key]) == "table" and type(value) == "table" then
			reconcile(target[key], value)
		end
	end
end

local function createSignal()
	local handlers = {}
	local signal = {}

	function signal:Connect(handler)
		table.insert(handlers, handler)
		return {
			Disconnect = function()
				local index = table.find(handlers, handler)
				if index ~= nil then
					table.remove(handlers, index)
				end
			end,
		}
	end

	function signal:_fire(...)
		for _, handler in table.clone(handlers) do
			task.spawn(handler, ...)
		end
	end

	return signal
end

function MockProfileStore.New(_storeName, template)
	local store = {
		_saved = {}, -- key -> last saved snapshot
		_locked = {}, -- key -> true while a session holds the lock
	}

	-- Test helper: pretend an (old) save already exists for this key.
	function store:_seed(key, data)
		self._saved[key] = deepCopy(data)
	end

	function store:StartSessionAsync(key, _params)
		if self._locked[key] then
			-- Another session holds the lock (real ProfileStore would
			-- negotiate/steal; returning nil is the "not_released" outcome).
			return nil
		end
		self._locked[key] = true

		local data = if self._saved[key] ~= nil then deepCopy(self._saved[key]) else deepCopy(template)

		local profile = {
			Data = data,
			Key = key,
			OnSessionEnd = createSignal(),
			_active = true,
		}

		function profile:AddUserId(_userId) end

		function profile:Reconcile()
			reconcile(self.Data, template)
		end

		function profile:IsActive()
			return self._active
		end

		function profile:Save()
			store._saved[key] = deepCopy(self.Data)
		end

		function profile:EndSession()
			if not self._active then
				return
			end
			self._active = false
			store._saved[key] = deepCopy(self.Data)
			store._locked[key] = nil
			self.OnSessionEnd:_fire()
		end

		return profile
	end

	MockProfileStore._lastStore = store
	return store
end

return MockProfileStore
