-- test-minimap-parity-r2-review.lua: the round 2 review's probes: a protected addon button stays put in combat, secret results are never compared, the micro menu stops polling while hovered and closes when switched off, a page reset clears addon places, corner buttons stay clear at every size and screen, the compartment counts late registrations without sorting, settings refresh once, and a column addon button looks like its siblings.
local M = dofile("Tools/regression/minimap_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local W = M.W

local failures = {}
local function check(name, fn)
	local ok, err = pcall(fn)
	if not ok then
		failures[#failures + 1] = name .. ": " .. tostring(err)
	end
end

local function setup(env)
	env._lib = M.FakeLibDBIcon(env)
	env._lib:Add("BugSack")
	env._lib:Add("Details")
	env.CreateFrame("Button", "CharacterMicroButton", env.UIParent)
	env.CreateFrame("Button", "SpellbookMicroButton", env.UIParent)
	env.AddonCompartmentFrame.registeredAddons = { { text = "One", func = function() end } }
end

local function boot(width, height)
	local env, K, ns = M.New({ enabled = true, width = width, height = height, setup = setup })
	M.Settle(env)
	local function write(key, value)
		K.Options.Write("Minimap", key, value)
	end
	write("column.hover", false)
	return env, K, ns, write
end

local function clean(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

local function moves(frame)
	local n = 0
	for _, method in ipairs({ "ClearAllPoints", "SetPoint", "SetSize", "SetParent" }) do
		n = n + #W.Calls(frame, method)
	end
	return n
end

local function overlap(a, b)
	return math.min(a:GetRight(), b:GetRight()) > math.max(a:GetLeft(), b:GetLeft()) + 0.01
		and math.min(a:GetTop(), b:GetTop()) > math.max(a:GetBottom(), b:GetBottom()) + 0.01
end

check("1 protected button in combat", function()
	local env, K, ns, write = boot()
	local column, drawer, details = ns.Map.column, ns.Map.drawer, env._lib.objects.Details
	write("drawer.button", "Details")
	write("drawer.place", "column")
	assert(details:GetParent() == column.host, "setup: Details sits in the column")
	details.IsProtected = function() return true end
	env.SetCombat(true)
	local before = moves(details)
	write("drawer.place", "drawer")
	assert(moves(details) == before, "a protected button changing place in combat is not moved: " .. moves(details) - before .. " geometry calls")
	assert(details:GetParent() == column.host, "it keeps its column seat until combat ends")
	env.SetCombat(false)
	assert(details:GetParent() == drawer.panel and select(2, details:GetPoint(1)) == drawer.panel, "after combat it moves into the drawer")
	env.SetCombat(true)
	before = moves(details)
	write("drawer.spacing", 6)
	assert(moves(details) == before, "a protected button already in the drawer is not re-placed in combat: " .. moves(details) - before .. " geometry calls")
	env.SetCombat(false)
	details.IsProtected = nil
	clean(env, K)
end)

check("2 secret results", function()
	for _, path in ipairs({ "KstyleUI_Minimap/Drawer.lua", "KstyleUI_Minimap/Micro.lua" }) do
		local file = assert(io.open(path, "rb"))
		local source = file:read("*a")
		file:close()
		local line = 0
		for text in source:gmatch("([^\n]*)\n") do
			line = line + 1
			assert(not text:find(":Is%a+%(%)%s*[=~]="), path .. ":" .. line .. " compares an IsShown, IsProtected or IsEnabled result, which Forever returns secret for another addon's"
				.. " or Blizzard's frame; use Widgets.MayMove or Drawer.Shown, or check Widgets.IsSecret first")
		end
	end
end)

check("3 micro menu", function()
	local env, K, ns, write = boot()
	write("microMenu", true)
	env.CharacterMicroButton:Disable()
	local click = env.Minimap:GetScript("OnMouseUp")
	click(env.Minimap, "MiddleButton")
	local panel = ns.Micro.panel
	assert(panel and panel:IsShown(), "a middle-click opens the micro menu")
	assert(panel.rows[1]:IsShown() and panel.rows[1]:IsEnabled() == false, "a game button Forever disabled is a disabled row")
	assert(panel.rows[4]:IsShown() and panel.rows[4]:IsEnabled() == true, "an enabled game button is an enabled row")
	panel._mouseOver = true
	local before = #W.Calls(panel, "IsMouseOver")
	for _ = 1, 120 do W.Tick(env, 1 / 60) end
	local polls = #W.Calls(panel, "IsMouseOver") - before
	assert(polls <= 1 and panel:GetScript("OnUpdate") == nil, "while the pointer stays over the menu nothing polls: " .. polls .. " checks in 120 frames")
	write("microMenu", false)
	for _ = 1, 120 do W.Tick(env, 1 / 60) end
	assert(not panel:IsShown() and panel:GetScript("OnUpdate") == nil, "switching the option off closes the open menu")
	clean(env, K)
end)

check("4 page reset", function()
	local env, K, ns, write = boot()
	local S, drawer = ns.Settings, ns.Map.drawer
	Load({ "KstyleUI_Options/Model.lua" }, env)
	write("drawer.button", "Details")
	write("drawer.place", "hidden")
	write("drawer.button", "BugSack")
	write("drawer.place", "column")
	write("drawer.button", "")
	assert(S.Get("drawer.places").Details == "hidden" and S.Get("drawer.places").BugSack == "column", "choosing no button keeps every place")
	write("drawer.button", "Details")
	assert(S.Get("drawer.place") == "hidden" and S.Get("drawer.places").BugSack == "column", "choosing another button keeps the others' places")
	env._addons.KstyleUI_Options.Model.ResetSchema("Minimap", K.Options.Get("Minimap"))
	assert(next(S.Get("drawer.places")) == nil, "a page reset clears every addon button's place")
	for _, name in ipairs({ "BugSack", "Details" }) do
		assert(env._lib.objects[name]:GetParent() == drawer.panel, "and puts " .. name .. " back in the drawer")
	end
	clean(env, K)
end)

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local tag = screen[1] .. "x" .. screen[2]
	check("5 corners at " .. tag, function()
		local env, K, ns, write = boot(screen[1], screen[2])
		local column, face = ns.Map.column, ns.Map.face
		env._mail.new = true
		env.FireEvent("UPDATE_PENDING_MAIL")
		write("compartment.shown", true)
		write("compartment.scale", 1.5)
		local cb = column.buttons.compartment
		local normal = cb:GetWidth()
		write("column.free", true)
		write("column.spots", { compartment = { x = 15, y = 15 } })
		assert(W.Near(cb:GetWidth(), normal, 0.01), "a freely placed compartment keeps its size: " .. normal .. " then " .. cb:GetWidth())
		write("column.free", false)
		write("compartment.scale", 1)
		local row = K.Options.Row("Minimap", "column.size")
		for _, growth in ipairs({ "down", "up" }) do
			write("column.growth", growth)
			write("compartment.position", growth == "down" and "BOTTOMRIGHT" or "TOPRIGHT")
			for size = row.min, row.max do
				write("column.size", size)
				for name, button in pairs(column.buttons) do
					assert(name == "compartment" or not button:IsShown() or not overlap(cb, button),
						"the compartment at the column's far end overlaps the " .. name .. " button, growing " .. growth .. " at size " .. size)
				end
			end
		end
		write("column.size", row.min)
		write("column.growth", "down")
		write("compartment.position", "BOTTOMRIGHT")
		write("compartment.shown", false)
		write("difficulty.shown", true)
		write("difficulty.position", "BOTTOMRIGHT")
		local function captionX()
			face:SetDifficulty(nil)
			face:SetDifficulty("25H")
			return select(4, face.difficulty:GetPoint(1))
		end
		local x = captionX()
		env.AddonCompartmentFrame.registeredAddons = {}
		write("compartment.shown", true)
		assert(not cb:IsShown() and captionX() == x, "an empty, hidden compartment reserves no room: the caption moved from " .. x .. " to " .. captionX())
		clean(env, K)
	end)
end

check("6 compartment count", function()
	local env, K, ns, write = boot()
	write("compartment.shown", true)
	local cb = ns.Map.column.buttons.compartment
	assert(tostring(cb.tally:GetText()) == "1", "setup: the button counts one addon")
	env.AddonCompartmentFrame:RegisterAddon({ text = "Late", func = function() end })
	assert(tostring(cb.tally:GetText()) == "2", "an addon registering after load updates the count: " .. tostring(cb.tally:GetText()))
	local builds, entries = 0, ns.Drawer.CompartmentEntries
	ns.Drawer.CompartmentEntries = function(...)
		builds = builds + 1
		return entries(...)
	end
	env.FireEvent("UPDATE_PENDING_MAIL")
	write("compartment.shown", false)
	env.FireEvent("UPDATE_PENDING_MAIL")
	ns.Drawer.CompartmentEntries = entries
	assert(builds == 0, "mail events and settings build no sorted compartment list: " .. builds)
	clean(env, K)
end)

check("7 repeat work", function()
	local env, K, ns, write = boot()
	write("drawer.button", "Details")
	local refreshes, refresh = 0, ns.Map.Refresh
	ns.Map.Refresh = function(...)
		refreshes = refreshes + 1
		return refresh(...)
	end
	write("drawer.place", "hidden")
	ns.Map.Refresh = refresh
	assert(refreshes == 1, "a place change refreshes the map once: " .. refreshes)
	local tip = K.Widgets.Tooltip()
	local base = tip:GetScale()
	write("tooltipScale", 1.5)
	local button = ns.Map.column.buttons.tracking
	button:GetScript("OnEnter")(button)
	assert(tip:IsOwned(button) and W.Near(tip:GetScale(), base * 1.5, 0.001), "a button tooltip is scaled: " .. tostring(tip:GetScale()))
	button:GetScript("OnLeave")(button)
	local before = #W.Calls(tip, "SetScale")
	button:GetScript("OnEnter")(button)
	assert(#W.Calls(tip, "SetScale") == before, "reopening it at the same size sets no scale: " .. #W.Calls(tip, "SetScale") - before .. " calls")
	button:GetScript("OnLeave")(button)
	clean(env, K)
end)

check("8 column addon look", function()
	local env, K, _, write = boot()
	local details = env._lib.objects.Details
	local ringPath = K.Tokens.Texture("ringBevel")
	local function ring()
		for _, region in ipairs(W.Regions(details, "Texture")) do
			if region:GetTexture() == ringPath then
				return region
			end
		end
	end
	local tile = K.Skin.Backdrop(details)
	assert(tile and tile:IsShown() and not ring(), "setup: in the drawer Details has the drawer's tile")
	write("drawer.button", "Details")
	write("drawer.place", "column")
	assert(not tile:IsShown() and ring() and ring():IsShown(), "in the column it drops the tile for the column's crystal disc")
	assert(details.icon:GetWidth() * math.sqrt(2) <= details:GetWidth() + 0.01,
		"its square icon fits inside the disc, as the kit's glyphs do: " .. details.icon:GetWidth() .. " on " .. details:GetWidth())
	write("column.backgrounds", false)
	assert(not tile:IsShown() and not ring():IsShown(), "with backgrounds off it shows its bare symbol, as its siblings do")
	write("column.backgrounds", true)
	write("drawer.place", "drawer")
	assert(tile:IsShown() and not ring():IsShown(), "back in the drawer it has the tile again")
	clean(env, K)
end)

check("9 drawer clears the round column", function()
	local env, K, ns, write = boot(1920, 1080)
	local column, drawer = ns.Map.column, ns.Map.drawer
	write("column.hover", true)
	W.Click(column.buttons.drawer)
	assert(drawer.panel:IsShown(), "the drawer opens")
	for name, button in pairs(column.buttons) do
		assert(not button:IsShown() or not overlap(drawer.panel, button), "the open drawer covers the " .. name .. " button")
	end
	clean(env, K)
end)

assert(#failures == 0, #failures .. " review probes fail:\n" .. table.concat(failures, "\n"))
print("ok: minimap parity round 2 review")
