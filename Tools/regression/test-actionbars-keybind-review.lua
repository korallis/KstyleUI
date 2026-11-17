-- test-actionbars-keybind-review.lua: reviewed binding hazards retain camera controls, canonical chords, account bindings and clear feedback.
local AB = dofile("Tools/regression/actionbars_env.lua")
local failed = {}
local function check(name, fn)
	local ok, err = pcall(fn)
	print((ok and "PASS " or "FAIL ") .. name .. (ok and "" or ": " .. tostring(err)))
	if not ok then failed[#failed + 1] = name end
end
local function fresh(setup)
	local e, K, ns = AB.New({ setup = setup })
	AB.Enable(e, K)
	local mode = ns.Keybind
	assert(mode.Enter())
	local overlay = mode.overlays[ns.bars.bar1.buttons[1]]
	overlay:GetScript("OnEnter")(overlay)
	return e, K, ns, mode, overlay
end
local function read(path)
	local file = assert(io.open(path, "rb"))
	local data = file:read("*a")
	file:close()
	return data
end

check("camera mouse buttons", function()
	local e, _, _, mode, overlay = fresh(function(g)
		g._game.bindings.CAMERAORSELECTORMOVE = { "BUTTON1" }
		g._game.bindings.TURNORACTION = { "BUTTON2" }
	end)
	for _, key in ipairs({ "LeftButton", "RightButton", "Button1", "Button2", "BUTTON1", "BUTTON2" }) do
		overlay:GetScript("OnMouseDown")(overlay, key)
	end
	assert(next(mode.pending) == nil, "ignore left/right clicks instead of staging camera-binding replacements")
	mode.Save()
	assert(e.GetBindingAction("BUTTON1") == "CAMERAORSELECTORMOVE" and e.GetBindingAction("BUTTON2") == "TURNORACTION")
	assert(AB.Used(e) == nil, "clicks in binding mode must not activate the covered action")
end)

check("canonical fallback chords", function()
	local e, _, _, mode = fresh()
	e.CreateKeyChordStringUsingMetaKeyState = nil
	e._game.alt, e._game.ctrl, e._game.shift = true, true, true
	mode.Input("F5")
	assert(mode.pending["ALT-CTRL-SHIFT-F5"] == "ACTIONBUTTON1", "compose modifiers in Blizzard's ALT-CTRL-SHIFT-META order")
	mode.Exit()
end)

check("Blizzard chord helper", function()
	local e, _, _, mode = fresh()
	local called
	e.CreateKeyChordStringUsingMetaKeyState = function(key) called = key; return "META-" .. key end
	mode.Input("F6")
	assert(called == "F6" and mode.pending["META-F6"], "prefer the client's chord helper when available")
	mode.Exit()
end)

check("Mac command key", function()
	local e, _, _, mode = fresh()
	e.CreateKeyChordStringUsingMetaKeyState = nil
	e.IsMetaKeyDown = function() return true end
	mode.Input("1")
	assert(mode.pending["META-1"] == "ACTIONBUTTON1" and mode.pending["1"] == nil, "Cmd+1 must not steal plain 1")
	e._game.alt, e._game.ctrl, e._game.shift = true, true, true
	mode.Input("F7")
	assert(mode.pending["ALT-CTRL-SHIFT-META-F7"], "META is the last modifier before the key")
	mode.Exit()
end)

check("character to account confirmation and isolation", function()
	local e, K, _, mode = fresh(function(g)
		g._game.bindingSet = 2
		g._game.bindings.CHARACTER_ONLY = { "C" }
		g.CONFIRM_DELETING_CHARACTER_SPECIFIC_BINDINGS = "Native character binding deletion warning"
	end)
	local confirm, loads = nil, 0
	K.Widgets.Confirm = function(opts) confirm = opts; return { Close = function() end } end
	e.LoadBindings = function(set)
		assert(set == 1, "load account bindings before applying pending edits")
		loads = loads + 1
		e._game.bindings = { ACCOUNT_ONLY = { "A" } }
		return true
	end
	mode.Input("F9")
	mode.panel.character:SetValue(false)
	mode.Save()
	assert(confirm and confirm.text == e.CONFIRM_DELETING_CHARACTER_SPECIFIC_BINDINGS and not e._game.savedSet,
		"show Blizzard's deletion warning before switching character bindings to account")
	assert(loads == 0, "do not load or overwrite bindings before confirmation")
	confirm.onCancel()
	assert(mode.active and e.GetBindingAction("C") == "CHARACTER_ONLY" and not e._game.savedSet, "Cancel preserves the character set")
	mode.Save()
	confirm.onAccept()
	assert(loads == 1 and e._game.savedSet == 1 and e.GetBindingAction("A") == "ACCOUNT_ONLY", "Save preserves unrelated account bindings")
	assert(e.GetBindingAction("C") == "" and e.GetBindingAction("F9") == "ACTIONBUTTON1", "apply edits to the loaded account set")
end)

check("hover highlight changes the visible fill", function()
	local _, _, _, mode, overlay = fresh()
	overlay:GetScript("OnLeave")(overlay)
	local idle = select(4, overlay.chrome.fill[5]:GetVertexColor())
	overlay:GetScript("OnEnter")(overlay)
	local hovered = select(4, overlay.chrome.fill[5]:GetVertexColor())
	assert(hovered - idle >= 0.3, "hover must visibly brighten the fill, including an already-active stance rim")
	mode.Exit()
	assert(not overlay:IsShown(), "binding highlights never remain after Exit")
end)

check("localized key display", function()
	local e, _, _, mode = fresh()
	e.GetBindingText = function(key) return key:gsub("CTRL", "STRG") end
	mode.Input("CTRL-F")
	assert(mode.panel.current:GetText():find("STRG-F", 1, true), "display key names through GetBindingText")
	assert(mode.pending["CTRL-F"], "keep the canonical binding code separate from its display text")
	mode.Exit()
end)

check("existing possession terminology", function()
	for code, term in pairs({ deDE = "Gedankenkontrolle", frFR = "Contrôle mental", zhCN = "精神控制" }) do
		assert(read("Tools/locale/" .. code .. ".json"):find('"Possess": "' .. term .. '"', 1, true), "reuse the existing Possess term for " .. code)
	end
end)

check("scene binding uniqueness", function()
	assert(not read("Tools/render/scenes/actionbars_keybind.lua"):find("i %% 10"), "assign twelve distinct scene keys, including minus and equals")
end)

check("feature map retains native bind command", function()
	local row = read("docs/feature-map.md"):match("| Action bars and the shared action slot[^\n]+")
	assert(row and row:find("/kstyle bind", 1, true), "document the still-supported /kstyle bind command")
end)

check("kb alias ownership and core fallback", function()
	local e, K, ns = AB.New({ setup = function(g) g.SLASH_OTHER1 = "/kb" end })
	AB.Enable(e, K)
	assert(e.SLASH_KSTYLEKB1 ~= "/kb" and e.SLASH_KSTYLEKB2 ~= "/kb", "do not claim another loaded addon's /kb")
	assert(table.concat(e._prints or {}, " "):find("/kstyle kb", 1, true), "print the collision fallback hint")
	e.SlashCmdList.KSTYLE("kb")
	assert(ns.Keybind.active, "/kstyle kb always works when /kb is owned by another addon")
	ns.Keybind.Exit()
end)

assert(#failed == 0, "binding review regressions: " .. table.concat(failed, ", "))
print("keybinding review regressions ok")
