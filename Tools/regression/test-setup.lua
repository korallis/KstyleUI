-- test-setup.lua: the first-run setup opens once per account, walks four steps, and Apply switches modules on, writes the layout and offers a reload.
local W = dofile("Tools/regression/widget_env.lua")
local CoreEnv = W.CoreEnv
local Geometry = dofile("Tools/regression/geometry.lua")

local MODULES = { "UnitFrames", "ActionBars", "Cooldowns", "Chat" }

local function Boot(opts)
	opts = opts or {}
	local env, K = W.New({
		saved = opts.saved,
		layout = opts.layout,
		boot = false,
		setup = function(env)
			env.C_AddOns = {
				DoesAddOnExist = function(name)
					return not (opts.missing and opts.missing[name])
				end,
				LoadAddOn = function()
					return false, "MISSING"
				end,
			}
		end,
	})
	for _, name in ipairs(opts.modules or MODULES) do
		K.Modules.Register(CoreEnv.Module(name, { defaults = opts.defaults and opts.defaults[name] or {} }))
	end
	CoreEnv.Boot(env)
	return env, K
end

local function Open(env, K)
	K.Setup.Open()
	W.Settle(env)
	return K.Setup.window
end

local function Seen(K)
	return K.Store.Account().setupSeen == true
end

-- The account flag and the slash command ------------------------------------------------------------

do
	local env, K = Boot()
	assert(K.Features.account.setupSeen == false, "Features.account.setupSeen is the first-run switch, off by default")
	assert(K.Setup.window == nil or not K.Setup.window:IsShown(), "nothing shows before the login delay")
	env.RunTimers()
	W.Settle(env)
	local panel = K.Setup.window
	assert(panel and panel:IsShown(), "the setup opens on the account's first login")
	assert(K.Setup.Step() == 1, "it starts on the welcome step")
	assert(not Seen(K), "opening does not mark it seen")
	panel:Close()
	W.Settle(env)
	assert(not panel:IsShown() and Seen(K), "closing marks the setup seen for the account")
	assert(CoreEnv.Printed(env, "/kstyle setup"), "closing tells the player how to reopen it")
	env.SlashCmdList.KSTYLE("setup")
	W.Settle(env)
	assert(panel:IsShown() and K.Setup.Step() == 1, "/kstyle setup reopens it on the welcome step")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local env, K = Boot({ saved = { version = 1, account = { setupSeen = true } } })
	env.RunTimers()
	W.Settle(env)
	assert(K.Setup.window == nil or not K.Setup.window:IsShown(), "a later login does not open it")
end

-- The delayed first-login open never resets a setup the player already opened; reopening beats a closing fade

do
	local env, K = Boot()
	env.SlashCmdList.KSTYLE("setup")
	W.Settle(env)
	K.Setup.Go(2)
	W.Click(K.Setup.window.cards.Tank)
	env.RunTimers()
	W.Settle(env)
	assert(K.Setup.Step() == 2 and K.Setup.Choice().layout == "Tank", "the login timer leaves an open setup alone")
	assert(K.Setup.IsShown())
	K.Setup.window:Close()
	assert(not K.Setup.IsShown(), "closing counts at once, before the fade ends")
	K.Setup.Open()
	W.Settle(env)
	assert(K.Setup.window:IsShown() and K.Setup.IsShown(), "reopening during the closing fade keeps the window shown")
	K.Setup.window:Hide()
	K.Setup.Open()
	W.Settle(env)
	assert(K.Setup.window:IsShown(), "a window hidden some other way opens again")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The window: kit widgets, Layout registration and the four steps ------------------------------------

