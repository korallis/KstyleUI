-- _native_menus.lua: one of KstyleUI's three native context menus (tracking, addon compartment, quest) opened over the owner's plate, as the Native fixture draws Blizzard's menu pipeline with the context-menu skin on it; see Tools/render/README.md.
--
--   RENDER_MATERIAL    Native (the skin switched off: Blizzard's own menu), Glass (the skin on, which keeps Blizzard's look), Flat, Slate, ForgedTicks or ForgedBrackets; Native when unset
--   RENDER_TEXT_SIZE   the Skins text size, 0.8 to 1.5; 1 when unset
--   RENDER_TEXT_FACE   a kit face name (CinzelSemiBold, InterSemiBold, AlegreyaSansBold, SourceSans3Semibold); the skin's own when unset
-- The page wraps a text it measures wider than its rect, and the scene does not export SetMaxLines, so a menu label that the glyph table measures a hair narrower than the page does wraps onto the row above. A native label is one line (the compositor's font string is SetMaxLines(1), asserted below), so its items are marked as not wrapping. That models the line cap in the renderer; it is not a runtime fix, and a label that really runs past its rect still ends in "..." and fails the guard.
--
-- Blizzard's Fonts\\FRIZQT__.TTF is not in any local cache, so the Native and Glass states draw the client face as Source Sans 3 Semibold (scene.lua's FONT_STAND_INS) and are wider or narrower than the game's text; the scene logs it.
local Common = dofile("Tools/render/scenes/_common.lua")
local E = dofile("Tools/regression/native_menu_env.lua")

local Native = {}

Native.MATERIALS = { "Native", "Glass", "Flat", "Slate", "ForgedTicks", "ForgedBrackets" }

local ADDONS = { "Details!", "BugSack", "Plater", "WeakAuras", "Questie", "RestedXP" }

function Native.Scene(name)
	local material = os.getenv("RENDER_MATERIAL") or "Native"
	local valid = false
	for _, candidate in ipairs(Native.MATERIALS) do
		valid = valid or candidate == material
	end
	assert(valid, "RENDER_MATERIAL must be one of " .. table.concat(Native.MATERIALS, ", ") .. ", not " .. material)
	local env, K, _, nm = E.New({
		material = material ~= "Native" and material or "Glass",
		skin = material ~= "Native",
		at = { 700, 330 },
		setup = function(env)
			Common.ForceScreen(env)
		end,
	})
	local size, face = tonumber(os.getenv("RENDER_TEXT_SIZE") or ""), os.getenv("RENDER_TEXT_FACE")
	if size then
		K.Options.Write("Skins", "text.size", size)
	end
	if face and face ~= "" then
		K.Options.Write("Skins", "text.font", K.Tokens.FontPath(face))
	end
	env.AddonCompartmentFrame.registeredAddons = {}
	for _, text in ipairs(ADDONS) do
		env.AddonCompartmentFrame.registeredAddons[#env.AddonCompartmentFrame.registeredAddons + 1] = { text = text, func = function() end }
	end
	local menu
	if name == "tracking" then
		menu = E.Tracking(env, nm)
	elseif name == "compartment" then
		menu = E.Compartment(env, nm)
	else
		menu = E.Quest(env, nm)
	end
	assert(menu and menu.open, name .. " menu opens")
	E.W.Enter(menu.rows[2])
	env.RunTimers()
	E.W.Settle(env)
	local scene = Common.Scene.Build(env)
	local oneLine = {}
	for _, row in ipairs(menu.rows) do
		local text = row.fontString
		if text then
			assert(text:GetMaxLines() == 1, "a menu label is a one-line string: Compositor's FontString default is SetMaxLines(1)")
			oneLine[text] = true
		end
	end
	for _, item in ipairs(scene.items) do
		if item.kind == "text" and oneLine[item.object] then
			item.wordWrap = false
		end
	end
	local err = Common.Errors(env, K)
	if err then
		scene.log[#scene.log + 1] = "native menus error: " .. err
	end
	if material == "Native" or material == "Glass" then
		scene.log[#scene.log + 1] = "stand-in face: Blizzard's FRIZQT is not in a local cache, so these labels are Source Sans 3 Semibold"
	end
	scene.log[#scene.log + 1] = "native menu " .. name .. " in " .. material .. " at text size " .. tostring(size or 1) .. ", face " .. tostring(face or "the skin's")
	return scene
end

return Native
