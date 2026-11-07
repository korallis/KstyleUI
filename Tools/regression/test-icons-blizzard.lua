-- test-icons-blizzard.lua: with custom icons on, Blizzard's spellbook and talent icons show the custom set through hooks, keep Blizzard's own shading, and get Blizzard's art back when custom icons stop.
local W = dofile("Tools/regression/widget_env.lua")
local S = dofile("Tools/regression/skins_env.lua")

local FIREBALL, REJUV, UNKNOWN = 135812, 136081, 999999
local A_PATH = "Interface\\AddOns\\KstyleUI_Icons\\Icons\\"
local B_PATH = "Interface\\AddOns\\KstyleUI_IconsColour\\Icons\\"
local DATA = {
	KstyleUI_Icons = { set = "A", icons = { [FIREBALL] = A_PATH .. FIREBALL .. ".png", [REJUV] = A_PATH .. REJUV .. ".png" } },
	KstyleUI_IconsColour = { set = "B", icons = { [FIREBALL] = B_PATH .. FIREBALL .. ".png" } },
}
-- The methods the service may hook on a Blizzard texture, and the page method it hooks on the spellbook.
local HOOKS = { SetTexture = true, SetVertexColor = true, SetAtlas = true, SetAlpha = true, SetTexCoord = true, AddMaskTexture = true, RemoveMaskTexture = true, Show = true, Hide = true, SetShown = true, DisplayViewsForCurrentPage = true }

local function New()
	return W.New({
		setup = function(env)
			env._loaded = {}
			env.TalentFrameBaseMixin = { Event = { TalentButtonAcquired = "TalentButtonAcquired" } }
			env.C_AddOns = {
				LoadAddOn = function(name)
					env.KstyleUIIconData, env._loaded[name] = W.CoreEnv.DeepCopy(DATA[name]), true
					return true
				end,
				IsAddOnLoaded = function(name) return env._loaded[name] == true end,
			}
		end,
	})
end

-- Forever keeps one alpha per texture: SetAlpha and SetVertexColor's fourth argument both write it.
local function OneAlpha(button)
	local create = button.CreateTexture
	function button.CreateTexture(...)
		local t = create(...)
		local setColor = t.SetVertexColor
		function t.SetVertexColor(self, r, g, b, a)
			setColor(self, r, g, b, a)
			self._state.Alpha = { n = 1, a or self:GetAlpha() }
		end
		function t.GetVertexColor(self)
			local c = self._state.VertexColor or {}
			return c[1] or 1, c[2] or 1, c[3] or 1, self:GetAlpha()
		end
		return t
	end
end

-- PlayerSpells(B, ...) -> the stand-in spell pages of Blizzard_PlayerSpells, one item per file ID, each icon drawn by Blizzard.
local function PlayerSpells(B, ...)
	local frame = B.frame("Frame", nil, "PlayerSpellsFrame")
	frame.SpellBookFrame = B.frame("Frame", frame)
	local paged = B.frame("Frame", frame.SpellBookFrame)
	frame.SpellBookFrame.PagedSpellsFrame = paged
	local p = { paged = paged, page = {}, items = {}, icons = {} }
	for i, fileID in ipairs({ ... }) do
		local item = B.frame("Frame", paged)
		item.Button = B.frame("Button", item)
		OneAlpha(item.Button)
		item.Button.Icon = B.texture(item.Button)
		item.Button.IconMask = B.add(item.Button:CreateMaskTexture())
		item.Button.Icon:AddMaskTexture(item.Button.IconMask)
		item.Button.Icon:SetTexture(fileID)
		p.items[i], p.icons[i], p.page[i] = item, item.Button.Icon, item
	end
	function paged.ForEachFrame(_, fn)
		for _, item in ipairs(p.page) do
			fn(item)
		end
	end
	function paged.DisplayViewsForCurrentPage() end
	return p
end

local function Shown(icon)
	return W.LastCall(icon, "SetTexture")[1]
end

-- The additive highlight copy the service makes for set A on the texture's parent.
local function Highlight(texture)
	for _, region in ipairs({ texture:GetParent():GetRegions() }) do
		local blend, points = W.LastCall(region, "SetBlendMode"), W.LastCall(region, "SetAllPoints")
		if region ~= texture and blend and blend[1] == "ADD" and points and points[1] == texture then
			return region
		end
	end
end

-- Off: nothing is hooked; custom icons turned on with the spellbook already loaded hook it at once ----

