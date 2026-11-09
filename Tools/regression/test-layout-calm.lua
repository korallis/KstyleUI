-- test-layout-calm.lua: combat calm. In combat the slow cards rest at 30% and the focus cards stay lit; a hover wakes a calmed card; out of combat the cards return after a delay. Alpha only, one owner per frame, with a setting.
local W = dofile("Tools/regression/widget_env.lua")
local CoreEnv = W.CoreEnv

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (eps or 1e-3)
end

local SLOW = { "chat.main", "minimap.main", "databars.strip", "databars.micro", "databars.bags", "databars.xp", "databars.rep", "databars.honor" }
local FOCUS = {
	"groupframes.party", "groupframes.raid", "unitframes.boss", "unitframes.target", "unitframes.player", "unitframes.castbar.player",
	"unitframes.castbar.target", "actionbars.bar1", "cooldowns.essential", "cooldowns.utility", "auras.buffs", "auras.debuffs",
	"meters.damage", "meters.threat",
}

-- New(setup) -> env, K, frames: the core with one frame registered under each slow and focus key.
local function New(setup)
	local env, K = W.New({ setup = setup })
	local frames = {}
	for _, list in ipairs({ SLOW, FOCUS }) do
		for i, key in ipairs(list) do
			local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
			frame:SetSize(100, 40)
			K.Layout.Register(frame, key, { anchor = "BOTTOMLEFT", x = 10 + i * 110, y = list == SLOW and 10 or 200 }, { label = key })
			frames[key] = frame
		end
	end
	W.Settle(env)
	return env, K, frames
end

-- Wait(env, seconds) runs every OnUpdate for that long in 16 ms frames.
local function Wait(env, seconds)
	local steps = math.floor(seconds / 0.016 + 0.5)
	for _ = 1, steps do
		W.Tick(env, 0.016)
	end
end

local function Poll(env)
	env.RunTickers()
	W.Settle(env)
end

-- The calm set and the focus set ----------------------------------------------------------------------------

do
	local env, K = New()
	local Calm = K.Layout.Calm
	assert(type(Calm) == "table", "KstyleUI.Layout.Calm is missing")
	assert(Calm.ALPHA == 0.3 and Calm.FALL == 0.24 and Calm.RISE == 0.6 and Calm.DELAY == 3, "30% over 0.24 s; back over 0.6 s after 3 s")
	local cards = {}
	for _, key in ipairs(Calm.CARDS) do
		cards[key] = true
		assert(K.Setup.Layouts.Element(key), key .. " is an element key")
	end
	for _, key in ipairs(SLOW) do
		assert(cards[key], key .. " is a slow card")
	end
	for _, key in ipairs(FOCUS) do
		assert(not cards[key], key .. " is a focus card and never calms")
	end
	assert(K.Layout.Setting("calm") == true, "Calm the rails in combat is on by default")
	local row
	for _, r in ipairs(K.Layout.schema) do
		if r.key == "calm" then
			row = r
		end
	end
	assert(row and row.type == "toggle" and row.label == "Calm the rails in combat", "Layout's settings page has the switch")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Combat: the slow cards fall to 30% over 0.24 s, the focus cards stay at 100%, nothing moves ------------------

do
	local env, K, frames = New()
	local rects = {}
	for key in pairs(frames) do
		rects[key] = { K.Layout.Rect(key) }
	end
	env.SetCombat(true)
	Wait(env, 0.12)
	local chat = frames["chat.main"]:GetAlpha()
	assert(chat < 1 and chat > 0.3, "half way through the fall the chat is between 100% and 30%, got " .. chat)
	Wait(env, 0.16)
	for _, key in ipairs(SLOW) do
		assert(near(frames[key]:GetAlpha(), 0.3), key .. " rests at 30% in combat, got " .. frames[key]:GetAlpha())
	end
	for _, key in ipairs(FOCUS) do
		assert(frames[key]:GetAlpha() == 1, key .. " stays at 100% in combat")
	end
	for key in pairs(frames) do
		local r = { K.Layout.Rect(key) }
		for i = 1, 4 do
			assert(r[i] == rects[key][i], key .. " keeps its place and size: calm is alpha only")
		end
		assert(K.Layout.Get(key).alphaCombat == 1, key .. ": calm never writes the player's opacity")
	end
	assert(K.Layout.Calm.Active(), "the rails are calm")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Hover: a calmed card wakes while the pointer is on it ---------------------------------------------------------

