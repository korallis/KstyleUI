-- test-skins-lumen.lua: the Lumen pieces the skins share: the gilt and quest gold colours read S1's token names and fall back to shipped tokens, the section cap draws a gem, a tracked title, a fading rule and a trailing count in one row, and the ring check box follows a Blizzard check button's state.
local S = dofile("Tools/regression/skins_env.lua")
local W = S.W
local Near = W.Near
local THIN_SPACE = "\226\128\137"

local function Plain(text)
	return (tostring(text:GetText()):gsub(THIN_SPACE, ""))
end

local function TextIs(text, r, g, b)
	local tr, tg, tb = text:GetTextColor()
	return Near(tr, r) and Near(tg, g) and Near(tb, b)
end

local function Regions(frame, kind, path)
	local out = {}
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:GetObjectType() == kind and (not path or region:GetTexture() == path) then
			out[#out + 1] = region
		end
	end
	return out
end

-- Colours: S1's names when Tokens has them, shipped tokens otherwise ----------------------------------------

do
	local env, K, ns = S.New()
	local Lumen = ns.Lumen
	assert(type(Lumen) == "table", "the skins share ns.Lumen")
	local r, g, b, a = Lumen.Color("gilt")
	local nr, ng, nb, na = K.Tokens.Color(Lumen.FALLBACKS.gilt)
	assert(Near(r, nr) and Near(g, ng) and Near(b, nb) and Near(a, na), "without S1's gilt token, gilt falls back to the shipped token it names")
	local qr, qg, qb = Lumen.Color("questGold")
	assert(qr > 0.8 and qg > 0.7 and qb < 0.7, "quest gold reads as a warm gold, got " .. qr .. " " .. qg .. " " .. qb)
	assert(not pcall(Lumen.Color, "noSuchColor"), "a name neither S1 nor the fallback table knows is an error, as Tokens.Color is")
	local ok = pcall(function()
		local real = K.Tokens.Color
		K.Tokens.Color = function(name)
			if name == "gilt" then
				return 0.1, 0.2, 0.3, 1
			end
			return real(name)
		end
		local sr, sg, sb = Lumen.Color("gilt")
		K.Tokens.Color = real
		assert(Near(sr, 0.1) and Near(sg, 0.2) and Near(sb, 0.3), "once Tokens knows gilt, Lumen reads it and the fallback goes unused")
	end)
	assert(ok, "the S1 switch works")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The section cap: gem, tracked Cinzel title, fading rule, trailing count ----------------------------------

local function WithColors(env)
	env.CreateColor = function(r, g, b, a)
		return { r = r, g = g, b = b, a = a }
	end
end

do
	local env, K, ns = S.New({ setup = WithColors })
	K.Modules.Enable("Skins")
	local Lumen, Style = ns.Lumen, ns.Style
	local parent = env.CreateFrame("Frame", nil, env.UIParent)
	parent:SetSize(300, 24)
	local cap = Lumen.SectionCap(parent, { left = 10, right = 24 })
	assert(cap.row:GetParent() == parent, "the cap draws on its own row frame under the parent")
	cap.row:SetAllPoints(parent)
	cap:SetTitle("Quests")
	cap:SetTrail(15)
	local gem = cap.gem
	assert(gem and gem:GetObjectType() == "Texture", "a gem leads the row")
	local gr, gg, gb = Lumen.Color("gilt")
	assert(W.SameRGB(gem, gr, gg, gb), "in gilt")
	assert(Near(gem:GetWidth(), K.Widgets.Snap(cap.row, Lumen.GEM_UNITS)) and Near(gem:GetHeight(), gem:GetWidth()), "a " .. Lumen.GEM_UNITS .. "-unit gem, got " .. tostring(gem:GetWidth()))
	local gemPoint = { gem:GetPoint(1) }
	assert(gemPoint[1] == "LEFT" and gemPoint[2] == cap.row and Near(gemPoint[4], K.Widgets.Snap(cap.row, 10)), "the gem sits at the row's left inset")
	local title = cap.title
	assert(Plain(title) == "QUESTS", "the title is upper case, got " .. Plain(title))
	assert(title:GetText():find(THIN_SPACE, 1, true), "and tracked when the kit face loads")
	assert((title:GetFont()) == Style.Font("caption") and Near((select(2, title:GetFont())), Lumen.CAP_SIZE), "in the caption face at the mockup's 13, got " .. tostring((select(2, title:GetFont()))))
	assert(TextIs(title, gr, gg, gb), "the title is gilt")
	local titlePoint = { title:GetPoint(1) }
	assert(titlePoint[1] == "LEFT" and titlePoint[2] == gem and titlePoint[3] == "RIGHT" and Near(titlePoint[4], K.Widgets.Snap(cap.row, K.Tokens.Size("gapSmall"))), "the title follows the gem after a gapSmall")
	assert(title:GetNumPoints() == 1, "the title sizes to its text, so the rule can start where it ends")
	local rule = cap.rule
	assert(rule and rule:GetObjectType() == "Texture", "a rule runs from the title to the count")
	local ruleLeft, ruleRight = { rule:GetPoint(1) }, { rule:GetPoint(2) }
	assert(ruleLeft[2] == title and ruleLeft[3] == "RIGHT" and Near(ruleLeft[4], K.Widgets.Snap(cap.row, K.Tokens.Size("gapMedium"))), "the rule starts a gapMedium after the title")
	assert(ruleRight[2] == cap.trail and ruleRight[3] == "LEFT" and Near(ruleRight[4], -K.Widgets.Snap(cap.row, K.Tokens.Size("gapMedium"))), "and ends a gapMedium before the count")
	assert(Near(rule:GetHeight(), K.Widgets.Border(cap.row)), "one border thick")
	local gradient = W.LastCall(rule, "SetGradient")
	assert(gradient and gradient[1] == "HORIZONTAL" and Near(gradient[2].a, Lumen.RULE_ALPHA) and Near(gradient[3].a, 0), "the rule fades out to the right")
	assert(Near(gradient[2].r, gr) and Near(gradient[2].g, gg) and Near(gradient[2].b, gb), "from gilt")
	local trail = cap.trail
	assert(Plain(trail) == "15", "the count reads 15")
	assert((trail:GetFont()) == Style.Font("number"), "in the number face")
	assert(TextIs(trail, K.Tokens.Color("text")), "muted")
	local trailPoint = { trail:GetPoint(1) }
	assert(trailPoint[1] == "RIGHT" and trailPoint[2] == cap.row and Near(trailPoint[4], -K.Widgets.Snap(cap.row, 24)), "right-aligned at the row's right inset")
	cap:SetTrail(nil)
	assert(trail:GetText() == "", "no count clears the trail")
	cap:SetTitle("The Deadmines")
	assert(Plain(title) == "THE DEADMINES", "a new title follows")
	-- A long title is bounded before the trail: it ellipsises instead of running under the count or the rule
	-- crossing it; with no measured widths (this stub, or a secret) it keeps its natural width.
	assert(W.LastCall(title, "SetWidth")[1] == 0, "with no measured width the title sizes to its text")
	title._state.UnboundedStringWidth = { n = 1, 400 }
	trail._state.UnboundedStringWidth = { n = 1, 12 }
	cap:SetTrail(15)
	local taken = 10 + Lumen.GEM_UNITS + K.Tokens.Size("gapSmall") + 2 * K.Tokens.Size("gapMedium") + 12 + 24
	assert(Near(W.LastCall(title, "SetWidth")[1], 300 - taken), "a 400-unit title on a 300-unit row is cut to the room before the trail, got " .. tostring(W.LastCall(title, "SetWidth")[1]))
	title._state.UnboundedStringWidth = { n = 1, 50 }
	cap:SetTitle("Quests")
	assert(Near(W.LastCall(title, "SetWidth")[1], 50), "a short title keeps its measured width")
	parent:SetSize(120, 24)
	local onSize = cap.row:GetScript("OnSizeChanged")
	assert(onSize, "the row refits on a size change")
	onSize(cap.row)
	assert(Near(W.LastCall(title, "SetWidth")[1], 120 - taken), "a narrower row refits the title")
	parent:SetSize(300, 24)
	cap:SetShown(false)
	assert(not cap.row:IsShown(), "SetShown hides the whole row")
	cap:SetShown(true)
	assert(cap.row:IsShown())
	K.Options.Write("Skins", "text.size", 1.2)
	assert(Near((select(2, title:GetFont())), Lumen.CAP_SIZE * 1.2), "the text size setting scales the title")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local env, K, ns = S.New()
	assert(env.CreateColor == nil, "this client has no CreateColor")
	local cap = ns.Lumen.SectionCap(env.CreateFrame("Frame", nil, env.UIParent), {})
	assert(cap.rule:GetTexture() == (K.Tokens.Texture("divider")), "without CreateColor the rule is the divider texture")
	local gr, gg, gb = ns.Lumen.Color("gilt")
	assert(W.SameColor(cap.rule, gr, gg, gb, ns.Lumen.RULE_ALPHA), "tinted gilt at the rule alpha")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The ring check box: a ring that lights under the mouse, a gilt fill while checked -----------------------

do
	local env, K, ns = S.New()
	local Lumen = ns.Lumen
	local B = S.Blizzard(env)
	local check = B.frame("CheckButton")
	local art = B.texture(check)
	check:SetChecked(false)
	local snap = B.snapshot()
	local ring = Lumen.RingCheck(check)
	assert(ring and Lumen.RingCheck(check) == ring, "a second call returns the same ring")
	assert(art:GetAlpha() == 0, "Blizzard's check art is hushed")
	local ringPath, dotPath = K.Tokens.Texture(Lumen.TEXTURES.checkRing), K.Tokens.Texture(Lumen.TEXTURES.gemFill)
	local ringTexture = Regions(ring.box, "Texture", ringPath)[1]
	local fill = Regions(ring.box, "Texture", dotPath)[1]
	assert(ringTexture and fill, "a ring and a fill draw on a KstyleUI frame over the button")
	assert(ring.box:GetParent() == check, "on the button")
	assert(Near(ring.box:GetWidth(), K.Widgets.Snap(ring.box, Lumen.RING_UNITS)), "the ring is " .. Lumen.RING_UNITS .. " units, got " .. tostring(ring.box:GetWidth()))
	assert(Near(fill:GetWidth(), K.Widgets.Snap(ring.box, Lumen.RING_FILL)), "the fill is " .. Lumen.RING_FILL .. " units, got " .. tostring(fill:GetWidth()))
	assert(W.SameRGB(ringTexture, K.Tokens.Color("edgeInner")), "at rest the ring is the edge line")
	assert(not fill:IsShown(), "unchecked, no fill")
	check:SetChecked(true)
	assert(fill:IsShown(), "checked, the fill shows")
	local gr, gg, gb = Lumen.Color("gilt")
	assert(W.SameRGB(fill, gr, gg, gb), "in gilt")
	assert(W.SameRGB(ringTexture, gr, gg, gb), "and the ring turns gilt with it")
	check:SetChecked(false)
	assert(not fill:IsShown(), "unchecked again, the fill hides")
	W.Enter(check)
	W.Settle(env)
	local hr, hg, hb = ringTexture:GetVertexColor()
	local er, eg, eb = K.Tokens.Color("edgeInner")
	assert(not (Near(hr, er) and Near(hg, eg) and Near(hb, eb)), "under the mouse the ring lights")
	W.Leave(check)
	W.Settle(env)
	assert(W.SameRGB(ringTexture, er, eg, eb), "and settles back when the mouse leaves")
	check:GetScript("OnClick")(check)
	assert(fill:IsShown() == (check:GetChecked() and true or false), "a click follows the button's state")
	B.check(snap, { SetChecked = true })
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Blizzard windows: every skinned window wears the Lumen window grade, a heading-face title and pill scroll bars --

do
	local Windows = dofile("Tools/regression/skins_windows.lua")
	local checked, bars = 0, 0
	for _, spec in ipairs(Windows.LIST) do
		local B, parts
		local env, K, ns = S.New({
			before = function(env)
				B = S.Blizzard(env)
				parts = select(2, Windows.Build(spec.key, env, B))
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
		for _, skin in ipairs(spec.skins) do
			assert(ns.Skins.IsApplied(skin), spec.key .. ": the " .. skin .. " skin applies")
		end
		-- The window, or one of its pages (the group finder and ready check draw their glass on a child), wears the
		-- window grade; the loot rolls are toasts and wear the panel grade.
		local window = env[spec.frame]
		local windowParts = K.Skin.Parts(window)
		local grade = spec.key == "lootrolls" and "panel" or "window"
		local function Under(frame)
			while frame do
				if frame == window then
					return true
				end
				frame = frame:GetParent()
			end
			return false
		end
		local found
		for _, frame in ipairs(parts.show) do
			local p = K.Skin.Parts(frame)
			found = found or (p and p.backdrop)
		end
		for _, frame in ipairs(B.made) do
			local p = type(frame.GetParent) == "function" and not found and K.Skin.Parts(frame)
			if p and p.backdrop and p.backdrop.chrome.shapeName == grade and Under(frame) then
				found = p.backdrop
			end
		end
		assert(found, spec.key .. ": the window or one of its pages sits on a KstyleUI backdrop")
		assert(found.chrome.shapeName == grade, spec.key .. ": the " .. grade .. " grade, Lumen's rail with gilt tips when S1 lands, got " .. tostring(found.chrome.shapeName))
		assert(found.chrome.fillName == "surface", spec.key .. ": on the glass surface")
		local headingPath = ns.Style.Font("heading")
		local title = type(window.TitleContainer) == "table" and window.TitleContainer.TitleText or nil
		if title and windowParts and windowParts.kinds.Window then
			assert((title:GetFont()) == headingPath, spec.key .. ": the title is in the heading face, Lumen's Cinzel")
		end
		for _, frame in ipairs(env._frames) do
			local p = K.Skin.Parts(frame)
			if p and p.kinds.ScrollBar and p.thumb then
				bars = bars + 1
				assert(type(p.thumbCaps) == "table" and p.thumbCaps[1] and p.thumbCaps[2], spec.key .. ": a skinned scroll bar's thumb is a pill")
			end
		end
		assert(#env._errors == 0, spec.key .. ": " .. tostring(env._errors[1]))
		checked = checked + 1
	end
	assert(checked == #Windows.LIST and checked >= 19, "every one of the 19 windows was checked, got " .. checked)
	assert(bars > 0, "at least one window has a skinned scroll bar, got " .. bars)
end

print("skins lumen ok")