do
	local env, K = New()
	local p = PlayerSpells(S.Blizzard(env), FIREBALL)
	S.LoadAddOn(env, "Blizzard_PlayerSpells")
	p.paged:DisplayViewsForCurrentPage()
	assert(Shown(p.icons[1]) == FIREBALL and rawget(p.icons[1], "SetTexture") == nil, "off: nothing is hooked and Blizzard's icon stays")
	K.Options.Write("Icons", "enabled", true)
	assert(Shown(p.icons[1]) == A_PATH .. FIREBALL .. ".png", "an open spellbook gets the custom icons when custom icons start")
	assert(#env._errors == 0)
end

-- On: set A replaces and tints Blizzard's icons, follows Blizzard's redraws and shading ---------------

do
	local env, K = New()
	K.Options.Write("Icons", "enabled", true)
	local B = S.Blizzard(env)
	local p = PlayerSpells(B, FIREBALL, UNKNOWN, REJUV)
	local icon, other, late = p.icons[1], p.icons[2], p.icons[3]
	p.page[3] = nil
	local snap = B.snapshot()
	S.LoadAddOn(env, "Blizzard_PlayerSpells")

	assert(Shown(icon) == A_PATH .. FIREBALL .. ".png", "an icon Blizzard drew before the hook gets set A's art")
	local ar, ag, ab = K.Theme.Accent()
	assert(W.SameRGB(icon, ar, ag, ab) and Highlight(icon), "and set A's class-colour tint and additive highlight")
	assert(Shown(other) == UNKNOWN and W.LastCall(other, "SetVertexColor") == nil, "an icon the set lacks is untouched")
	p.page[3] = p.items[3]
	p.paged:DisplayViewsForCurrentPage()
	assert(Shown(late) == A_PATH .. REJUV .. ".png", "items on a later page are watched when the page shows")

	icon:SetTexture(REJUV)
	assert(Shown(icon) == A_PATH .. REJUV .. ".png", "Blizzard's later SetTexture is swapped too, as on shapeshifting")
	icon:SetVertexColor(0.5, 0.5, 0.5, 1)
	assert(W.SameRGB(icon, ar * 0.5, ag * 0.5, ab * 0.5), "Blizzard's unlearned shading multiplies the tint")
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	icon:RemoveMaskTexture(p.items[1].Button.IconMask)
	assert(select(1, Highlight(icon):GetTexCoord()) == 0.07 and Highlight(icon):GetNumMaskTextures() == 0, "the highlight follows a later crop and mask, as the spellbook skin makes")
	assert(W.SameColor(Highlight(icon), 0.5, 0.5, 0.5, 0.25), "an opaque icon's highlight keeps the highlight strength")
	icon:SetAlpha(0.6)
	assert(W.SameColor(Highlight(icon), 0.5, 0.5, 0.5, 0.15), "a faded icon fades its highlight")
	K.Options.Write("Icons", "tint", "white")
	assert(W.SameColor(icon, 0.5, 0.5, 0.5, 0.6), "a redraw keeps Blizzard's latest alpha")
	icon:SetTexture(UNKNOWN)
	assert(Shown(icon) == UNKNOWN and W.SameRGB(icon, 0.5, 0.5, 0.5) and not Highlight(icon):IsShown(), "an icon the set lacks keeps Blizzard's art and shading")
	icon:SetTexture(env.Secret(FIREBALL))
	assert(env.issecretvalue(Shown(icon)), "a secret file ID keeps Blizzard's art")

	icon:SetTexture(FIREBALL)
	K.Options.Write("Icons", "set", "B")
	assert(Shown(icon) == B_PATH .. FIREBALL .. ".png" and W.SameRGB(icon, 0.5, 0.5, 0.5), "a set change redraws Blizzard's icons; set B keeps Blizzard's shading, untinted")
	K.Options.Write("Icons", "enabled", false)
	assert(Shown(icon) == FIREBALL and W.SameColor(icon, 0.5, 0.5, 0.5, 0.6), "turning custom icons off gives Blizzard's icon and alpha back")
	icon:SetTexture(REJUV)
	assert(Shown(icon) == REJUV, "off: Blizzard's redraws stay Blizzard's")
	B.check(snap, HOOKS)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Talents: buttons made before the hook and acquired after it, and an atlas icon ---------------------

do
	local env, K = New()
	local B = S.Blizzard(env)
	local frame = B.frame("Frame", nil, "PlayerSpellsFrame")
	local talents = B.frame("Frame", frame)
	frame.TalentsFrame = talents
	local active, callbacks, buttons = {}, {}, {}
	for i = 1, 3 do
		buttons[i] = B.frame("Button", talents)
		OneAlpha(buttons[i])
		buttons[i].Icon = B.texture(buttons[i])
	end
	buttons[2].Icon2 = B.texture(buttons[2])
	function talents.RegisterCallback(_, event, fn, owner)
		callbacks[#callbacks + 1] = { event = event, fn = fn, owner = owner }
	end
	function talents.EnumerateAllTalentButtons()
		local i = 0
		return function()
			i = i + 1
			return active[i]
		end
	end
	-- Acquire(button, fileID): Blizzard acquires a pooled button, fires TalentButtonAcquired, then draws the icon.
	local function Acquire(button, fileID)
		active[#active + 1] = button
		for _, entry in ipairs(callbacks) do
			entry.fn(entry.owner, button)
		end
		button.Icon:SetTexture(fileID)
	end
	local snap = B.snapshot()
	Acquire(buttons[1], FIREBALL)
	K.Options.Write("Icons", "enabled", true)
	S.LoadAddOn(env, "Blizzard_PlayerSpells")
	assert(Shown(buttons[1].Icon) == A_PATH .. FIREBALL .. ".png", "a talent button made before the hook is watched")
	Acquire(buttons[2], REJUV)
	buttons[2].Icon2:SetTexture(FIREBALL)
	assert(Shown(buttons[2].Icon) == A_PATH .. REJUV .. ".png", "a talent button acquired later is watched")
	assert(Shown(buttons[2].Icon2) == A_PATH .. FIREBALL .. ".png", "and so is a split-choice button's second icon")
	Acquire(buttons[3], FIREBALL)
	buttons[3].Icon:SetVertexColor(0.4, 0.4, 0.4, 1)
	buttons[3].Icon:SetAtlas("talents-node-choiceflyout")
	assert(W.SameRGB(buttons[3].Icon, 0.4, 0.4, 0.4) and not Highlight(buttons[3].Icon):IsShown(), "an atlas icon drops the tint and the highlight and keeps Blizzard's shading")
	B.check(snap, HOOKS)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("icons on Blizzard's spellbook and talents ok")
