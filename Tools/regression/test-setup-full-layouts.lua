-- test-setup-full-layouts.lua: when Edit Mode refuses setup because every account layout is in use, the summary keeps Replace this one and Apply, and the pick writes the KstyleUI layout over only that layout with no second backup.
local W = dofile("Tools/regression/widget_env.lua")
local Fake = dofile("Tools/regression/editmode_fake.lua")

-- A player's setup run reported on 2026-11-28: all five account layouts in use, Apply pressed with nothing picked,
-- and a summary that said "Choose Replace this one, then Apply" while it showed neither control.
local function FullSetup(replaceSetting, names)
	local env, K = W.New()
	local saved = {}
	for i = 1, 5 do saved[i] = { layoutName = names and names[i] or ("Mine " .. i), layoutType = Fake.ACCOUNT, systems = Fake.Modern().systems } end
	local state = { saved = saved, active = 3, max = 5 }
	Fake.Install(env, state)
	K.Options.Write("Setup", "replaceLayout", replaceSetting)
	K.Setup.Open()
	W.Settle(env)
	K.Setup.Go(5)
	W.Settle(env)
	return env, K, state, K.Setup.window
end

local function Visible(frame) return frame:IsVisible() == true end

local function Refuse(env, K, panel)
	assert(Visible(panel.replace) and Visible(panel.apply), "before Apply the summary offers Replace this one and Apply")
	W.Click(panel.apply)
	W.Settle(env)
	assert(K.Setup.EditMode.Last().state == "failed", "Apply with nothing picked keeps every account layout")
	assert(panel.editMode:GetText():find("Choose Replace this one, then Apply", 1, true), "the refusal names Replace this one and Apply")
	assert(Visible(panel.replace) and Visible(panel.apply), "after the refusal the summary still shows Replace this one and Apply, as the refusal asks")
	assert(not Visible(panel.reload) and not Visible(panel.later), "Apply takes Reload's place while the refusal waits for a pick")
end

-- Picks through the open menu, as a player does, so a broken dropdown click or menu row fails here too.
local function Pick(env, K, panel, name)
	W.Click(panel.replace)
	W.Settle(env)
	local menu = K.Widgets.DropdownMenu()
	assert(panel.replace:IsOpen() and menu:IsVisible(), "clicking Replace this one opens its menu")
	for _, row in ipairs(menu.list.rows) do
		if row:IsVisible() and row.label:GetText() == name then
			W.Click(row)
			W.Settle(env)
			assert(panel.replace:GetValue() == name and not panel.replace:IsOpen(), "the menu row picks " .. name)
			return
		end
	end
	error("the Replace this one menu lists no " .. name)
end

local function Replaced(state)
	assert(Fake.Named(state, "KstyleUI DPS") and not Fake.Named(state, "Mine 2"), "the KstyleUI layout replaces the picked layout")
	for _, name in ipairs({ "Mine 1", "Mine 3", "Mine 4", "Mine 5" }) do
		assert(Fake.Named(state, name), name .. " is kept")
	end
end

local function Finished(env, K, panel)
	assert(K.Setup.EditMode.Last().state == "written", "Edit Mode takes the KstyleUI layout once a layout is picked")
	assert(Visible(panel.reload) and Visible(panel.later), "the summary offers Reload and Later once Edit Mode took the layout")
	assert(not Visible(panel.apply) and not Visible(panel.replace), "Apply and Replace this one go once Edit Mode took the layout")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local env, K, state, panel = FullSetup(true)
	Refuse(env, K, panel)
	local profiles = #K.Store.ListProfiles()
	W.Click(panel.retry)
	W.Settle(env)
	assert(K.Setup.EditMode.Last().state == "failed" and not state.saves, "Try again with nothing picked still keeps every account layout")
	assert(Visible(panel.replace) and Visible(panel.apply), "Try again with nothing picked keeps Replace this one and Apply")
	local title = panel.summaryTitle:GetText()
	Pick(env, K, panel, "Mine 2")
	assert(panel.summaryTitle:GetText() == title, "picking a layout keeps the summary applied, so Apply writes only Edit Mode")
	assert(Visible(panel.apply), "Apply stays after the pick")
	W.Click(panel.apply)
	W.Settle(env)
	assert(state.saves == 1, "Apply after the pick saves Edit Mode once")
	Replaced(state)
	assert(#K.Store.ListProfiles() == profiles, "Apply after the refusal makes no second setup backup")
	Finished(env, K, panel)
end

do
	local env, K, state, panel = FullSetup(true)
	Refuse(env, K, panel)
	Pick(env, K, panel, "Mine 2")
	W.Click(panel.retry)
	W.Settle(env)
	Replaced(state)
	Finished(env, K, panel)
end

do
	local env, K, state, panel = FullSetup(false)
	assert(not Visible(panel.replace), "with Choose an Edit Mode replacement off, setup offers no replacement")
	W.Click(panel.apply)
	W.Settle(env)
	assert(K.Setup.EditMode.Last().state == "failed" and not state.saves, "with the replacement off, five full layouts are kept")
	assert(panel.editMode:GetText():find("Delete one in Edit Mode", 1, true), "with the replacement off, the summary keeps the earlier refusal")
	assert(not Visible(panel.replace) and not Visible(panel.apply), "with the replacement off, the summary offers no replacement after the refusal")
	assert(Visible(panel.reload) and Visible(panel.later), "with the replacement off, Reload and Later show after Apply")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A failure that is not the full-list refusal keeps the usual Reload and Later, even with every slot in use: here
-- KstyleUI DPS already has its slot, so Edit Mode needs no replacement, and only the save fails.
do
	local env, K, state, panel = FullSetup(true, { "Mine 1", "Mine 2", "KstyleUI DPS", "Mine 4", "Mine 5" })
	env.C_EditMode.SaveLayouts = function() error("save refused") end
	W.Click(panel.apply)
	W.Settle(env)
	assert(K.Setup.EditMode.Last().state == "failed" and not K.Setup.EditMode.Last().full, "a failed save is not the full-list refusal")
	assert(Visible(panel.retry) and Visible(panel.reload) and Visible(panel.later), "a failed save keeps Try again, Reload and Later")
	assert(not Visible(panel.apply) and not Visible(panel.replace), "a failed save offers no replacement")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("setup full layouts ok")
