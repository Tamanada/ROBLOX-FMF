--!strict
-- shared/Config/Monetization.luau — Blueprint §8 (monétisation).
-- Single source of truth for Game Passes and Developer Products.
-- §8.4 (binding): no gameplay-critical content is Robux-exclusive, no direct
-- paid loot boxes, and every Dev Product flows through ProcessReceipt with
-- idempotence (§8.4.3 / §10.5).
--
-- gamePassId / productId are the Roblox asset ids — created in Studio and
-- pasted here (AssetRegistry discipline, §10.1). They are 0 placeholders until
-- then; MonetizationService keys purchases by these ids, so nothing grants
-- until the real ids are filled in. Shell-pack amounts are a Sprint 5 amendment
-- (2026-07-17): §8.2 sets "~15-20 min of farming", tuned here per tier.

export type PassDef = {
	id: string,
	displayName: string,
	gamePassId: number,
	robux: number,
	effect: string,
}

export type ProductDef = {
	id: string,
	displayName: string,
	productId: number,
	robux: number,
	effect: string, -- "shells" | "hypeBoost" | "repairAll"
	amount: number, -- shells granted (shells packs) or 0
}

-- §8.1 — Game Passes (one-time).
local passes: { PassDef } = {
	table.freeze({
		id = "auto_collect",
		displayName = "Auto-Collect",
		gamePassId = 0,
		robux = 249,
		effect = "autoCollect",
	}),
	table.freeze({ id = "vip_islander", displayName = "VIP Islander", gamePassId = 0, robux = 399, effect = "vip" }),
	table.freeze({ id = "pyro_master", displayName = "Pyro Master", gamePassId = 0, robux = 299, effect = "pyro" }),
	table.freeze({
		id = "golden_boat",
		displayName = "Golden Longtail Boat",
		gamePassId = 0,
		robux = 199,
		effect = "goldenBoat",
	}),
	-- Extra Plot Slot (§8.1): the 2nd save slot is a follow-up (multi-plot
	-- persistence); the pass is registered but its effect is deferred.
	table.freeze({
		id = "extra_plot",
		displayName = "Extra Plot Slot",
		gamePassId = 0,
		robux = 349,
		effect = "extraPlot",
	}),
}

-- §8.2 — Developer Products (repeatable). Shell amounts tuned per tier.
local products: { ProductDef } = {
	table.freeze({
		id = "shells_small",
		displayName = "Handful of Shells",
		productId = 0,
		robux = 99,
		effect = "shells",
		amount = 5000,
	}),
	table.freeze({
		id = "shells_medium",
		displayName = "Bag of Shells",
		productId = 0,
		robux = 249,
		effect = "shells",
		amount = 15000,
	}),
	table.freeze({
		id = "shells_large",
		displayName = "Chest of Shells",
		productId = 0,
		robux = 599,
		effect = "shells",
		amount = 42000,
	}),
	table.freeze({
		id = "shells_huge",
		displayName = "Hoard of Shells",
		productId = 0,
		robux = 1299,
		effect = "shells",
		amount = 100000,
	}),
	table.freeze({
		id = "hype_boost",
		displayName = "Hype Boost (+20, 30m)",
		productId = 0,
		robux = 49,
		effect = "hypeBoost",
		amount = 0,
	}),
	table.freeze({
		id = "repair_all",
		displayName = "Instant Repair All",
		productId = 0,
		robux = 25,
		effect = "repairAll",
		amount = 0,
	}),
}

local passById: { [string]: PassDef } = {}
local passByGamePassId: { [number]: PassDef } = {}
for _, pass in passes do
	passById[pass.id] = pass
	if pass.gamePassId ~= 0 then
		passByGamePassId[pass.gamePassId] = pass
	end
end

local productById: { [string]: ProductDef } = {}
local productByProductId: { [number]: ProductDef } = {}
for _, product in products do
	productById[product.id] = product
	if product.productId ~= 0 then
		productByProductId[product.productId] = product
	end
end

-- §8.2 — Hype Boost magnitude/duration (§8.2 "+20 pendant 30 min").
return table.freeze({
	passes = table.freeze(passes),
	passById = table.freeze(passById),
	passByGamePassId = table.freeze(passByGamePassId),
	products = table.freeze(products),
	productById = table.freeze(productById),
	productByProductId = table.freeze(productByProductId),
	HYPE_BOOST_AMOUNT = 20,
	HYPE_BOOST_DURATION_SECONDS = 30 * 60,
	VIP_SHELLS_MULTIPLIER = 1.25, -- §8.1 VIP Islander +25 %
	GOLDEN_BOAT_ARRIVAL_MULTIPLIER = 1.1, -- §8.1 +10 % NPC arrivals
})