do
	local env, _, frames = New()
	env.SetCombat(true)
	W.Settle(env)
	local chat = frames["chat.main"]
	chat._mouseOver = true
	Poll(env)
	assert(near(chat:GetAlpha(), 1), "the pointer on the chat wakes it")
	assert(near(frames["minimap.main"]:GetAlpha(), 0.3), "the other cards stay calm")
	chat._mouseOver = false
	Poll(env)
	assert(near(chat:GetAlpha(), 0.3), "the chat calms again once the pointer leaves")
	env.SetCombat(false)
	Wait(env, 4)
	W.Settle(env)
	assert(env.LiveTickers() == 0, "the hover poll stops with the calm")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Leaving combat: the cards wait 3 s, then rise over 0.6 s; a new pull during the wait keeps them calm ---------

do
	local env, K, frames = New()
	local chat = frames["chat.main"]
	env.SetCombat(true)
	W.Settle(env)
	env.SetCombat(false)
	Wait(env, 2.9)
	assert(near(chat:GetAlpha(), 0.3), "the chat stays calm for 3 s after combat")
	Wait(env, 0.4)
	local rising = chat:GetAlpha()
	assert(rising > 0.3 and rising < 1, "then it rises, got " .. rising)
	Wait(env, 0.6)
	assert(near(chat:GetAlpha(), 1), "and is back at 100% 0.6 s later")
	assert(not K.Layout.Calm.Active())

	env.SetCombat(true)
	W.Settle(env)
	env.SetCombat(false)
	Wait(env, 2)
	env.SetCombat(true)
	Wait(env, 2)
	assert(near(chat:GetAlpha(), 0.3), "a pull during the wait keeps the chat calm")
	env.SetCombat(false)
	Wait(env, 1.5)
	assert(near(chat:GetAlpha(), 0.3), "and the wait starts again when that pull ends")
	W.Settle(env)
	assert(near(chat:GetAlpha(), 1))
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Reduced motion: the calm is instant ----------------------------------------------------------------------------

do
	local env, K, frames = New()
	K.Motion.SetLevel("reduced")
	env.SetCombat(true)
	assert(near(frames["chat.main"]:GetAlpha(), 0.3), "with reduced motion the chat calms at once")
	env.SetCombat(false)
	Wait(env, 3.05)
	assert(near(frames["chat.main"]:GetAlpha(), 1), "and returns at once after the wait")
end

-- The setting: off, nothing calms; turned off in combat, the cards return ----------------------------------------

do
	local env, K, frames = New()
	K.Options.Write("Layout", "calm", false)
	env.SetCombat(true)
	W.Settle(env)
	assert(frames["chat.main"]:GetAlpha() == 1, "with the setting off the chat stays at 100% in combat")
	K.Options.Write("Layout", "calm", true)
	W.Settle(env)
	assert(near(frames["chat.main"]:GetAlpha(), 0.3), "turned on in combat, the rails calm")
	K.Options.Write("Layout", "calm", false)
	W.Settle(env)
	assert(near(frames["chat.main"]:GetAlpha(), 1), "turned off in combat, the rails return")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- One owner per frame: the player's own opacity or mouseover rule wins over the calm -------------------------------

