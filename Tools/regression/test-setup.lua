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

-- First run: closing the setup without Apply applies the picked layout (DPS) with every loaded module, so a skipped
-- wizard never leaves an empty screen; Keep my UI is the opt-out; a later /kstyle setup closes with no change.

local function Login(opts)
	local env, K = Boot(opts)
	env.RunTimers()
	W.Settle(env)
	return env, K, K.Setup.window
end

do
	local env, K, panel = Login()
	assert(panel and panel:IsShown(), "the first-run setup opens")
	assert(panel.welcomeNote and panel.welcomeNote:IsShown() and panel.welcomeNote:GetText():find("DPS", 1, true), "the welcome step says closing uses the DPS layout")
	assert(panel.skip.label:GetText() == "Keep my UI", "the welcome step's left button is the opt-out")
	panel:Close()
	W.Settle(env)
	for _, name in ipairs(MODULES) do
		assert(K.Modules.IsEnabled(name), "closing the first-run setup switches " .. name .. " on")
	end
	assert(K.Layout.Setting("preset") == "DPS", "and applies the DPS layout")
	assert(K.Store.Layout()["chat.main"] and K.Store.Layout()["chat.main"].x == K.Setup.Layouts.Get("DPS")["chat.main"].x, "with its positions")
	assert(Seen(K), "and marks the setup seen")
	assert(CoreEnv.Printed(env, "DPS") and CoreEnv.Printed(env, "/kstyle setup"), "the player is told what was applied and how to change it")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local env, K, panel = Login()
	W.Click(panel.skip)
	W.Settle(env)
	assert(not panel:IsShown() and Seen(K), "Keep my UI closes the setup and marks it seen")
	for _, name in ipairs(MODULES) do
		assert(not K.Modules.IsEnabled(name), "Keep my UI leaves " .. name .. " off")
	end
	assert(next(K.Store.Layout()) == nil, "and moves nothing")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local env, K, panel = Login()
	K.Setup.Go(2)
	W.Click(panel.cards.Healer)
	W.Key(panel, "ESCAPE")
	W.Settle(env)
	assert(K.Layout.Setting("preset") == "Healer", "Escape on the first run applies the layout the player had picked")
	env.SlashCmdList.KSTYLE("setup")
	W.Settle(env)
	K.Setup.Go(2)
	W.Click(panel.cards.Tank)
	panel:Close()
	W.Settle(env)
	assert(K.Layout.Setting("preset") == "Healer", "closing a later setup changes nothing")
	assert(not panel.welcomeNote:IsShown(), "and a later setup does not promise a layout on close")
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

-- Layout step: three role cards over one large preview of the picked layout; a click picks one, a hover previews it

local function Measured(env)
	env._textWidth = function(text, _, size)
		return #text * size * 0.5
	end
end

