--!strict
-- shared/Util/Signal.luau — minimal dependency-free signal.
-- Closure-based (dot-call API) to stay clean under strict mode.

export type Connection = {
	Disconnect: () -> (),
}

export type Signal = {
	Connect: (handler: (...any) -> ()) -> Connection,
	Once: (handler: (...any) -> ()) -> Connection,
	Fire: (...any) -> (),
	DisconnectAll: () -> (),
}

local SignalModule = {}

function SignalModule.new(): Signal
	local handlers: { (...any) -> () } = {}

	local signal = {} :: Signal

	function signal.Connect(handler: (...any) -> ()): Connection
		table.insert(handlers, handler)

		local connection = {} :: Connection
		function connection.Disconnect()
			local index = table.find(handlers, handler)
			if index ~= nil then
				table.remove(handlers, index)
			end
		end
		return connection
	end

	function signal.Once(handler: (...any) -> ()): Connection
		local connection: Connection? = nil
		connection = signal.Connect(function(...)
			if connection ~= nil then
				connection.Disconnect()
				connection = nil
			end
			handler(...)
		end)
		return connection :: Connection
	end

	function signal.Fire(...: any)
		-- Clone so handlers disconnecting mid-fire don't skip entries.
		for _, handler in table.clone(handlers) do
			task.spawn(handler, ...)
		end
	end

	function signal.DisconnectAll()
		table.clear(handlers)
	end

	return signal
end

return SignalModule