do
	local env, K = Boot({ layout = true })
	local panel = Open(env, K)
	local registered
	for _, entry in ipairs(env._layout) do
		if entry.key == "setup.window" then
			registered = entry
		end
	end
	assert(registered and registered.frame == panel and registered.opts.scalable, "the window registers with Layout as a scalable element")
	assert(panel.titleText and panel.closeButton, "a titled panel with a close button")
	local tabs = panel.steps
	assert(#tabs.buttons == 4, "a strip of four steps")
	assert(tabs:GetValue() == 1)
	assert(tabs:Select(3) == false, "steps not reached yet are disabled")
	assert(panel.pages[1]:IsShown() and not panel.pages[2]:IsShown(), "one page at a time")
	assert(not panel.back:IsShown(), "no Back on the welcome step")
	W.Click(panel.next)
	W.Settle(env)
	assert(K.Setup.Step() == 2 and panel.pages[2]:IsShown() and not panel.pages[1]:IsShown(), "Next moves to the layout step")
	assert(tabs:GetValue() == 2 and panel.back:IsShown())
	W.Click(panel.back)
	W.Settle(env)
	assert(K.Setup.Step() == 1, "Back goes back")
	assert(tabs:Select(2) == true and K.Setup.Step() == 2, "a reached step can be picked from the strip")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Layout step: three cards with previews; a click picks one ---------------------------------------------

do
	local env, K = Boot()
	local panel = Open(env, K)
	K.Setup.Go(2)
	W.Settle(env)
	local cards = panel.cards
	assert(cards.DPS and cards.Tank and cards.Healer, "a card per layout")
	assert(K.Setup.Choice().layout == "DPS" and cards.DPS.selected, "DPS is picked by default")
	local rects = 0
	for _, region in ipairs(W.Regions(cards.Healer.screen, "Texture")) do
		if region.isElement then
			rects = rects + 1
		end
	end
	assert(rects >= 30, "each card draws its layout's elements in a preview, got " .. rects)
	W.Click(cards.Healer)
	W.Settle(env)
	assert(K.Setup.Choice().layout == "Healer" and cards.Healer.selected and not cards.DPS.selected, "a click picks the layout")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Module step: every loaded module on, with a note; missing modules disabled -------------------------------

do
	local env, K = Boot()
	local panel = Open(env, K)
	K.Setup.Go(3)
	W.Settle(env)
	local toggles = panel.toggles
	for _, name in ipairs(MODULES) do
		assert(toggles[name] and toggles[name]:GetValue() == true and toggles[name]:IsEnabled(), name .. " is listed and on")
		assert(toggles[name].note and toggles[name].note:GetText() ~= "", name .. " has a one-line note")
		local p = toggles[name].note._points[1]
		assert(p[1] == "TOPLEFT" and p[2] == toggles[name] and p[3] == "BOTTOMLEFT" and p[5] <= 0, name .. "'s note hangs below the toggle, whatever its height")
		assert(p[4] >= toggles[name].trackBox:GetWidth(), name .. "'s note starts right of the 58-unit track, under the label")
	end
	assert(toggles.Bags and toggles.Bags:GetValue() == false and not toggles.Bags:IsEnabled(), "a module whose addon did not load is off and disabled")
	assert(toggles.Options == nil and toggles.Icons == nil, "the settings window is not a module to pick, and there is no icon module")
	toggles.Chat:SetValue(false)
	assert(K.Setup.Choice().modules.Chat == false, "a toggle changes the choice")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Apply: modules, positions, the account flag and the reload button ---------------------------------------

do
	local env, K = Boot()
	local panel = Open(env, K)
	K.Setup.Go(2)
	W.Click(panel.cards.Tank)
	K.Setup.Go(3)
	panel.toggles.Chat:SetValue(false)
	K.Setup.Go(4)
	W.Settle(env)
	assert(panel.summary:GetText():find("Tank", 1, true), "the summary names the layout")
	assert(panel.apply:IsShown() and not panel.reload:IsShown(), "Apply shows on the summary, the reload button after it")
	local changed = {}
	K.Callbacks.Register("SettingChanged", "test", function(_, module, key, value)
		changed[module .. "." .. key] = value
	end)
	W.Click(panel.apply)
	W.Settle(env)
	for _, name in ipairs({ "UnitFrames", "ActionBars", "Cooldowns" }) do
		assert(K.Modules.IsEnabled(name) and K.Modules.IsRunning(name), name .. " is switched on and running")
		assert(changed[name .. ".enabled"] == true, name .. " went through Options.Write, so an open settings window refreshes")
	end
	assert(not K.Modules.IsEnabled("Chat"), "a module the player turned off stays off")
	assert(K.Store.Module("Bags").enabled == false, "a module that did not load is not switched on")
	local stored = K.Store.Layout()
	local tank = K.Setup.Layouts.Get("Tank")
	for key, position in pairs(tank) do
		local entry = stored[key]
		assert(entry and entry.anchor == position.anchor and entry.x == position.x and entry.y == position.y, "Apply writes " .. key)
	end
	assert(Seen(K), "Apply marks the setup seen")
	assert(panel.reload:IsShown() and panel.reload.label:GetText() == "Reload", "Apply offers the secure reload button")
	assert(panel.later:IsShown() and not panel.apply:IsShown())
	assert(panel.reload.primary, "styled as the primary action")
	W.Click(panel.later)
	W.Settle(env)
	assert(not panel:IsShown(), "Later closes the window")
	local logged
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		if entry.module == "Setup" and entry.message:find("applied layout Tank", 1, true) then
			logged = entry.message
		end
	end
	assert(logged, "Apply logs what it did")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Apply keeps the other fields of a stored element and uses Layout's live API for registered elements -----

do
	local env, K = Boot()
	local stored = K.Store.Layout()
	stored["chat.main"] = { anchor = "CENTER", x = 1, y = 2, width = 500, shown = "combat" }
	local updates = {}
	K.Layout = {
		Get = function(key)
			if key == "unitframes.player" then
				return { anchor = "CENTER", x = 0, y = 0 }
			end
		end,
		Update = function(key, values)
			updates[key] = values
			return true
		end,
	}
	local ok = K.Setup.Apply({ layout = "DPS", modules = {} })
	assert(ok, "Apply returns true")
	local chat = stored["chat.main"]
	local dps = K.Setup.Layouts.Get("DPS")["chat.main"]
	assert(chat.anchor == dps.anchor and chat.x == dps.x and chat.width == 500 and chat.shown == "combat", "Apply moves an element and keeps its size and rules")
	assert(updates["unitframes.player"] and updates["unitframes.player"].x == K.Setup.Layouts.Get("DPS")["unitframes.player"].x, "a registered element moves at once through Layout.Update")
	assert(stored["unitframes.player"] == nil, "Layout stores what it applies itself")
	assert(K.Setup.Apply({ layout = "Raid", modules = {} }) == false, "an unknown layout is refused")
	-- Tank sizes the meters with the positions: two damage rows over two threat rows, so the right rail fits.
	updates = {}
	K.Layout.Get = function(key)
		if key == "meters.damage" then
			return { anchor = "CENTER", x = 0, y = 0 }
		end
	end
	assert(K.Setup.Apply({ layout = "Tank", modules = {} }))
	assert(updates["meters.damage"] and updates["meters.damage"].height == 98 and updates["meters.damage"].width == 318, "a registered meter takes the layout's size through Layout.Update")
	assert(stored["meters.threat"].height == 98 and stored["meters.threat"].y == K.Setup.Layouts.Get("Tank")["meters.threat"].y, "a meter that has not registered keeps the size for the reload")
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
	assert(updates["chat.main"] == nil and stored["meters.threat"].height == 144, "DPS puts the meters back to their footprints")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Apply writes the Lumen layout's bars, meters and group sizes, and remembers the layout ----------------------

do
	local function bar(rows)
		return { enabled = true, rows = rows }
	end
	local defaults = {
		ActionBars = {
			bar1 = bar(1), bar2 = bar(1), bar3 = bar(12), bar4 = bar(12), bar5 = bar(12), bar6 = bar(12), pet = bar(1), stance = bar(1),
		},
		Meters = { threat = { shown = true } },
		GroupFrames = { party = { height = 46, spacing = 10 }, raid = { height = 40, width = 72, groupsPerRow = 8 } },
		Auras = { buffs = { rows = 2 }, card = { docked = false } },
		DataBars = { strip = { menus = false } },
	}
	local env, K = Boot({ modules = { "ActionBars", "Meters", "GroupFrames", "Chat", "Auras", "DataBars" }, defaults = defaults })
	assert(K.Layout.Setting("preset") == "DPS", "a profile that never applied a layout has the DPS one")
	assert(K.Setup.Apply({ layout = "Healer", modules = { ActionBars = true, Meters = true, GroupFrames = true, Chat = true } }))
	local bars = K.Store.Module("ActionBars")
	assert(bars.bar1.enabled == true and bars.bar1.rows == 1, "Apply keeps bar 1 on, one row")
	for i = 2, 6 do
		assert(bars["bar" .. i].enabled == false, "Apply switches bar " .. i .. " off")
	end
	assert(bars.pet.rows == 2 and bars.stance.rows == 2, "Apply folds the pet and stance sockets into two rows")
	assert(K.Store.Module("Meters").threat.shown == false, "Healer hides the threat card")
	local group = K.Store.Module("GroupFrames")
	assert(K.Store.Module("Auras").buffs.rows == 1 and K.Store.Module("Auras").card.docked == true, "Apply writes one buff row in the Blessings card, the debuffs docked")
	assert(K.Store.Module("DataBars").strip.menus == true, "Apply docks the menu and the bags in the readout card")
	assert(group.party.height == 46 and group.party.spacing == 8 and group.raid.height == 46 and group.raid.groupsPerRow == 4 and group.raid.width == 77, "Healer writes larger party and raid frames, four groups a row")
	assert(K.Layout.Setting("preset") == "Healer", "Apply remembers the layout for Layout Mode's story slot")
	assert(K.Setup.Apply({ layout = "Tank", modules = { ActionBars = true, Meters = true, GroupFrames = true } }))
	assert(K.Store.Module("Meters").threat.shown == true and K.Store.Module("GroupFrames").party.height == 40, "Tank shows the threat card and puts the party back to 40")
	assert(K.Layout.Setting("preset") == "Tank")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The layout cards draw the story slot, and leave out what the layout switches off -----------------------------

do
	local env, K = Boot()
	local panel = Open(env, K)
	K.Setup.Go(2)
	W.Settle(env)
	for _, name in ipairs(K.Setup.Layouts.Names()) do
		local card = panel.cards[name]
		assert(card.slot and card.slot:IsShown(), name .. "'s card outlines the story slot")
		assert(panel.layoutHint:GetText():find("Story rail", 1, true) and panel.layoutHint:GetText():find("Edit Mode", 1, true), "the step names the Story rail and says what goes there")
		for _, rect in ipairs(card.rects) do
			assert(K.Setup.Layouts.Shown(name, rect.element.key) ~= false or not rect:IsShown(), name .. "'s card hides " .. rect.element.key .. ", which the layout switches off")
		end
	end
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Layout Mode outlines the story slot of the layout last applied, with a hint ------------------------------------

do
	local env, K = Boot()
	assert(K.Setup.Apply({ layout = "Healer", modules = {} }))
	assert(K.Layout.Enter(), "Layout Mode opens")
	W.Settle(env)
	local slot = K.Layout.Mode.Slot()
	assert(slot and slot:IsShown(), "Layout Mode shows the story slot")
	assert(slot.label:GetText() == "Story rail" and slot.hint:GetText():find("RestedXP", 1, true) and slot.hint:GetText():find("Edit Mode", 1, true), "labelled, with a one-line hint")
	local want = K.Setup.Layouts.Slot("Healer")
	local rw, rh = K.Layout.RootSize()
	local l, b, r, t = K.Setup.Layouts.Rect(want, want, rw, rh)
	local got = assert(Geometry.Rect(slot, K.Scale.Root()))
	assert(math.abs(got.left - l) < 1 and math.abs(got.bottom - b) < 1 and math.abs(got.right - r) < 1 and math.abs(got.top - t) < 1, "at the Healer slot")
	assert(not slot:IsMouseEnabled(), "the outline never takes the mouse from the frames the player drops on it")
	local line = assert(Geometry.Rect(slot.raidLine, K.Scale.Root()))
	assert(slot.raidLine:IsShown() and math.abs(line.top - (t - want.raid)) < 1, "a line marks how far the raid frames reach into the slot")
	assert(slot.raidText:GetText():find("raid", 1, true), "and says so")
	K.Layout.Exit(true)
	W.Settle(env)
	assert(not slot:IsShown(), "and hides with Layout Mode")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Combat: Apply waits for nothing protected; modules start when combat ends -------------------------------

do
	local env, K = Boot()
	local panel = Open(env, K)
	K.Setup.Go(4)
	env.SetCombat(true)
	W.Click(panel.apply)
	W.Settle(env)
	assert(not K.Modules.IsRunning("UnitFrames"), "modules wait for combat to end")
	assert(K.Store.Module("UnitFrames").enabled == true, "the switch is set at once")
	env.SetCombat(false)
	assert(K.Modules.IsRunning("UnitFrames"), "and start after combat")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Escape closes; changing a choice after Apply offers Apply again ---------------------------------------

do
	local env, K = Boot()
	local panel = Open(env, K)
	K.Setup.Go(4)
	W.Click(panel.apply)
	K.Setup.Go(3)
	panel.toggles.Chat:SetValue(false)
	K.Setup.Go(4)
	W.Settle(env)
	assert(panel.apply:IsShown() and not panel.reload:IsShown(), "a changed choice can be applied again")
	W.Key(panel, "ESCAPE")
	W.Settle(env)
	assert(not panel:IsShown(), "Escape closes the setup")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Each card is the button grade; its screen preview is a glass panel at the tile chamfer with the shadow ----

do
	local env, K = Boot()
	local panel = Open(env, K)
	K.Setup.Go(2)
	W.Settle(env)
	local card = panel.cards.DPS
	local br, bg, bb = K.Tokens.Color("buttonFill")
	local r, g, b = card.chrome.fill[5]:GetVertexColor()
	assert(W.Near(r, br) and W.Near(g, bg) and W.Near(b, bb), "the card body is the button grade's tone")
	assert(card.chrome.shapeName == "tile" and not card.chrome.shadow[5]:IsShown(), "a tile without a shadow")
	local sr, sg, sb = K.Tokens.Color("surface")
	r, g, b = card.screenChrome.fill[5]:GetVertexColor()
	assert(W.Near(r, sr) and W.Near(g, sg) and W.Near(b, sb), "the screen preview is filled surface")
	assert(card.screenChrome.shapeName == "tile", "at the tile chamfer")
	assert(card.screenChrome.shadow[5]:IsShown(), "with the glass panel's drop shadow")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("setup ok")