do
	local env, K = Boot()
	Measured(env)
	local panel = Open(env, K)
	K.Setup.Go(2)
	W.Settle(env)
	local cards, preview = panel.cards, panel.preview
	assert(cards.DPS and cards.Tank and cards.Healer, "a card per layout")
	assert(K.Setup.Choice().layout == "DPS" and cards.DPS.selected, "DPS is picked by default")
	assert(preview and preview.layout == "DPS", "the preview shows the picked layout")
	local rects = 0
	for _, rect in ipairs(preview.rects) do
		if rect:IsShown() then
			rects = rects + 1
		end
	end
	assert(rects >= 30, "the preview draws the layout's elements at their real footprints, got " .. rects)
	W.Click(cards.Healer)
	W.Settle(env)
	assert(K.Setup.Choice().layout == "Healer" and cards.Healer.selected and not cards.DPS.selected, "a click picks the layout")
	assert(preview.layout == "Healer", "and the preview follows")
	W.Enter(cards.Tank)
	assert(preview.layout == "Tank", "hovering a card previews its layout")
	W.Leave(cards.Tank)
	assert(preview.layout == "Healer", "and leaving it shows the picked one again")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The preview names its elements (round 4, Muse #4, Fable #5: DPS and Tank once read the same from abstract blocks):
-- a block whose label fits carries it, its short name when the full one does not fit, and no label when neither
-- does, so no label is ever cut or spills; Tank's threat card is named, and DPS draws none.

do
	local env, K = Boot()
	Measured(env)
	local panel = Open(env, K)
	K.Setup.Go(2)
	W.Settle(env)
	local preview = panel.preview
	local root = K.Scale.Root()
	local function labels()
		local out = {}
		for _, rect in ipairs(preview.rects) do
			local label = rect.label
			if rect:IsShown() and label:IsShown() then
				local text = label:GetText()
				out[rect.element.key] = text
				local box = assert(Geometry.Rect(rect, root))
				local width = 0
				for line in text:gmatch("[^\n]+") do
					width = math.max(width, env._textWidth(line, nil, select(2, label:GetFont()) or 12))
				end
				assert(width <= box.right - box.left + 0.5, rect.element.key .. "'s label '" .. text .. "' fits its block")
				assert(not label:IsTruncated(), rect.element.key .. "'s label is whole")
			end
		end
		return out
	end
	local dps = labels()
	for _, key in ipairs({ "unitframes.target", "chat.main", "minimap.main", "groupframes.party", "meters.damage" }) do
		assert(dps[key], "DPS names " .. key)
	end
	assert(not dps["meters.threat"], "DPS draws no threat card")
	-- Round 5, Fable #5: a block read "TEXT"; your combat text is named as such.
	assert(dps["combattext.player"] and dps["combattext.player"]:lower():gsub("%s+", " "):find("combat text", 1, true), "DPS names your combat text: " .. tostring(dps["combattext.player"]))
	W.Click(panel.cards.Tank)
	W.Settle(env)
	local tank = labels()
	assert(tank["meters.threat"], "Tank names its threat card")
	-- Round 5, Opus #9: German names (BEDROHUNG, STAERKUNGSZAUBER) once left their blocks bare. A name that does not fit
	-- at the caption size steps down, to no less than the floor, before the block goes unlabelled.
	env._textWidth = function(text, _, size)
		return #text * size * 0.8
	end
	K.Setup.Go(1)
	K.Setup.Go(2)
	W.Settle(env)
	local wide = labels()
	assert(wide["meters.threat"] and wide["auras.buffs"], "with wider glyphs the threat and buff blocks keep their names")
	for _, rect in ipairs(preview.rects) do
		if rect:IsShown() and rect.label:IsShown() then
			local _, size = rect.label:GetFont()
			assert(size >= 8, rect.element.key .. "'s name stays at least 8 units, got " .. tostring(size))
		end
	end
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The preview names the layout it draws (round 5, Fable #5: with DPS picked and the mouse on Tank, Tank's threat card
-- read as DPS's): a line over the legend says which layout the blocks are, and follows the hover.
do
	local env, K = Boot()
	local panel = Open(env, K)
	K.Setup.Go(2)
	W.Settle(env)
	assert(panel.previewName and panel.previewName:IsShown(), "the layout step names the previewed layout")
	assert(panel.previewName:GetText():lower():find("dps", 1, true), "the picked one: " .. tostring(panel.previewName:GetText()))
	W.Enter(panel.cards.Tank)
	assert(panel.previewName:GetText():lower():find("tank", 1, true), "the hovered one: " .. tostring(panel.previewName:GetText()))
	W.Leave(panel.cards.Tank)
	assert(panel.previewName:GetText():lower():find("dps", 1, true), "and back")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The step fills its page: the preview and its legend reach down to the buttons, and nothing leaves the page

do
	local env, K = Boot()
	Measured(env)
	local panel = Open(env, K)
	K.Setup.Go(2)
	W.Settle(env)
	local root = K.Scale.Root()
	local page = assert(Geometry.Rect(panel.pages[2], root))
	local lowest = math.huge
	for _, object in ipairs({ panel.preview, panel.cards.DPS, panel.cards.Tank, panel.cards.Healer }) do
		local box = assert(Geometry.Rect(object, root))
		assert(Geometry.Outside(box, page) < 0.5, "everything on the layout step stays on its page")
		lowest = math.min(lowest, box.bottom)
	end
	local preview = assert(Geometry.Rect(panel.preview, root))
	local p = panel.previewName._points[1]
	assert(p[2] == panel.preview and p[3] == "TOPRIGHT", "the legend, headed by the previewed layout's name, stands beside the preview")
	local h = panel.layoutHint._points[1]
	assert(h[2] == panel.previewName and h[3] == "BOTTOMLEFT", "the legend's text runs under that name")
	assert(preview.right + p[4] + panel.layoutHint:GetWidth() <= page.right + 0.5, "and ends at the page's right edge")
	assert(lowest - page.bottom <= K.Tokens.Size("gapLarge") * 2, "the step has no empty lower half: its content ends " .. (lowest - page.bottom) .. " units above the page bottom")
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
	-- Tank sizes the meters with the positions: the threat card at the combat cluster's side, 200 by 112.
	updates = {}
	K.Layout.Get = function(key)
		if key == "meters.threat" then
			return { anchor = "CENTER", x = 0, y = 0 }
		end
	end
	assert(K.Setup.Apply({ layout = "Tank", modules = {} }))
	assert(updates["meters.threat"] and updates["meters.threat"].height == 112 and updates["meters.threat"].width == 200, "a registered meter takes the layout's size through Layout.Update")
	assert(stored["meters.damage"].height == 190 and stored["meters.damage"].y == K.Setup.Layouts.Get("Tank")["meters.damage"].y, "a meter that has not registered keeps the size for the reload")
	updates = {}
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
	assert(updates["chat.main"] == nil and updates["meters.threat"].height == 144 and updates["meters.threat"].width == 318 and stored["meters.damage"].height == 190, "DPS puts the meters back to their footprints")
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

-- The preview draws the story slot, and leaves out what the layout switches off ------------------------------

do
	local env, K = Boot()
	local panel = Open(env, K)
	K.Setup.Go(2)
	W.Settle(env)
	local preview = panel.preview
	for _, name in ipairs(K.Setup.Layouts.Names()) do
		W.Click(panel.cards[name])
		W.Settle(env)
		assert(preview.slot and preview.slot:IsShown(), name .. "'s preview outlines the story slot")
		assert(panel.layoutHint:GetText():find("Story rail", 1, true) and panel.layoutHint:GetText():find("Edit Mode", 1, true), "the step names the Story rail and says what goes there")
		assert(panel.layoutHint:GetText():find("Apply places the quest tracker there", 1, true), "and that Apply places the tracker itself (round 3, Opus #4)")
		assert(not panel.layoutHint:GetText():find("yourself", 1, true), "with no drag instruction: a refusal gets Try again on the summary (round 4, Muse #4)")
		-- Round 5, Muse #5: the RestedXP step moved to the summary's checklist; the layout choice carries no chore.
		assert(not panel.layoutHint:GetText():find("Drag", 1, true) and not K.Setup.Layouts.Slot(name).hint:find("Drag", 1, true), "the layout step and the slot hint ask for no drag")
		for _, rect in ipairs(preview.rects) do
			assert(K.Setup.Layouts.Shown(name, rect.element.key) ~= false or not rect:IsShown(), name .. "'s preview hides " .. rect.element.key .. ", which the layout switches off")
		end
	end
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The preview tells the roles apart: each block is the real footprint, and the elements whose place or presence
-- differs between the layouts (the group frames, the meters, the boss column, your combat text) stand out brighter
-- than the shared hands and rails, so Tank's threat card and Healer's group frames read at a glance (round 3, Muse #6).
do
	local env, K = Boot()
	local panel = Open(env, K)
	K.Setup.Go(2)
	W.Settle(env)
	local Layouts = K.Setup.Layouts
	local function alpha(rect)
		local call = W.LastCall(rect, "SetColorTexture")
		return call and call[4] or 0
	end
	local roles = {}
	for _, name in ipairs(Layouts.Names()) do
		W.Click(panel.cards[name])
		W.Settle(env)
		local role, shared = 0, 1
		for _, rect in ipairs(panel.preview.rects) do
			if rect:IsShown() then
				if rect.role then
					role = math.max(role, alpha(rect))
					roles[name] = (roles[name] or "") .. rect.element.key .. ";"
				else
					shared = math.min(shared, alpha(rect))
				end
			end
		end
		assert(role > 0 and role >= shared + 0.25, name .. "'s role elements stand out from the shared ones: " .. role .. " over " .. shared)
	end
	assert(roles.DPS:find("groupframes.party", 1, true) and roles.Tank:find("meters.threat", 1, true) and not roles.DPS:find("meters.threat", 1, true), "Tank's preview shows its threat card as a role element; DPS's does not")
	assert(roles.Healer:find("groupframes.party", 1, true), "Healer's preview marks its group frames")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Layout Mode outlines the story slot of the layout last applied, with a hint ------------------------------------

do
	local env, K = Boot()
	assert(K.Setup.Apply({ layout = "Tank", modules = {} }))
	assert(K.Layout.Enter(), "Layout Mode opens")
	W.Settle(env)
	local slot = K.Layout.Mode.Slot()
	assert(slot and slot:IsShown(), "Layout Mode shows the story slot")
	assert(slot.label:GetText() == "Story rail" and slot.hint:GetText():find("RestedXP", 1, true) and slot.hint:GetText():find("Edit Mode", 1, true), "labelled, with a one-line hint")
	local want = K.Setup.Layouts.Slot("Tank")
	local rw, rh = K.Layout.RootSize()
	local l, b, r, t = K.Setup.Layouts.Rect(want, want, rw, rh)
	local got = assert(Geometry.Rect(slot, K.Scale.Root()))
	assert(math.abs(got.left - l) < 1 and math.abs(got.bottom - b) < 1 and math.abs(got.right - r) < 1 and math.abs(got.top - t) < 1, "at the Tank slot")
	assert(not slot:IsMouseEnabled(), "the outline never takes the mouse from the frames the player drops on it")
	local line = assert(Geometry.Rect(slot.raidLine, K.Scale.Root()))
	assert(slot.raidLine:IsShown() and math.abs(line.top - (t - want.raid)) < 1, "a line marks how far the raid frames reach into the slot")
	assert(slot.raidText:GetText():find("raid", 1, true), "and says so")
	K.Layout.Exit(true)
	W.Settle(env)
	-- Healer brings the raid beside the hands: its slot runs from the focus target to chat with no raid line.
	assert(K.Setup.Apply({ layout = "Healer", modules = {} }))
	assert(K.Layout.Enter())
	W.Settle(env)
	want = K.Setup.Layouts.Slot("Healer")
	local _, hb, _, ht = K.Setup.Layouts.Rect(want, want, rw, rh)
	got = assert(Geometry.Rect(slot, K.Scale.Root()))
	assert(math.abs(got.top - ht) < 1 and math.abs(got.bottom - hb) < 1, "Layout Mode follows the Healer slot")
	assert(not slot.raidLine:IsShown() and not slot.raidHelp:IsShown(), "and draws no raid line there")
	K.Layout.Exit(true)
	W.Settle(env)
	assert(not slot:IsShown(), "and hides with Layout Mode")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Layout Mode keeps the story slot's guidance readable (round 4, Astra #2: its title and help sat under a mover plate):
-- the label and the hint stand on their own glass card, and the raid line's text on its own, each shown only while no
-- mover plate covers it, so a plate's label is never written over and the guidance never hides half under a plate.

do
	local env, K = Boot()
	assert(K.Setup.Apply({ layout = "Tank", modules = {} }))
	assert(K.Layout.Enter())
	W.Settle(env)
	local slot = K.Layout.Mode.Slot()
	local root = K.Scale.Root()
	assert(slot.help and slot.help:IsShown() and slot.help.chrome.shapeName == "card", "the guidance stands on a glass card")
	assert(slot.label:GetParent() == slot.help and slot.hint:GetParent() == slot.help, "with the label and the hint on it")
	assert(slot.raidHelp and slot.raidHelp:IsShown() and slot.raidText:GetParent() == slot.raidHelp, "the raid line's text has its own card")
	local help = assert(Geometry.Rect(slot.help, root))
	local frame = K.Widgets.Panel(root, { width = 160, height = 40, shape = "panel" })
	K.Layout.Register(frame, "test.box", { anchor = "BOTTOMLEFT", x = help.left + 10, y = help.bottom + 4 }, { label = "Box" })
	W.Settle(env)
	assert(not slot.help:IsShown(), "a mover plate over the guidance hides it")
	assert(slot:IsShown(), "and the slot's outline stays")
	local raid = assert(Geometry.Rect(slot.raidHelp, root))
	assert(K.Layout.Update("test.box", { anchor = "BOTTOMLEFT", x = raid.left + 10, y = raid.bottom }))
	W.Settle(env)
	assert(slot.help:IsShown(), "moving the plate away shows the guidance again")
	assert(not slot.raidHelp:IsShown(), "and the raid line's text hides under the plate now over it")
	assert(K.Layout.Update("test.box", { anchor = "BOTTOMLEFT", x = 900, y = 600 }))
	W.Settle(env)
	assert(slot.help:IsShown() and slot.raidHelp:IsShown(), "with nothing over the slot both show")
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

-- Each card is the button grade; the preview is a glass panel at the tile chamfer with the shadow --------------

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
	local preview = panel.preview
	local sr, sg, sb = K.Tokens.Color("surface")
	r, g, b = preview.chrome.fill[5]:GetVertexColor()
	assert(W.Near(r, sr) and W.Near(g, sg) and W.Near(b, sb), "the preview is filled surface")
	assert(preview.chrome.shapeName == "tile", "at the tile chamfer")
	assert(preview.chrome.shadow[5]:IsShown(), "with the glass panel's drop shadow")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The summary says what Edit Mode did after Apply. When Edit Mode refuses the layout it says why and offers Try
-- again, one click, never a drag instruction (round 4, Muse #4); when tracked buffs overflow every arrangement, it
-- names the counts and opens the Cooldown Manager.

do
	local EditModeFake = dofile("Tools/regression/editmode_fake.lua")
	local env, K = Boot()
	local panel = Open(env, K)
	K.Setup.Go(4)
	W.Settle(env)
	assert(not panel.editMode:IsShown() and not panel.retry:IsShown(), "before Apply the summary says nothing about Edit Mode")
	assert(panel.summaryPreview:IsShown() and panel.summaryPreview.layout == "DPS", "the summary previews the layout Apply builds")
	W.Click(panel.apply)
	W.Settle(env)
	assert(panel.editMode:IsShown() and panel.editMode:GetText():find("Edit Mode", 1, true), "a refusal is on the summary: " .. tostring(panel.editMode:GetText()))
	assert(not panel.editMode:GetText():find("yourself", 1, true) and not panel.editMode:GetText():find("drag", 1, true), "with no drag instruction")
	assert(panel.retry:IsShown() and panel.retry.label:GetText() == "Try again", "and a Try again button")
	-- Round 5, Opus #4: the heading says a step is left, not a bare "Applied".
	assert(panel.summaryTitle:GetText():lower() == "applied, with one step left", "the heading counts the step left: " .. panel.summaryTitle:GetText())
	local state = { saved = {}, active = 1 }
	EditModeFake.Install(env, state)
	W.Click(panel.retry)
	W.Settle(env)
	assert(state.saves == 1 and EditModeFake.Named(state, "KstyleUI DPS"), "Try again writes the layout")
	assert(not panel.retry:IsShown(), "and the button goes once it took")
	assert(panel.editMode:GetText():find("KstyleUI DPS", 1, true), "the summary names the active layout: " .. panel.editMode:GetText())
	assert(not panel.manager:IsShown(), "no Cooldown Manager button while everything fits")
	assert(panel.summaryTitle:GetText():lower() == "applied", "and with nothing left the heading is Applied")
	K.Setup.EditMode.CountTracked(function(group)
		return ({ buffs = 60, bars = 40 })[group]
	end)
	local opened = 0
	env.CooldownViewerSettings = { ShowUIPanel = function() opened = opened + 1 end }
	K.Setup.RetryEditMode()
	W.Settle(env)
	assert(panel.editMode:GetText():find("60 tracked buffs", 1, true) and panel.editMode:GetText():find("40 tracked bars", 1, true), "the summary names both counts: " .. panel.editMode:GetText())
	assert(panel.manager:IsShown(), "and offers the Cooldown Manager")
	assert(panel.summaryTitle:GetText():lower() == "applied, with 2 steps left", "the heading counts both: " .. panel.summaryTitle:GetText())
	assert(panel.retry:IsShown(), "and Try again, which the lines name, sits beside the Cooldown Manager button")
	local m = panel.manager._points[1]
	assert(m[2] == panel.retry and m[3] == "RIGHT", "the Cooldown Manager button stands right of Try again")
	W.Click(panel.manager)
	assert(opened == 1, "which opens Blizzard's Cooldown Manager settings")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The summary lists what Apply switches off only when something is off, so the Edit Mode notes keep their room at
-- the largest text size (codex review).
do
	local env, K = Boot()
	local panel = Open(env, K)
	K.Setup.Go(4)
	W.Settle(env)
	assert(not panel.summary:GetText():find("Off:", 1, true), "with every module on there is no Off line: " .. panel.summary:GetText())
	K.Setup.Choice().modules.Chat = false
	K.Setup.Go(3)
	K.Setup.Go(4)
	W.Settle(env)
	assert(panel.summary:GetText():find("Off: Chat", 1, true), "a module switched off is listed: " .. panel.summary:GetText())
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- RestedXP's guide (round 5, Muse #5): with Window skins on, the skin puts the guide on the story rail and there is
-- nothing to do; with them off, the summary's checklist asks for the drag, beside Try again, and counts it as a step.
do
	local EditModeFake = dofile("Tools/regression/editmode_fake.lua")
	for _, skins in ipairs({ false, true }) do
		local env, K = Boot({ modules = skins and { "UnitFrames", "Skins" } or MODULES })
		env.C_AddOns.IsAddOnLoaded = function(name)
			return name == "RXPGuides"
		end
		EditModeFake.Install(env, { saved = {}, active = 1 })
		local panel = Open(env, K)
		K.Setup.Go(4)
		W.Settle(env)
		W.Click(panel.apply)
		W.Settle(env)
		local text = panel.editMode:GetText() or ""
		if skins then
			assert(not text:find("RestedXP", 1, true), "with Window skins on, the guide needs no step: " .. text)
			assert(panel.summaryTitle:GetText():lower() == "applied", "and the heading is Applied")
		else
			assert(panel.editMode:IsShown() and text:find("RestedXP", 1, true) and text:find("story rail", 1, true), "with them off, the checklist asks for the drag: " .. text)
			assert(panel.summaryTitle:GetText():lower() == "applied, with one step left", "and counts it: " .. panel.summaryTitle:GetText())
		end
		assert(#env._errors == 0, tostring(env._errors[1]))
	end
end

-- The skin places the guide only while its RestedXP part and story rail are on (codex review): with Window skins
-- picked but either switched off, the drag stays on the checklist.
do
	local EditModeFake = dofile("Tools/regression/editmode_fake.lua")
	for _, field in ipairs({ "enabled", "rail" }) do
		local rxp = { enabled = true, rail = true }
		rxp[field] = false
		local env, K = Boot({
			modules = { "UnitFrames", "Skins" },
			defaults = { Skins = { restedXP = { enabled = true, rail = true } } },
			saved = { version = 2, profiles = { Default = { Skins = { restedXP = rxp } } }, characters = {}, layouts = {}, account = {} },
		})
		env.C_AddOns.IsAddOnLoaded = function(name)
			return name == "RXPGuides"
		end
		EditModeFake.Install(env, { saved = {}, active = 1 })
		local panel = Open(env, K)
		K.Setup.Go(4)
		W.Settle(env)
		W.Click(panel.apply)
		W.Settle(env)
		local text = panel.editMode:GetText() or ""
		assert(text:find("RestedXP", 1, true), "with restedXP." .. field .. " off, the checklist asks for the drag: " .. text)
		assert(panel.summaryTitle:GetText():lower() == "applied, with one step left", "and counts it")
		assert(#env._errors == 0, tostring(env._errors[1]))
	end
end

-- A refusal outlives the window: an Apply made with the window closed (the first-run close, or a write that waited
-- for combat) that Edit Mode refused still shows on the summary when the player reopens setup, with Try again, as
-- the chat line promises. A save that Edit Mode took but did not switch to is a refusal too.
do
	local EditModeFake = dofile("Tools/regression/editmode_fake.lua")
	local env, K = Boot()
	assert(K.Setup.Apply({ layout = "Tank", modules = {} }))
	assert(CoreEnv.Printed(env, "Try again"), "the chat line points at Try again")
	local panel = Open(env, K)
	K.Setup.Go(4)
	W.Settle(env)
	assert(panel.editMode:IsShown() and panel.editMode:GetText():find("KstyleUI Tank", 1, true), "the reopened summary keeps the refusal")
	assert(panel.retry:IsShown(), "with Try again")
	local state = { saved = {}, active = 1 }
	EditModeFake.Install(env, state)
	env.C_EditMode.SetActiveLayout = function()
		error("blocked")
	end
	W.Click(panel.retry)
	W.Settle(env)
	assert(state.saves == 1 and K.Setup.EditMode.Last().state == "failed", "a layout saved but not switched to is not reported as active")
	assert(panel.retry:IsShown() and not panel.editMode:GetText():find("is your active layout", 1, true), "the summary offers Try again instead: " .. panel.editMode:GetText())
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Both previews follow the theme: a restyle repaints their blocks in the new accent.
do
	local env, K = Boot()
	local panel = Open(env, K)
	K.Setup.Go(2)
	W.Settle(env)
	local role
	for _, rect in ipairs(panel.preview.rects) do
		if rect.role and rect:IsShown() then
			role = rect
			break
		end
	end
	local before = W.LastCall(role, "SetColorTexture")
	K.Options.Write("Appearance", "accentSource", "custom")
	K.Options.Write("Appearance", "accentColor", { r = 0, g = 1, b = 0 })
	K.Widgets.RestyleAll()
	local after = W.LastCall(role, "SetColorTexture")
	assert(after and before and after ~= before and W.Near(after[1], 0) and W.Near(after[2], 1), "the preview's role blocks take the new accent")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local EditModeFake = dofile("Tools/regression/editmode_fake.lua")
	local env, K = Boot()
	local state = { saved = {}, active = 1 }
	EditModeFake.Install(env, state)
	local panel = Open(env, K)
	K.Setup.Go(4)
	env.SetCombat(true)
	W.Click(panel.apply)
	W.Settle(env)
	assert(panel.editMode:GetText():find("combat", 1, true), "in combat the summary says the Edit Mode write waits for combat to end")
	env.SetCombat(false)
	W.Settle(env)
	assert(state.saves == 1 and panel.editMode:GetText():find("KstyleUI DPS", 1, true), "and updates when it lands")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("setup ok")