do
	local env, K, frames = New()
	assert(K.Layout.Set("chat.main", "alphaCombat", 0.8))
	assert(K.Layout.Set("minimap.main", "shown", "mouseover"))
	W.Settle(env)
	env.SetCombat(true)
	W.Settle(env)
	assert(near(frames["chat.main"]:GetAlpha(), 0.8), "the chat keeps the player's 80% combat opacity, got " .. frames["chat.main"]:GetAlpha())
	assert(frames["minimap.main"]:GetAlpha() == 0, "the minimap keeps the player's mouseover rule")
	assert(near(frames["databars.xp"]:GetAlpha(), 0.3), "a card at its defaults calms")
	assert(K.Layout.Set("chat.main", "alphaCombat", 1))
	W.Settle(env)
	assert(near(frames["chat.main"]:GetAlpha(), 0.3), "an opacity put back at 100% hands the chat back to the calm")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The guide and quest skins: calmed while Skins runs, never fought over -------------------------------------------

do
	local env, K = W.New({
		setup = function(env)
			env.CreateFrame("Frame", "ObjectiveTrackerFrame", env.UIParent)
			env.CreateFrame("Frame", "RXPFrame", env.UIParent)
		end,
	})
	K.Modules.Register(CoreEnv.Module("Skins"))
	K.Modules.Enable("Skins")
	env.RunTimers()
	assert(K.Modules.IsRunning("Skins"))
	local tracker, guide = env.ObjectiveTrackerFrame, env.RXPFrame
	env.SetCombat(true)
	W.Settle(env)
	assert(near(tracker:GetAlpha(), 0.3) and near(guide:GetAlpha(), 0.3), "the tracker and the guide calm with the rails")
	tracker._mouseOver = true
	Poll(env)
	assert(near(tracker:GetAlpha(), 1), "the pointer wakes the tracker")
	tracker._mouseOver = false
	Poll(env)
	assert(near(tracker:GetAlpha(), 0.3))
	guide:SetAlpha(0.7)
	env.SetCombat(false)
	Wait(env, 4)
	W.Settle(env)
	assert(near(tracker:GetAlpha(), 1), "the tracker returns after combat")
	assert(near(guide:GetAlpha(), 0.7), "a guide another owner faded in the meantime is left as that owner set it")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local env, K = W.New({
		setup = function(env)
			env.CreateFrame("Frame", "ObjectiveTrackerFrame", env.UIParent)
		end,
	})
	local tracker = env.ObjectiveTrackerFrame
	env.SetCombat(true)
	W.Settle(env)
	assert(tracker:GetAlpha() == 1, "without the Skins module the tracker is Blizzard's and stays as it is")
	env.SetCombat(false)
	K.Modules.Register(CoreEnv.Module("Skins"))
	K.Modules.Enable("Skins")
	env.RunTimers()
	assert(K.Modules.IsRunning("Skins"))
	tracker:SetAlpha(0.5)
	env.SetCombat(true)
	W.Settle(env)
	assert(near(tracker:GetAlpha(), 0.5), "a tracker another owner already faded is not calmed")
	env.SetCombat(false)
	Wait(env, 4)
	W.Settle(env)
	assert(near(tracker:GetAlpha(), 0.5), "nor touched when the calm ends")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A pull during the rise: the calm keeps the surfaces it is bringing back, and fades them again ----------------------

do
	local env, K = W.New({
		setup = function(env)
			env.CreateFrame("Frame", "ObjectiveTrackerFrame", env.UIParent)
		end,
	})
	K.Modules.Register(CoreEnv.Module("Skins"))
	K.Modules.Enable("Skins")
	env.RunTimers()
	local tracker = env.ObjectiveTrackerFrame
	env.SetCombat(true)
	W.Settle(env)
	env.SetCombat(false)
	Wait(env, 3.2)
	local rising = tracker:GetAlpha()
	assert(rising > 0.3 and rising < 1, "the tracker is rising, got " .. rising)
	env.SetCombat(true)
	Wait(env, 0.5)
	assert(near(tracker:GetAlpha(), 0.3), "a pull mid-rise fades the tracker again, got " .. tracker:GetAlpha())
	env.SetCombat(false)
	Wait(env, 4)
	assert(near(tracker:GetAlpha(), 1), "and it returns after that pull")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("layout calm ok")
