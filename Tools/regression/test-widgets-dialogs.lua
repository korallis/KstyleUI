-- test-widgets-dialogs.lua: KstyleUI's own popup and confirm dialogs, and the secure reload button.
local W = dofile("Tools/regression/widget_env.lua")

local function overlays(env)
	local out = {}
	for _, frame in ipairs(env._frames) do
		if frame._template == "SecureActionButtonTemplate" then
			out[#out + 1] = frame
		end
	end
	return out
end

-- The reload button: a primary button whose clicks go to one shared secure macro button running /reload.
do
	local env, K = W.New()
	local visual = K.Widgets.ReloadButton(K.Scale.Root(), {})
	assert(visual.label:GetText() == "Reload", "a Reload button")
	assert(visual.primary, "styled as a primary button")
	assert(#overlays(env) == 0, "no secure frame until the pointer arrives")
	W.Enter(visual)
	local secure = overlays(env)
	assert(#secure == 1, "one secure button")
	local overlay = secure[1]
	assert(overlay:GetParent() == env.UIParent, "on UIParent, so no KstyleUI frame becomes protected")
	assert(overlay:GetAttribute("type") == "macro" and overlay:GetAttribute("macrotext") == "/reload", "it runs /reload as a macro")
	assert(overlay:GetAttribute("useOnKeyDown") == false, "on the release of a click")
	assert(W.LastCall(overlay, "RegisterForClicks")[1] == "AnyUp")
	assert(overlay:IsShown() and W.LastCall(overlay, "SetAllPoints")[1] == visual, "it sits over the button the pointer is on")
	W.Enter(overlay)
	W.Settle(env)
	assert(visual.hoverT == 1, "the visual button shows the hover")
	W.Down(overlay)
	W.Settle(env)
	assert(visual.pressT == 1, "and the press")
	W.Up(overlay)
	W.Leave(overlay)
	W.Settle(env)
	assert(overlay:IsShown() == false and visual.hoverT == 0, "leaving hides the secure button")
	local other = K.Widgets.ReloadButton(K.Scale.Root(), { text = "Reload now" })
	W.Enter(other)
	assert(#overlays(env) == 1 and W.LastCall(overlay, "SetAllPoints")[1] == other, "the one secure button serves every reload button")
	other:GetScript("OnHide")(other)
	assert(overlay:IsShown() == false, "it leaves with a hidden button")
	assert(#env._errors == 0)
end

-- Combat: the secure button leaves before lockdown, makes no protected call in combat, and the visual waits.
do
	local env, K = W.New()
	local visual = K.Widgets.ReloadButton(K.Scale.Root(), {})
	W.Enter(visual)
	local overlay = overlays(env)[1]
	local function protectedCalls()
		local n = 0
		for _, call in ipairs(overlay._calls) do
			local m = call.method
			if m == "SetAttribute" or m == "Show" or m == "SetPoint" or m == "SetAllPoints" or m == "ClearAllPoints" or m == "SetFrameStrata" or m == "SetFrameLevel" then
				n = n + 1
			end
		end
		return n
	end
	env.SetCombat(true)
	assert(overlay:IsShown() == false, "combat start hides the secure button before lockdown")
	assert(visual:IsEnabled() == false, "the visual button waits for combat to end")
	local before = protectedCalls()
	W.Enter(visual)
	W.Leave(visual)
	W.Enter(overlay)
	W.Leave(overlay)
	assert(protectedCalls() == before, "no protected call on the secure button in combat")
	env.SetCombat(false)
	assert(visual:IsEnabled() == true, "the button returns after combat")
	W.Enter(visual)
	assert(overlay:IsShown(), "and works again")
	assert(#env._errors == 0)
end

-- A reload button made in combat makes no secure frame until combat ends.
do
	local env, K = W.New()
	env.SetCombat(true)
	local visual = K.Widgets.ReloadButton(K.Scale.Root(), {})
	W.Enter(visual)
	assert(#overlays(env) == 0 and visual:IsEnabled() == false, "nothing secure in combat")
	env.SetCombat(false)
	W.Enter(visual)
	assert(#overlays(env) == 1, "made on the first hover after combat")
end

-- Confirm: a glass dialog with a title, text and Cancel and Accept buttons; never StaticPopupDialogs.
do
	local env, K = W.New({ layout = true })
	local accepted, cancelled = 0, 0
	local handle = K.Widgets.Confirm({
		title = "Disable skins?",
		text = "Blizzard windows keep their skin until you reload.",
		onAccept = function(h)
			accepted = accepted + 1
			assert(h ~= nil)
		end,
		onCancel = function()
			cancelled = cancelled + 1
		end,
	})
	local host = K.Widgets.DialogHost()
	assert(host:IsShown() and handle:IsShown(), "the dialog shows")
	assert(host:GetFrameStrata() == "DIALOG")
	assert(host.titleText:GetText() == "DISABLE SKINS?" and host.body:GetText() == "Blizzard windows keep their skin until you reload.")
	local buttons = host.visibleButtons
	assert(#buttons == 2 and buttons[1].label:GetText() == "Cancel" and buttons[2].label:GetText() == "Accept", "Cancel, then Accept")
	assert(buttons[2].primary and not buttons[1].primary, "Accept is the primary button")
	local reg = env._layout[1]
	assert(reg and reg.frame == host and reg.key == "Widgets.Dialog" and reg.opts.scalable, "the dialog registers with Layout")
	assert(env.StaticPopupDialogs == nil or next(env.StaticPopupDialogs) == nil, "no StaticPopupDialogs entry")
	W.Click(buttons[2])
	assert(accepted == 1 and cancelled == 0, "Accept runs onAccept")
	W.Settle(env)
	assert(host:IsShown() == false and not handle:IsShown(), "and closes")
	K.Widgets.Confirm({ text = "Again?", onCancel = function()
		cancelled = cancelled + 1
	end })
	W.Key(host, "ESCAPE")
	assert(cancelled == 1, "Escape cancels")
	W.Settle(env)
	assert(host:IsShown() == false)
	assert(#env._errors == 0)
end

-- One dialog at a time: a second waits until the first closes; a keyed popup is not queued twice.
do
	local env, K = W.New()
	local first = K.Widgets.Popup({ text = "First", buttons = { { label = "OK" } } })
	local second = K.Widgets.Popup({ text = "Second", key = "second", buttons = { { label = "OK" } } })
	local again = K.Widgets.Popup({ text = "Second again", key = "second" })
	assert(again == second, "a keyed popup that waits is returned, not queued again")
	local host = K.Widgets.DialogHost()
	assert(first:IsShown() and not second:IsShown() and host.body:GetText() == "First", "the first shows, the second waits")
	W.Click(host.visibleButtons[1])
	W.Settle(env)
	assert(second:IsShown() and host.body:GetText() == "Second", "the second shows once the first closes")
	second:Close()
	W.Settle(env)
	assert(host:IsShown() == false, "and the queue empties")
	local waiting = K.Widgets.Popup({ text = "Waiting" })
	local dropped = K.Widgets.Popup({ text = "Dropped" })
	dropped:Close()
	waiting:Close()
	W.Settle(env)
	assert(host:IsShown() == false, "closing a waiting popup drops it")
end

-- A popup with an edit box: Enter presses the primary button, which reads the text.
do
	local env, K = W.New()
	local got
	local handle = K.Widgets.Popup({
		title = "New profile",
		editBox = { placeholder = "Profile name", maxLetters = 48 },
		buttons = {
			{ label = "Cancel" },
			{ label = "Create", primary = true, onClick = function(h)
				got = h:GetText()
			end },
		},
	})
	local host = K.Widgets.DialogHost()
	assert(handle.editBox == host.editBox and host.editBox:IsShown(), "an edit box")
	host.editBox:SetText("Raid")
	host.editBox:GetScript("OnEnterPressed")(host.editBox)
	assert(got == "Raid", "Enter presses the primary button")
	W.Settle(env)
	assert(host:IsShown() == false)
	K.Widgets.Popup({ text = "No box" })
	assert(host.editBox:IsShown() == false, "a popup without one hides it")
end

-- A reload confirm: its accept button is a reload button, so the click reaches the secure /reload macro.
do
	local env, K = W.New()
	K.Widgets.ReloadPrompt("Reload to finish switching modules off.")
	local host = K.Widgets.DialogHost()
	local buttons = host.visibleButtons
	local accept = buttons[#buttons]
	assert(accept.isReload and accept.label:GetText() == "Reload now", "the accept button is a reload button")
	W.Enter(accept)
	local secure = overlays(env)
	assert(#secure == 1 and secure[1]:IsShown() and W.LastCall(secure[1], "SetAllPoints")[1] == accept, "the secure button covers it")
	W.Click(buttons[1])
	W.Settle(env)
	assert(host:IsShown() == false, "Later closes it")
	assert(#env._errors == 0)
end

-- A reload confirm runs onAccept from the secure button's PreClick, before the /reload macro.
do
	local env, K = W.New()
	local order = {}
	K.Widgets.Confirm({ text = "Apply and reload?", reload = true, onAccept = function()
		order[#order + 1] = "accept"
	end })
	local host = K.Widgets.DialogHost()
	local accept = host.visibleButtons[2]
	W.Enter(accept)
	local overlay = overlays(env)[1]
	local pre = overlay:GetScript("PreClick")
	assert(pre, "the secure button has a PreClick")
	pre(overlay, "LeftButton", false)
	assert(order[1] == "accept", "onAccept runs before the macro")
	assert(#env._errors == 0)
end

-- The dialog's edit box keeps the dialog's width through a restyle.
do
	local _, K = W.New()
	K.Widgets.Popup({ editBox = {}, buttons = { { label = "OK", primary = true } } })
	local host = K.Widgets.DialogHost()
	local width = host.editBox:GetWidth()
	assert(width > 300, "the edit box spans the dialog, got " .. tostring(width))
	K.Theme.SetCustomAccent(0.3, 0.6, 0.9)
	K.Theme.SetAccentSource("custom")
	assert(host.editBox:GetWidth() == width, "a restyle keeps that width, got " .. tostring(host.editBox:GetWidth()))
end

-- Enter on one edit-box popup gives focus to the next one, after the first lets go of it.
do
	local env, K = W.New()
	local spec = { { label = "OK", primary = true } }
	K.Widgets.Popup({ editBox = {}, buttons = spec })
	local second = K.Widgets.Popup({ editBox = { text = "two" }, buttons = spec })
	local box = K.Widgets.DialogHost().editBox
	box:GetScript("OnEnterPressed")(box)
	env.RunTimers()
	assert(second:IsShown())
	local last
	for _, call in ipairs(box._calls) do
		if call.method == "SetFocus" or call.method == "ClearFocus" then
			last = call.method
		end
	end
	assert(last == "SetFocus", "the next dialog's box ends with focus, got " .. tostring(last))
end

print("widgets dialogs ok")
