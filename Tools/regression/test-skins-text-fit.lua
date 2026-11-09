-- test-skins-text-fit.lua: skinned window texts read LEFT and sit inside their pane (the reputation description, the mail body, the trainer's skill bar label and rank), and the character sheet's mode tabs dock to the window on one rail.
local S = dofile("Tools/regression/skins_env.lua")
local Windows = dofile("Tools/regression/skins_windows.lua")
local Geometry = dofile("Tools/regression/geometry.lua")
local Measure = dofile("Tools/regression/databars_env.lua")
local W = S.W

local EPS = 0.01

-- Open(key) -> env, K, ns, parts: the stand-in window built as the gallery builds it, shown, its skins applied.
local function Open(key, setup)
	local spec = Windows.Spec(key)
	local B, parts
	local env, K, ns = S.New({
		setup = function(env)
			env._textWidth = Measure.TextWidth
			if setup then
				setup(env)
			end
		end,
		before = function(env)
			B = S.Blizzard(env)
			parts = select(2, Windows.Build(key, env, B))
		end,
	})
	K.Modules.Enable("Skins")
	if spec.addon then
		S.LoadAddOn(env, spec.addon)
	end
	for _, shown in ipairs(parts.show) do
		S.Show(shown)
	end
	env.RunTimers()
	W.Settle(env)
	for _, skin in ipairs(spec.skins) do
		assert(ns.Skins.IsApplied(skin), key .. ": the " .. skin .. " skin applies")
	end
	return env, K, ns, parts
end

-- Natural(text) gives a font string with one anchor on an axis its text's extent there, as the game sizes a
-- string with no width or height: its text's width in its font, and its font's size as its height.
local function Natural(text)
	if text:GetWidth() == nil then
		local width = text:GetUnboundedStringWidth()
		assert(type(width) == "number" and width > 0, "the text measures")
		text:SetWidth(width)
	end
	if text:GetHeight() == nil then
		local _, size = text:GetFont()
		text:SetHeight(size)
	end
	return text
end

local function Rect(region, root)
	local rect, why = Geometry.Rect(region, root)
	assert(rect, tostring(why))
	return rect
end

local function Inside(inner, outer, what)
	assert(inner.left >= outer.left - EPS and inner.right <= outer.right + EPS, what .. ": left " .. inner.left .. " right " .. inner.right .. " in " .. outer.left .. ".." .. outer.right)
	assert(inner.bottom >= outer.bottom - EPS and inner.top <= outer.top + EPS, what .. ": bottom " .. inner.bottom .. " top " .. inner.top .. " in " .. outer.bottom .. ".." .. outer.top)
end

local function Justify(text)
	local call = W.LastCall(text, "SetJustifyH")
	return call and call[1]
end

-- Reputation: the description reads LEFT in the body face, inside the pane and clear of the scroll bar -----

do
	local env, _, ns = Open("reputation")
	local root = env.UIParent
	local detail = env.ReputationFrame.ReputationDetailFrame
	local description = detail.Description
	assert(type(description) == "table", "the stand-in detail pane has Forever's Description scrolling font")
	local text = description.ScrollBox.FontStringContainer.FontString
	assert(Justify(text) == "LEFT", "the description is justified LEFT, got " .. tostring(Justify(text)))
	assert((text:GetFont()) == ns.Style.Font("body"), "and wears the body face")
	local pane, box, bar = Rect(detail, root), Rect(description, root), Rect(detail.DescriptionScrollBar, root)
	Inside(box, pane, "the description box sits inside the pane")
	assert(box.right <= bar.left + EPS, "the description ends before the scroll bar: " .. box.right .. " vs " .. bar.left)
	Inside(Rect(text, root), box, "the text fills its box, not the pane")
end

-- Mail: the open letter's body reads LEFT, in the body face, inside the letter's scroll frame -------------

do
	local env, _, ns = Open("mail")
	local root = env.UIParent
	local body = env.OpenMailBodyText
	assert(Justify(body) == "LEFT", "the letter body is justified LEFT, got " .. tostring(Justify(body)))
	assert((body:GetFont()) == ns.Style.Font("body"), "and wears the body face")
	Inside(Rect(body, root), Rect(env.OpenMailScrollFrame, root), "the body lies inside the letter's scroll frame")
end

-- Trainer: the skill bar is the kit capsule, the skill's name LEFT and the rank RIGHT, both inside the bar -----

do
	local env, K, ns = Open("trainer")
	local root = env.UIParent
	local bar = env.ClassTrainerStatusBar
	local parts = K.Safe.Side(bar).partBBar
	assert(parts and parts.label, "the skill bar gets a KstyleUI label")
	assert(parts.label:GetText() == "Polearms" and parts.label:IsShown(), "the label names the trainer's skill line, got " .. tostring(parts.label:GetText()))
	assert(Justify(parts.label) == "LEFT" and Justify(bar.rankText) == "RIGHT", "label LEFT, rank RIGHT")
	assert((bar.rankText:GetFont()) == ns.Style.Font("number"), "the rank wears the number face")
	Natural(bar.rankText)
	Natural(parts.label)
	local track, label, rank = Rect(bar, root), Rect(parts.label, root), Rect(bar.rankText, root)
	Inside(label, track, "the label sits inside the bar")
	Inside(rank, track, "the rank sits inside the bar")
	assert(label.right <= rank.left + EPS, "the label ends before the rank begins")
	assert(label.left > track.left and rank.right < track.right, "both keep an inset from the bar's ends")
	local ar, ag, ab = ns.Style.Accent()
	local er, eg, eb = ns.Style.BarColor(ar, ag, ab, 1)
	local r, g, b = bar:GetStatusBarColor()
	assert(W.Near(r, er) and W.Near(g, eg) and W.Near(b, eb), "the fill is the kit accent, not Blizzard's blue")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Character: the mode tabs stand on one rail docked to the window's edge, their icons quiet until chosen ----

do
	local env, K, ns = Open("character")
	local root = env.UIParent
	local f = env.CharacterFrame
	local rail = ns.CharacterRail(f)
	assert(rail and rail.clip, "the tabs' rail is clipped at the window's edge")
	local window, clip, railRect = Rect(f, root), Rect(rail.clip, root), Rect(rail, root)
	assert(W.Near(clip.left, window.right), "the rail starts at the window's right edge: " .. clip.left .. " vs " .. window.right)
	assert(railRect.left < window.right, "the rail's own left edge runs under the window, so the clip cuts its left corners away")
	for i, tab in ipairs(f.ModeTabs.Tabs) do
		Inside(Rect(tab, root), clip, "mode tab " .. i .. " sits on the rail")
	end
	local chrome = K.Skin.Parts(rail).backdrop.chrome
	assert(chrome.shadowOn ~= true, "the rail casts no shadow of its own onto the window")
	for i, tab in ipairs(f.ModeTabs.Tabs) do
		local alpha = tab.Icon:GetAlpha()
		if i == 1 then
			assert(alpha == 1, "the chosen tab's icon is full")
		else
			assert(alpha < 1 and alpha > 0.3, "an unchosen tab's icon is quiet, got " .. tostring(alpha))
		end
	end
	f.ModeTabs.Tabs[2]:SetChecked(true)
	assert(f.ModeTabs.Tabs[2].Icon:GetAlpha() == 1, "choosing a tab brings its icon up")
	-- The equipment slots and their rims lie inside the window glass.
	for _, name in ipairs({ "CharacterHeadSlot", "CharacterHandsSlot", "CharacterMainHandSlot" }) do
		local rim = ns.Parts.RimOf(env[name])
		Inside(Rect(rim, root), window, name .. "'s rim lies inside the window")
	end
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("skins text fit ok")
