-- test-icons.lua: the Icons service maps icon file IDs to the active custom set, tints set A and loads the data addons on demand.
local W = dofile("Tools/regression/widget_env.lua")
local CoreEnv = W.CoreEnv

local FIRE, NATURE, FROST, ARCANE, FROSTFIRE, PHYSICAL = 4, 8, 16, 64, 20, 1
local FIREBALL, REJUV, PLAIN, UNKNOWN = 135812, 136081, 132147, 999999
local A_PATH = "Interface\\AddOns\\KstyleUI_Icons\\Icons\\"
local B_PATH = "Interface\\AddOns\\KstyleUI_IconsColour\\Icons\\"

local DATA = {
	KstyleUI_Icons = {
		set = "A",
		icons = { [FIREBALL] = A_PATH .. FIREBALL .. ".png", [REJUV] = A_PATH .. REJUV .. ".png", [PLAIN] = A_PATH .. PLAIN .. ".png" },
		schools = { [FIREBALL] = FIRE, [REJUV] = NATURE },
	},
	KstyleUI_IconsColour = {
		set = "B",
		icons = { [FIREBALL] = B_PATH .. FIREBALL .. ".png" },
		schools = { [FIREBALL] = FIRE },
	},
}

-- A C_AddOns stand-in: LoadAddOn runs a data addon once, which sets the shared global, as the game would.
-- opts.data replaces an addon's table (false: the addon defines nothing); opts.fail makes LoadAddOn fail.
local function AddOns(env, opts)
	opts = opts or {}
	env._loads, env._loaded = {}, {}
	env.C_AddOns = {
		LoadAddOn = function(name)
			env._loads[#env._loads + 1] = name
			if opts.fail and opts.fail[name] then
				return false, opts.fail[name]
			end
			if not env._loaded[name] then
				env._loaded[name] = true
				local data = DATA[name]
				if opts.data and opts.data[name] ~= nil then
					data = opts.data[name]
				end
				if data then
					env.KstyleUIIconData = CoreEnv.DeepCopy(data)
				end
			end
			return true
		end,
		IsAddOnLoaded = function(name)
			local loaded = env._loaded[name] == true
			return loaded, loaded
		end,
	}
end

local function New(opts)
	opts = opts or {}
	return W.New({
		saved = opts.saved,
		setup = function(env)
			if opts.noAddOns then
				env.C_AddOns = nil
			else
				AddOns(env, opts)
			end
		end,
	})
end

local function Count(K)
	local counter = { n = 0 }
	K.Callbacks.Register("IconsChanged", counter, function(self)
		self.n = self.n + 1
	end)
	return counter
end

local function Logged(env, text)
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		if entry.module == "Icons" and entry.message:find(text, 1, true) then
			return entry.message
		end
	end
end

local function Texture(K)
	return K.Scale.Root():CreateTexture(nil, "ARTWORK", nil, 1)
end

local function Highlight(env, texture)
	for _, region in ipairs({ texture:GetParent():GetRegions() }) do
		if region ~= texture and W.LastCall(region, "SetBlendMode") and W.LastCall(region, "SetBlendMode")[1] == "ADD" then
			if W.LastCall(region, "SetAllPoints") and W.LastCall(region, "SetAllPoints")[1] == texture then
				return region
			end
		end
	end
end

local function Is(texture, r, g, b)
	return W.SameRGB(texture, r, g, b)
end

-- Settings: the Icons module's defaults and its settings page ------------------------------------

do
	local env, K = New()
	local defaults = K.Store.Defaults("Icons")
	assert(defaults.enabled == false and defaults.set == "A" and defaults.tint == "class" and defaults.highlight == 0.25, "defaults: off, set A, class tint, highlight 0.25")
	local schema = K.Options.Get("Icons")
	assert(schema, "the Icons page is registered with Options")
	local keys = {}
	for _, row in ipairs(schema) do
		if row.key then
			keys[row.key] = row
		end
	end
	assert(keys.enabled and keys.enabled.type == "toggle", "a toggle switches custom icons on")
	assert(keys.set and keys.set.type == "dropdown", "a dropdown picks set A or B")
	assert(keys.tint and keys.tint.type == "dropdown", "a dropdown picks the tint")
	assert(keys.highlight and keys.highlight.type == "slider", "a slider sets the highlight strength")
	assert(keys.tint.showWhen({ set = "A" }) == true and keys.tint.showWhen({ set = "B" }) == false, "the tint applies to set A only")
	local values = {}
	for _, option in ipairs(keys.tint.options) do
		values[option.value] = true
	end
	assert(values.class and values.school and values.white, "tints: class colour, school colour and white")
	local found = false
	for _, name in ipairs(K.Modules.List()) do
		found = found or name == "Icons"
	end
	assert(found, "Icons runs as the Icons module, so DevTest and the settings window see its switch")
	assert(#env._loads == 0, "nothing loads while custom icons are off")
	assert(#env._errors == 0)
end

-- Off: Blizzard's icons, no data addon, no tint ----------------------------------------------------

do
	local env, K = New()
	assert(K.Icons.Resolve(FIREBALL) == nil, "off: Resolve gives nil")
	local texture = Texture(K)
	local custom = K.Icons.Apply(texture, FIREBALL, FIRE)
	assert(custom == false, "off: Apply reports Blizzard's icon")
	assert(W.LastCall(texture, "SetTexture")[1] == FIREBALL, "off: Apply shows the game's icon")
	assert(Is(texture, 1, 1, 1), "off: no tint")
	assert(Highlight(env, texture) == nil, "off: no highlight copy")
	assert(K.Icons.ActiveSet() == nil)
	assert(#env._loads == 0)
end

-- On with set A: loads KstyleUI_Icons, resolves, tints by class colour with an additive highlight -----

do
	local env, K = New()
	local changed = Count(K)
	K.Options.Write("Icons", "enabled", true)
	assert(env._loads[1] == "KstyleUI_Icons" and #env._loads == 1, "turning icons on loads set A's addon once")
	assert(K.Icons.ActiveSet() == "A")
	assert(changed.n >= 1, "turning icons on fires IconsChanged")
	assert(Logged(env, "set A"), "the load path goes to the devlog")
	assert(K.Icons.Resolve(FIREBALL) == A_PATH .. FIREBALL .. ".png", "Resolve maps a file ID to set A's texture")
	assert(K.Icons.Resolve(UNKNOWN) == nil, "a file ID the set lacks gives nil")
	assert(K.Icons.Resolve("Interface\\Icons\\Spell_Fire_Fireball") == nil, "a path is not a file ID")
	assert(K.Icons.Resolve(nil) == nil)
	assert(K.Icons.Resolve(env.Secret(FIREBALL)) == nil, "a secret file ID is never used as a key")

	local texture = Texture(K)
	assert(K.Icons.Apply(texture, FIREBALL) == true, "Apply reports a custom icon")
	assert(W.LastCall(texture, "SetTexture")[1] == A_PATH .. FIREBALL .. ".png")
	local ar, ag, ab = K.Theme.Accent()
	assert(Is(texture, ar, ag, ab), "set A is tinted in the class colour by default")
	local glow = Highlight(env, texture)
	assert(glow, "set A gets an additive copy for bright highlights")
	assert(W.LastCall(glow, "SetTexture")[1] == A_PATH .. FIREBALL .. ".png", "the copy shows the same art")
	assert(W.SameColor(glow, 1, 1, 1, 0.25), "the copy is white at the highlight strength")
	assert(glow:IsShown(), "the copy shows")
	local layer, sublevel = glow:GetDrawLayer()
	assert(layer == "ARTWORK" and sublevel == 2, "the copy draws just above the icon")

	-- The copy follows the icon's visibility.
	texture:Hide()
	assert(not glow:IsShown(), "hiding the icon hides its highlight")
	texture:Show()
	assert(glow:IsShown(), "showing the icon shows its highlight")
	texture:SetShown(false)
	assert(not glow:IsShown())
	texture:SetShown(true)

	-- Apply to the same texture reuses the copy.
	K.Icons.Apply(texture, REJUV)
	assert(Highlight(env, texture) == glow and W.LastCall(glow, "SetTexture")[1] == A_PATH .. REJUV .. ".png", "one copy per texture")

	-- An unknown file ID falls back to the game's icon with no tint.
	assert(K.Icons.Apply(texture, UNKNOWN) == false)
	assert(W.LastCall(texture, "SetTexture")[1] == UNKNOWN and Is(texture, 1, 1, 1) and not glow:IsShown(), "a missing icon shows the game's art untinted")

	-- A secret file ID passes to SetTexture untouched.
	local secret = env.Secret(FIREBALL)
	assert(K.Icons.Apply(texture, secret) == false)
	assert(W.LastCall(texture, "SetTexture")[1] == secret, "a secret file ID reaches the engine untouched")
	assert(#env._errors == 0)
end

-- Tints: school colour from the caller or the data, and white ---------------------------------------

do
	local env, K = New()
	K.Options.Write("Icons", "enabled", true)
	K.Options.Write("Icons", "tint", "school")
	local texture = Texture(K)
	K.Icons.Apply(texture, FIREBALL)
	local fr, fg, fb = K.Tokens.Color("schoolFire")
	assert(Is(texture, fr, fg, fb), "the school comes from the data table")
	K.Icons.Apply(texture, FIREBALL, FROST)
	local cr, cg, cb = K.Tokens.Color("schoolFrost")
	assert(Is(texture, cr, cg, cb), "the caller's school wins")
	K.Icons.Apply(texture, FIREBALL, FROSTFIRE)
	assert(Is(texture, fr, fg, fb), "a mixed school takes its first magic school")
	K.Icons.Apply(texture, FIREBALL, ARCANE + PHYSICAL)
	local xr, xg, xb = K.Tokens.Color("schoolArcane")
	assert(Is(texture, xr, xg, xb), "physical yields to a magic school")
	K.Icons.Apply(texture, FIREBALL, PHYSICAL)
	local pr, pg, pb = K.Tokens.Color("schoolPhysical")
	assert(Is(texture, pr, pg, pb))
	K.Icons.Apply(texture, PLAIN)
	local ar, ag, ab = K.Theme.Accent()
	assert(Is(texture, ar, ag, ab), "no school falls back to the class colour")
	K.Icons.Apply(texture, FIREBALL, env.Secret(FROST))
	assert(Is(texture, fr, fg, fb), "a secret school is ignored")
	assert(select(1, K.Icons.SchoolColor(NATURE)) == select(1, K.Tokens.Color("schoolNature")))

	local changed = Count(K)
	K.Options.Write("Icons", "tint", "white")
	assert(changed.n == 1, "a tint change fires IconsChanged")
	assert(Is(texture, 1, 1, 1), "a tint change repaints applied icons at once")
	K.Options.Write("Icons", "highlight", 0.5)
	assert(changed.n == 2, "a highlight change fires IconsChanged")
	assert(W.SameColor(Highlight(env, texture), 1, 1, 1, 0.5), "and repaints the copy")
	K.Options.Write("Icons", "highlight", 0)
	assert(not Highlight(env, texture):IsShown(), "a highlight of 0 hides the copy")
	assert(#env._errors == 0)
end

-- The class colour follows ThemeChanged --------------------------------------------------------------

do
	local _, K = New()
	K.Options.Write("Icons", "enabled", true)
	local texture = Texture(K)
	K.Icons.Apply(texture, FIREBALL)
	K.Theme.SetCustomAccent(0.2, 0.4, 0.6)
	K.Theme.SetAccentSource("custom")
	assert(Is(texture, 0.2, 0.4, 0.6), "a new accent retints set A icons")
	K.Options.Write("Icons", "tint", "school")
	local plain = Texture(K)
	K.Icons.Apply(plain, PLAIN)
	K.Theme.SetCustomAccent(0.6, 0.4, 0.2)
	assert(Is(plain, 0.6, 0.4, 0.2), "in school mode, an icon with no school follows the accent too")
end

-- The highlight copy keeps the icon's crop when the same art is applied again ------------------------

do
	local env, K = New()
	K.Options.Write("Icons", "enabled", true)
	local texture = Texture(K)
	texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	K.Icons.Apply(texture, FIREBALL)
	local glow = Highlight(env, texture)
	assert(select(1, glow:GetTexCoord()) == 0.07, "the copy takes the icon's crop")
	texture:SetTexCoord(0.1, 0.9, 0.1, 0.9)
	K.Icons.Apply(texture, FIREBALL)
	assert(select(1, glow:GetTexCoord()) == 0.1, "re-applying the same art copies the new crop")
end

-- Set B: full colour, no tint, no highlight; switching sets loads the other addon ---------------------

do
	local env, K = New()
	K.Options.Write("Icons", "enabled", true)
	local texture = Texture(K)
	K.Icons.Apply(texture, FIREBALL)
	local changed = Count(K)
	K.Options.Write("Icons", "set", "B")
	assert(env._loads[2] == "KstyleUI_IconsColour", "set B loads its own addon")
	assert(changed.n == 1, "a set change fires IconsChanged")
	assert(K.Icons.ActiveSet() == "B")
	assert(K.Icons.Resolve(FIREBALL) == B_PATH .. FIREBALL .. ".png")
	assert(K.Icons.Resolve(REJUV) == nil, "only set B's table is used")
	K.Icons.Apply(texture, FIREBALL)
	assert(Is(texture, 1, 1, 1), "set B is never tinted")
	assert(not Highlight(env, texture):IsShown(), "set B has no highlight copy")
	K.Options.Write("Icons", "set", "A")
	assert(#env._loads == 2, "set A's table is kept, so switching back loads nothing")
	assert(K.Icons.Resolve(REJUV) == A_PATH .. REJUV .. ".png")
	K.Options.Write("Icons", "enabled", false)
	assert(changed.n == 3, "turning icons off fires IconsChanged")
	assert(K.Icons.Resolve(FIREBALL) == nil and K.Icons.ActiveSet() == nil)
	assert(#env._errors == 0)
end

-- Faults: a failed load, missing data, the wrong set, no C_AddOns ----------------------------------

do
	local env, K = New({ fail = { KstyleUI_Icons = "MISSING" } })
	K.Options.Write("Icons", "enabled", true)
	assert(K.Icons.Resolve(FIREBALL) == nil and K.Icons.ActiveSet() == nil, "a failed load keeps Blizzard's icons")
	assert(Logged(env, "MISSING"), "the reason goes to the devlog")
	local texture = Texture(K)
	assert(K.Icons.Apply(texture, FIREBALL) == false and W.LastCall(texture, "SetTexture")[1] == FIREBALL)
	assert(#env._errors == 0)
end

do
	local env, K = New({ data = { KstyleUI_Icons = false } })
	K.Options.Write("Icons", "enabled", true)
	assert(K.Icons.ActiveSet() == nil and Logged(env, "KstyleUIIconData"), "an addon that defines no data is logged")
end

do
	local env, K = New({ data = { KstyleUI_Icons = { set = "B", icons = { [FIREBALL] = "x" } } } })
	K.Options.Write("Icons", "enabled", true)
	assert(K.Icons.Resolve(FIREBALL) == nil, "data for the other set is not used")
	assert(Logged(env, "KstyleUIIconData"))
end

do
	local env, K = New({ data = { KstyleUI_Icons = { set = "A", icons = { [FIREBALL] = 7, [REJUV] = A_PATH .. "r.png" } } } })
	K.Options.Write("Icons", "enabled", true)
	assert(K.Icons.Resolve(FIREBALL) == nil, "an entry that is not a path is ignored")
	assert(K.Icons.Resolve(REJUV) == A_PATH .. "r.png", "schools are optional")
	assert(#env._errors == 0)
end

do
	local env, K = New({ noAddOns = true })
	K.Options.Write("Icons", "enabled", true)
	assert(K.Icons.Resolve(FIREBALL) == nil and Logged(env, "C_AddOns"), "a client without C_AddOns.LoadAddOn keeps Blizzard's icons")
	assert(#env._errors == 0)
end

-- Saved switch: icons on at login load the set before modules build their frames --------------------

do
	local saved = { version = 1, profiles = { Default = { Icons = { enabled = true, set = "B" } } } }
	local env, K = New({ saved = saved })
	assert(env._loads[1] == "KstyleUI_IconsColour" and K.Icons.ActiveSet() == "B", "a saved switch loads the saved set at login")
	assert(K.Modules.IsRunning("Icons"))
	K.Store.CreateProfile("Plain")
	local changed = Count(K)
	K.Store.SetProfile("Plain")
	assert(K.Icons.ActiveSet() == nil and changed.n == 1, "a profile with icons off turns them off")
	assert(#env._errors == 0)
end

-- Shade: widgets dim and desaturate icons without losing the tint ------------------------------------

do
	local env, K = New()
	K.Options.Write("Icons", "enabled", true)
	local plain = Texture(K)
	K.Icons.Shade(plain, 0.5, 0.5, 0.5, true)
	assert(Is(plain, 0.5, 0.5, 0.5) and W.LastCall(plain, "SetDesaturated")[1] == true, "a texture Apply never saw is shaded as given")

	local button = K.Widgets.IconButton(K.Scale.Root(), {})
	K.Icons.Apply(button.icon, FIREBALL)
	local ar, ag, ab = K.Theme.Accent()
	assert(Is(button.icon, ar, ag, ab), "an icon button shows the tint")
	W.Enter(button)
	W.Settle(env)
	assert(Is(button.icon, ar, ag, ab), "hover keeps the tint")
	W.Down(button)
	W.Settle(env)
	assert(Is(button.icon, ar * 0.75, ag * 0.75, ab * 0.75), "press dims the tinted icon")
	W.Up(button)
	W.Settle(env)
	button:SetUsable(false)
	assert(W.LastCall(button.icon, "SetDesaturated")[1] == true, "an unusable icon is desaturated")
	assert(Is(button.icon, ar * 0.55, ag * 0.55, ab * 0.55), "and dimmed with its tint")
	local glow = Highlight(env, button.icon)
	assert(W.LastCall(glow, "SetDesaturated")[1] == true, "the highlight copy follows the desaturation")
	assert(W.SameColor(glow, 0.55, 0.55, 0.55, 0.25), "and the dimming")
	button:SetUsable(true)
	button:SetIcon(136243)
	assert(Is(button.icon, 1, 1, 1) and not glow:IsShown(), "SetIcon with a plain texture drops the custom tint")
	assert(#env._errors == 0)
end

-- DevTest reports the icon set ---------------------------------------------------------------------

do
	local env, K = New()
	K.Options.Write("Icons", "enabled", true)
	K.DevTest.Run()
	local found
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		if entry.message:find("PASS icons", 1, true) then
			found = entry.message
		end
	end
	assert(found and found:find("set A", 1, true) and found:find("3 icons", 1, true), "DevTest logs the active set and its size: " .. tostring(found))
end

print("icons ok")
