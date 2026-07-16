--!strict
-- server/Services/MonetizationService.luau — ProcessReceipt idempotent, passes.
-- Blueprint §8, §10.2 — implemented in Sprint 5 (Roadmap §12).
-- Sprint 0: structural stub only. No gameplay logic before S5.
-- §8.4.3 — every Dev Product MUST go through ProcessReceipt with idempotence
-- (purchase id recorded in the profile before granting).

local MonetizationService = {}

function MonetizationService.Init() end

return MonetizationService
