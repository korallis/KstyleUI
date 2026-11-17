-- test-unitframes-medallions-target-row.lua: creature captions, visible name fitting, secret reuse and marker clearance across game-fitted screens.
local U = dofile("Tools/regression/unitframes_env.lua")
local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local failures = {}
local function check(ok, why)
	if not ok then failures[#failures + 1] = why end
end

for _, screen in ipairs({ { 5120, 1440 }, { 3456, 2234 }, { 1920, 1080 } }) do
	_G.RENDER_SCREEN = { width = screen[1], height = screen[2], size = "auto" }
	_G.RENDER_HUD_STYLE = "Medallions"
	local env, K, ns = U.New(Common.ScreenOpts({
		saved = Hud.Saved(Hud.Options({ layout = "DPS" }), "UnitFrames", {}),
		setup = function(e) Common.ForceScreen(e, true) end,
	}))
	env.RunTimers()
	local view = ns.Frames.Get("target").views[1]
	local path = ns.Settings.Font("target", "name")
	local tag = screen[1] .. "x" .. screen[2]
	local floorPixels = math.ceil(9 * screen[2] / 1080 - 1e-6)
	local function pixels(text)
		local _, size = text:GetFont()
		return size * text:GetEffectiveScale() * screen[2] / 768
	end
	local function ink(text)
		if not text:IsShown() then return nil end
		local x, y, w, h = Common.Scene.Rect(env, text)
		local font, size = text:GetFont()
		local advance = env._textWidth(U.Shown(env, text), font, size) * text:GetEffectiveScale() * 1080 / 768
		local visible = w > 0 and math.min(w, advance) or advance
		if text:GetJustifyH() == "RIGHT" then x = x + w - visible end
		return { x, y, visible, h, advance, w }
	end
	local function clearRow(label, captionMayTruncate)
		local name, caption = ink(view.name), ink(view.caption)
		local level = ink(view.slabLevel)
		check(captionMayTruncate or caption[5] <= caption[6] + 0.01, tag .. " " .. label .. ": show the complete drawn creature caption")
		check(not name or caption[1] + caption[3] <= name[1] + 0.01, tag .. " " .. label .. ": drawn name must clear the creature caption")
		check(not level or caption[1] + caption[3] <= level[1] + 0.01, tag .. " " .. label .. ": drawn level must clear the creature caption")
	end
	local function target(name, creature, secretName, secretCreature)
		U.SetUnit(env, "target", { name = name, creature = creature, secretName = secretName, secretCreature = secretCreature, level = 39, health = 90, healthMax = 100, marker = 8, reaction = 2 })
		env.SetTarget(true)
	end
	for _, creature in ipairs(env._creatureTypes) do
		for _, name in ipairs({ "Ash", "Riverglade Crocolisk", string.rep("Everlasting ", 12) }) do
			target(name, creature)
			clearRow(name .. "/" .. creature)
			check(pixels(view.name) >= floorPixels - 1e-6, tag .. ": even a truncated fallback must keep the 9-unit reading floor")
		end
	end
	for _, scale in ipairs({ 0.8, 1, 1.2, 1.3 }) do
		assert(K.Theme.SetFontScale(scale))
		env.RunTimers()
		target("Ash", "Beast")
		local fullPixels = pixels(view.name)
		for _, creature in ipairs({ "Beast", "Mechanical", "Non-combat Pet" }) do
			target("Riverglade Crocolisk", creature)
			clearRow("Text size " .. scale .. "/" .. creature)
			if creature == "Beast" then
				check(view.name:GetFont() == path, tag .. ": Text size " .. scale .. " must shrink a fitting long name in caps before fallback")
			end
			check(pixels(view.name) <= fullPixels + 0.01, tag .. ": fitting must never enlarge a scaled caps name")
			check(pixels(view.name) >= floorPixels - 1e-6, tag .. ": Text size " .. scale .. " keeps the reading floor")
			if scale == 1.3 and view.name:GetFont() == K.Tokens.Font("body") then
				check(pixels(view.name) <= floorPixels + 0.01, tag .. ": fallback must not grow beyond the last caps size at the reading floor")
			end
		end
	end
	assert(K.Theme.SetFontScale(1))
	env.RunTimers()
	for _, text in ipairs({ view.name, view.caption }) do
		local getText, measure = text.GetText, text.GetUnboundedStringWidth
		text.GetText = function(self)
			local value = getText(self)
			if self:HasAnySecretAspect() and not env.issecretvalue(value) then return env.Secret(value) end
			return value
		end
		text.GetUnboundedStringWidth = function(self)
			assert(not env.issecretvalue(self:GetText()), "never measure secret unit text")
			local width = measure(self)
			if self:IsAnchoringSecret() then return env.Secret(width) end
			return width
		end
	end
	for _, name in ipairs({ "Hogger", "Blackfang" }) do
		target(name, "Non-combat Pet", true, true)
		clearRow("secret short name/type")
		local shortName = ink(view.name)
		check(shortName and math.abs(shortName[3] - shortName[5]) <= 0.01, tag .. ": secret " .. name .. "'s drawn width must equal its full text width")
	end
	target("Riverglade Crocolisk", "Non-combat Pet", false, true)
	clearRow("secret type/plain long name")
	env._creatureTypes[#env._creatureTypes + 1] = "Unusually Long Creature"
	target("Hogger", "Unusually Long Creature", true, true)
	clearRow("secret localized client-list entry")
	env._creatureTypes[#env._creatureTypes] = nil
	target("Riverglade Crocolisk", "Mechanical")
	clearRow("plain target after secret")
	check(not view.caption:HasAnySecretAspect() and not view.name:HasAnySecretAspect(), tag .. ": target reuse must clear the Text secret aspect")
	target("Ash", "Beast")
	check(view.name:GetFont() == path, tag .. ": a normal short target restores the caps face")
	local caption = ink(view.caption)
	check(caption[6] <= caption[5] + 3 * K.Widgets.Border(view.caption), tag .. ": a normal target releases the secret caption reserve")
	target("Hogger", nil)
	check(view.name:GetFont() == path and not view.name:IsTruncated(), tag .. ": a missing creature type leaves room for a short name")
	target("Riverglade Crocolisk", "Beast")
	env._units.target.creature = "Non-combat Pet"
	env.FireEvent("UNIT_LEVEL", "target")
	clearRow("caption event must refit an existing name")
	for _, width in ipairs({ 120, 180 }) do
		K.Layout.Set("unitframes.target", "width", 300)
		env.RunTimers()
		target("Riverglade Crocolisk", "Mechanical")
		K.Layout.Set("unitframes.target", "width", width)
		env.RunTimers()
		clearRow("resize existing target to " .. width, true)
		for _, creature in ipairs({ "Mechanical", "Non-combat Pet" }) do
			target("Riverglade Crocolisk", creature)
			clearRow("narrow slab width " .. width .. "/" .. creature, true)
			check(not view.name:IsShown() or view.name:IsTruncated(), tag .. ": no unbounded name at narrow slab widths")
		end
	end
	K.Layout.Set("unitframes.target", "width", 300)
	env.RunTimers()
	local g, s = view.geometry, view.s
	local row = { x = g.aura.x, y = g.aura.y, w = s.auraColumns * s.auraSize + (s.auraColumns - 1) * s.auraSpacing, h = s.auraSize + 16 }
	local m = g.marker
	check(m.x >= row.x + row.w + ns.Geometry.MARKER_GAP or m.x + m.w + ns.Geometry.MARKER_GAP <= row.x or m.y >= row.y + row.h or m.y + m.h <= row.y, tag .. ": raid marker clears debuffs and timers")
	check(m.x >= g.medal.x + g.medal.w and m.y + m.h <= 0, tag .. ": raid marker clears the medallion and outboard unit slab")
	check(#env._errors == 0 and K.ErrorCount() == 0, tag .. ": no errors: " .. tostring(env._errors[1]))
end
_G.RENDER_SCREEN, _G.RENDER_HUD_STYLE = nil, nil
assert(#failures == 0, table.concat(failures, "\n"))
print("unitframes medallions target row ok")
