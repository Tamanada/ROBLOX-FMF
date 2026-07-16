--!strict
-- shared/Util/Serde.luau — DataStore-safe serialization helpers.
-- CFrames cannot be stored in DataStores (§10.4): equipment placement is
-- persisted as the 12 CFrame components, relative to the plot origin.

local Serde = {}

function Serde.serializeCFrame(cframe: CFrame): { number }
	return { cframe:GetComponents() }
end

function Serde.deserializeCFrame(components: { number }): CFrame
	assert(#components == 12, `[Serde] expected 12 CFrame components, got {#components}`)
	return CFrame.new(
		components[1],
		components[2],
		components[3],
		components[4],
		components[5],
		components[6],
		components[7],
		components[8],
		components[9],
		components[10],
		components[11],
		components[12]
	)
end

return Serde
