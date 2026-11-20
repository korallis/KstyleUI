-- test-actionbars-options.lua: the real options controls select every bar and change only its own button count.
local AB = dofile("Tools/regression/actionbars_env.lua")
local O = dofile("Tools/regression/options_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local env, K, bars = AB.New({ setup = function(e)
	for i = 1, 10 do e._game.forms[i] = { texture = 132355, spellID = 2457 + i } end
	e._game.petExists = true
	e.C_AddOns.LoadAddOn = function(name)
		if name == "KstyleUI_Options" and not e._addons[name] then Load(O.Files(), e) end
		return true
	end
end })
AB.Enable(env, K)
assert(K.Options.Open("ActionBars"))
local ns = env._addons.KstyleUI_Options
local function Settle() env.RunTimers(); AB.W.Settle(env); env.RunTimers() end
local function Jump(key)
	ns.Window.Jump({ page = "ActionBars", module = "ActionBars", key = key })
	Settle()
	for _, row in ipairs(ns.Window.Parts().content.rows) do
		if row:IsShown() and row.item and row.item.key == key then return row end
	end
	error("no visible control for " .. key)
end
Settle()
K.Options.Write("ActionBars", "slab", false)
K.Options.Write("ActionBars", "useTray", false)
local choices = {}
for _, def in ipairs(bars.BARS) do choices[#choices + 1] = def end
choices[#choices + 1] = bars.Consumables.def
K.Options.Write("ActionBars", "consumables.hideEmpty", false)
for _, def in ipairs(choices) do
	local selector = Jump("editBar")
	local picker = assert(selector.controls.segmented, "use visible tabs for every bar")
	AB.W.Click(picker.buttons[assert(picker:IndexOf(def.key))])
	Settle()
	K.Options.Write("ActionBars", def.key .. ".enabled", true)
	Settle()
	for _, field in ipairs({ "buttons", "rows", "orientation", "growth", "size", "spacing", "backing", "fade", "hotkey", "cooldown", "visibility", "reverse", "clickThrough", "visibilityBuilder.combat", "visibilityBuilder.mode" }) do
		local found
		for _, item in ipairs(ns.Window.State().items) do if item.key == def.key .. "." .. field then found = true end end
		assert(found, def.key .. " exposes " .. field)
	end
	if def.key == "bar3" then
		local found
		for _, item in ipairs(ns.Window.State().items) do if item.key == "bar3.finished" then found = true end end
		assert(found, "the Finished third bar switch belongs below its own header")
	end
	local before = K.Options.Copy(K.Store.Module("ActionBars"))
	local row = Jump(def.key .. ".buttons")
	row.controls.slider:SetValue(6)
	Settle()
	assert(K.Store.Module("ActionBars")[def.key].buttons == 6, def.key .. " Buttons writes its bar")
	local live = def.kind == "consumable" and bars.Consumables or bars.bars[def.key]
	assert(live.buttons[6]:IsShown() and not live.buttons[7]:IsShown(), def.key .. " Buttons applies to the live bar")
	for _, other in ipairs(choices) do
		if other.key ~= def.key then
			assert(K.Options.Equal(before[other.key], K.Store.Module("ActionBars")[other.key]), "changing " .. def.key .. " also changed " .. other.key)
		end
	end
	AB.W.Click(Jump(def.key .. ".visibilityBuilder.combat").controls.toggle)
	Settle()
	assert(K.Store.Module("ActionBars")[def.key].visibility == "[combat] show; hide", "builder ticks write this bar's macro")
	local text = Jump(def.key .. ".visibility").controls.text
	text:SetText("[mod:alt] hide; show")
	text:GetScript("OnEnterPressed")(text)
	Settle()
	assert(K.Store.Module("ActionBars")[def.key].visibility == "[mod:alt] hide; show", "visibility writes the selected bar")
	if def.kind == "consumable" then
		assert(K.Options.Row("ActionBars", "consumables.combat").disableWhen(K.Store.Module("ActionBars")), "custom visibility disables the consumables' built-in visibility switches")
	end
	env._game.mod = "alt"
	env.RunStateDrivers()
	assert(not live.header:IsShown(), def.key .. " custom visibility hides securely")
	env._game.mod = nil
	env.RunStateDrivers()
	assert(live.header:IsShown(), def.key .. " custom visibility restores securely")
	local layoutItems = ns.Model.Visible(ns.Model.PageItems(ns.Pages.Find(ns.Pages.List(), "ActionBars")))
	for _, item in ipairs(layoutItems) do
		if item.element then assert(item.element == def.element, "only the selected bar's layout settings appear") end
	end
	for _, label in ipairs({ "Scale", "Opacity in combat", "Opacity out of combat", "Shown" }) do
		local found
		for _, item in ipairs(layoutItems) do
			if item.element == def.element and item.label == K.L[label] then found = item; break end
		end
		assert(found, def.key .. " exposes " .. label)
		if label == "Scale" then
			found.set(0.9)
			assert(math.abs(live.holder:GetScale() - 0.9) < 0.001, "scale applies to the selected bar")
		elseif label == "Opacity out of combat" then
			found.set(0.5)
			Settle()
			assert(math.abs(live.holder:GetAlpha() - 0.5) < 0.001, "opacity applies to the selected bar")
		end
	end
	K.Options.Write("ActionBars", def.key .. ".enabled", false)
	Settle()
	for _, item in ipairs(ns.Window.State().items) do
		assert(item.key ~= def.key .. ".rows" and item.key ~= def.key .. ".buttons", "a disabled bar hides its controls")
	end
end
K.Options.Write("ActionBars", "editBar", "bar1")
K.Options.Write("ActionBars", "bar1.enabled", true)
K.Options.Write("ActionBars", "bar1.paging", "[mod:alt] 2; 1")
assert(K.Options.Row("ActionBars", "bar1.pageForms").disableWhen(K.Store.Module("ActionBars")), "custom paging disables built-in paging rules")
K.Options.Write("HudStyle", "style", "medallions")
K.Options.Write("ActionBars", "slab", true)
assert(not K.Options.Row("ActionBars", "bar1.rows").showWhen(K.Store.Module("ActionBars")), "slab hides fixed geometry")
AB.W.Click(Jump("slab").controls.toggle)
assert(K.Options.Row("ActionBars", "bar1.rows").showWhen(K.Store.Module("ActionBars")), "one click frees the slab's geometry")
K.Options.Write("ActionBars", "bar2.enabled", true)
local oldDriver = env.Driver(bars.bars.bar2.header, "visibility")
env._combat = true
K.Options.Write("ActionBars", "bar2.visibility", "[combat] show; hide")
assert(env.Driver(bars.bars.bar2.header, "visibility") == oldDriver, "visibility edits wait until combat ends")
env._combat = false
env.FireEvent("PLAYER_REGEN_ENABLED")
assert(env.Driver(bars.bars.bar2.header, "visibility") == "[combat] show; hide", "combat end applies the queued visibility driver")
assert(#env._blocked == 0, tostring(env._blocked[1]))
assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
print("actionbars options ok: every picker choice refreshes, every Buttons slider writes and applies independently")
