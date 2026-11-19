-- test-tooltips-cursor-hover.lua: cursor tooltips leave a gap and never intercept list hover input.
local T = dofile("Tools/regression/tooltips_env.lua")

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env, K, ns = T.New({ width = screen[1], height = screen[2] })
	assert(K.Modules.Enable("Tooltips") and K.Modules.IsRunning("Tooltips"), tostring(env._errors[1]))
	local tip = env.GameTooltip
	local scale = tip:GetEffectiveScale()
	local x, y = screen[1] / 2, screen[2] / 2
	local failures = {}
	for _, mode in ipairs({ "cursorOutOfCombat", "cursor" }) do
		K.Options.Write("Tooltips", "anchor", mode)
		for _, offsets in ipairs({ { 0, 0 }, { -64, -64 }, { 24, 32 } }) do
			-- Old profiles may contain zero or negative offsets; validate them on read too.
			local settings = K.Store.Module("Tooltips")
			settings.cursorX, settings.cursorY = offsets[1], offsets[2]
			for _, surface in ipairs({ "Auction row", "Bag item", "Merchant item", "Quest reward", "Chat link" }) do
				local owner = env.CreateFrame("Button", nil, env.UIParent)
				local enters, leaves = 0, 0
				owner:SetScript("OnEnter", function()
					enters = enters + 1
					env.GameTooltip_SetDefaultAnchor(tip, owner)
					tip:AddLine(surface)
					T.BlizzardShow(tip, true)
				end)
				owner:SetScript("OnLeave", function()
					leaves = leaves + 1
					T.BlizzardShow(tip, false)
				end)
				-- Exercise a tooltip reused after a mouse-enabled owner, as pooled lists reuse GameTooltip.
				tip:EnableMouse(true)
				owner:GetScript("OnEnter")(owner)
				assert(tip:GetOwner() == owner and tip._anchor[1] == "ANCHOR_CURSOR_RIGHT", "cursor tooltips keep their hovered owner")
				local dx, dy = tip._anchor[2] * scale, tip._anchor[3] * scale
				local left, bottom = x + dx, y + dy
				local overlaps = x >= left and x <= left + 320 * scale and y >= bottom and y <= bottom + 240 * scale
				if overlaps then failures.overlap = true end
				if tip:IsMouseEnabled() then failures.mouse = true end
				for _ = 1, 4 do
					if overlaps and tip:IsMouseEnabled() then
						owner:GetScript("OnLeave")(owner)
						owner:GetScript("OnEnter")(owner)
					end
				end
				if enters ~= 1 or leaves ~= 0 then failures.blink = true end
			end
		end
	end
	assert(not failures.overlap, "cursor tooltip overlaps the cursor point: use positive cursor offsets")
	assert(not failures.mouse, "cursor tooltip is mouse-enabled: disable GameTooltip mouse input")
	assert(not failures.blink, "list tooltip repeatedly leaves and re-enters the hovered row")
	-- Forever's auction item display also calls SetOwner directly (SharedTemplates.lua:112-134).
	-- This native button-relative path must stay mouse transparent without moving or clearing its item.
	tip:EnableMouse(true)
	tip:SetOwner(env.UIParent, "ANCHOR_RIGHT")
	tip:AddLine("Auction item")
	T.BlizzardShow(tip, true)
	assert(not tip:IsMouseEnabled(), "auction item tooltips must not steal hover input")
	assert(tip._anchor[1] == "ANCHOR_RIGHT" and tip:GetLeftLine(1):GetText() == "Auction item", "native item anchoring and content stay intact")
	assert(ns.Settings.Get("anchor") == "cursor", "the cursor choice remains enabled")
	env.ItemRefTooltip:EnableMouse(true)
	env.ItemRefTooltip:SetOwner(env.UIParent, "ANCHOR_NONE")
	assert(env.ItemRefTooltip:IsMouseEnabled(), "clickable chat-link windows keep mouse input")
	K.Modules.Disable("Tooltips")
	tip:EnableMouse(true)
	tip:SetOwner(env.UIParent, "ANCHOR_NONE")
	assert(tip:IsMouseEnabled(), "disabled Tooltips leaves mouse input alone")
	assert(#env._errors == 0, tostring(env._errors[1]))
	print("cursor hover stable at " .. screen[1] .. "x" .. screen[2])
end

print("tooltips cursor hover ok")
