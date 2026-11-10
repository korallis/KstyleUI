-- test-skins-lumen.lua: the Lumen pieces the skins share: the gilt and quest gold colours read S1's token names and fall back to shipped tokens, the section cap draws a flat gilt diamond, a tracked title, an even rule and a trailing count in one row, all sized in root units, and the ring check box follows a Blizzard check button's state.
local S = dofile("Tools/regression/skins_env.lua")

local function FontSize(K, text, actual, requested)
	local factor = type(text.GetEffectiveScale) == "function" and K.Widgets.ScaleFactor(text) or 1
	local pixels = actual * factor / K.Scale.Pixel(1)
	return math.abs(actual - K.Widgets.FontSize(text, requested)) < 1e-8
		and math.abs(pixels - math.floor(pixels + 0.5)) < 1e-8
end
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
	local tr, tg, tb, ta = K.Tokens.Color("gilt")
	assert(Near(r, tr) and Near(g, tg) and Near(b, tb) and Near(a, ta), "with S1's gilt token, Lumen reads it")
	local wr, wg, wb = Lumen.Color("questGold")
	local xr, xg, xb = K.Tokens.Color("questGold")
	assert(Near(wr, xr) and Near(wg, xg) and Near(wb, xb) and Near(wr, 0xf2 / 255) and Near(wg, 0xcf / 255) and Near(wb, 0x55 / 255), "quest gold is the questGold token, the picture's #f2cf55 quest titles")
	local fellBack = pcall(function()
		local real = K.Tokens.Color
		K.Tokens.Color = function(name)
			if name == "gilt" then
				error("unknown name gilt")
			end
			return real(name)
		end
		local fr, fg, fb, fa = Lumen.Color("gilt")
		K.Tokens.Color = real
		local nr, ng, nb, na = real(Lumen.FALLBACKS.gilt)
		assert(Near(fr, nr) and Near(fg, ng) and Near(fb, nb) and Near(fa, na), "without S1's gilt token, gilt falls back to the shipped token it names")
	end)
	assert(fellBack, "the fallback still works")
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

-- The section cap: diamond, tracked Cinzel title, even rule, trailing count ---------------------------------

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
	local factor = K.Widgets.ScaleFactor(cap.row)
	assert(Lumen.GEM_UNITS == 8 and Near(gem:GetWidth(), K.Widgets.Snap(cap.row, Lumen.GEM_UNITS / factor)) and Near(gem:GetHeight(), gem:GetWidth()), "a gem 8 root units from point to point, whatever scale the cap's frame has, got " .. tostring(gem:GetWidth()))
	assert(W.LastCall(gem, "SetTexture")[1] == K.Tokens.Texture("diamond") and W.LastCall(gem, "SetRotation") == nil, "the flat diamond the picture draws: its own texture, already turned, with no facets and no halo")
	local gemPoint = { gem:GetPoint(1) }
	assert(gemPoint[1] == "LEFT" and gemPoint[2] == cap.row and Near(gemPoint[4], K.Widgets.Snap(cap.row, 10)), "the gem sits at the row's left inset")
	local title = cap.title
	assert(Plain(title) == "QUESTS", "the title is upper case, got " .. Plain(title))
	assert(not title:GetText():find(THIN_SPACE, 1, true), "and carries no thin space, which Cinzel cannot draw")
	assert((title:GetFont()) == Style.Font("caps") and Lumen.CAP_SIZE == 12 and FontSize(K, title, select(2, title:GetFont()), Lumen.CAP_SIZE / K.Widgets.ScaleFactor(cap.row)), "in the caps face at the picture's 12 root units (21 px on the owner's screen), whatever scale the cap's frame has, got " .. tostring((select(2, title:GetFont()))))
	assert(TextIs(title, K.Tokens.Color("capsGold")), "the title is the picture's muted gold")
	assert(Near(K.Widgets.TrackPad(title), K.Tokens.FaceTracking((title:GetFont())) * select(2, title:GetFont())), "kit-owned captions retain their tracking compensation for the rule start")
	local titlePoint = { title:GetPoint(1) }
	assert(Near(Lumen.CapColumn(cap.row), K.Widgets.Snap(cap.row, Lumen.GEM_UNITS / factor) + K.Widgets.Snap(cap.row, Lumen.GEM_GAP / factor)) and Lumen.GEM_UNITS + Lumen.GEM_GAP == 15, "the title's column is 15 root units after the gem's left point")
	assert(titlePoint[1] == "LEFT" and titlePoint[2] == cap.row and Near(titlePoint[4], K.Widgets.Snap(cap.row, 10) + Lumen.CapColumn(cap.row)), "the title starts in that column, got " .. tostring(titlePoint[4]))
	assert(title:GetNumPoints() == 1, "the title sizes to its text, so the rule can start where it ends")
	local rule = cap.rule
	assert(rule and rule:GetObjectType() == "Texture", "a rule runs from the title to the count")
	local ruleLeft, ruleRight = { rule:GetPoint(1) }, { rule:GetPoint(2) }
	assert(ruleLeft[2] == title and ruleLeft[3] == "RIGHT" and math.abs(ruleLeft[4] + K.Widgets.TrackPad(title) - K.Widgets.Snap(cap.row, Lumen.RULE_LEAD / factor)) <= K.Scale.Pixel(1), "the rule starts 11 root units after the last letter, not after the tracking that follows it")
	assert(ruleRight[2] == cap.trail and ruleRight[3] == "LEFT" and Near(ruleRight[4], -K.Widgets.Snap(cap.row, Lumen.RULE_TRAIL / factor)), "and ends 9 root units before the count")
	assert(Near(rule:GetHeight(), math.max(K.Widgets.Border(cap.row), K.Widgets.Snap(cap.row, 1 / factor))), "one root unit thick (two pixels on the owner's screen), never under a pixel")
	local flat = W.LastCall(rule, "SetColorTexture")
	assert(W.LastCall(rule, "SetGradient") == nil and Lumen.RULE_ALPHA == 0.5 and Near(flat[4], Lumen.RULE_ALPHA), "the rule is one even line at half strength from end to end, as the picture draws it: it does not fade")
	assert(Near(flat[1], gr) and Near(flat[2], gg) and Near(flat[3], gb), "in gilt")
	local trail = cap.trail
	assert(Plain(trail) == "15", "the count reads 15")
	assert((trail:GetFont()) == Style.Font("number"), "in the number face")
	assert(TextIs(trail, K.Tokens.Color("textEmphasis")), "in near white, as the picture draws Step 134 and the quests' 7")
	local trailPoint = { trail:GetPoint(1) }
	assert(trailPoint[1] == "RIGHT" and trailPoint[2] == cap.row and Near(trailPoint[4], -K.Widgets.Snap(cap.row, 24)), "right-aligned at the row's right inset")
	cap:SetTrail(nil)
	assert(trail:GetText() == "", "no count clears the trail")
	cap:SetTitle("The Deadmines")
	assert(Plain(title) == "THE DEADMINES", "a new title follows")
	-- A long title is bounded before the trail: it ellipsises instead of running under the count or the rule
	-- crossing it; with no measured widths (this stub, or a secret) it keeps its natural width.
	assert(W.LastCall(title, "SetWidth")[1] == 0, "with no measured width the title sizes to its text")
	local pad = K.Widgets.TrackPad(title)
	title._state.UnboundedStringWidth = { n = 1, 400 }
	trail._state.UnboundedStringWidth = { n = 1, 12 }
	cap:SetTrail(15)
	local taken = 10 + Lumen.CapColumn(cap.row) + (Lumen.RULE_LEAD + Lumen.RULE_TRAIL) / K.Widgets.ScaleFactor(cap.row) + 12 + 24
	assert(Near(W.LastCall(title, "SetWidth")[1], 300 - taken + pad), "a 400-unit title on a 300-unit row is cut to the room before the trail (its string rect holds the tracking after the last letter), got " .. tostring(W.LastCall(title, "SetWidth")[1]))
	title._state.UnboundedStringWidth = { n = 1, 50 }
	cap:SetTitle("Quests")
	assert(W.LastCall(title, "SetWidth")[1] == 0, "a title the row has room for takes its natural width: the client draws its own string rect, so a measuring gap (Cinzel's thin spaces) can never truncate it, got " .. tostring(W.LastCall(title, "SetWidth")[1]))
	assert(not title:IsTruncated(), "and is not truncated")
	title._state.UnboundedStringWidth = { n = 1, 300 - taken + pad }
	cap:SetTitle("Quests")
	assert(W.LastCall(title, "SetWidth")[1] == 0, "a title that exactly fills the room still takes its natural width")
	title._state.UnboundedStringWidth = { n = 1, 300 - taken + pad + 1 }
	cap:SetTitle("Quests")
	assert(Near(W.LastCall(title, "SetWidth")[1], 300 - taken + pad), "one unit over the room, the title is clamped to the room and ellipsises")
	title._state.UnboundedStringWidth = { n = 1, 50 }
	cap:SetTitle("Quests")
	parent:SetSize(120, 24)
	local onSize = cap.row:GetScript("OnSizeChanged")
	assert(onSize, "the row refits on a size change")
	onSize(cap.row)
	assert(Near(W.LastCall(title, "SetWidth")[1], 120 - taken + pad), "a narrower row refits the title")
	parent:SetSize(300, 24)
	cap:SetShown(false)
	assert(not cap.row:IsShown(), "SetShown hides the whole row")
	cap:SetShown(true)
	assert(cap.row:IsShown())
	K.Options.Write("Skins", "text.size", 1.2)
	assert(FontSize(K, title, select(2, title:GetFont()), Lumen.CAP_SIZE * 1.2 / K.Widgets.ScaleFactor(cap.row)), "the text size setting scales the title")
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

-- Blizzard windows: every skinned window wears the Lumen window grade, a caps-face title and pill scroll bars --

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
		local titlePath = ns.Style.Font("caps")
		local title = type(window.TitleContainer) == "table" and window.TitleContainer.TitleText or nil
		if title and windowParts and windowParts.kinds.Window then
			assert((title:GetFont()) == titlePath or ((spec.key == "character" or spec.key == "reputation") and (title:GetFont()) == ns.Style.Font("names")), spec.key .. ": the title is in the gold caps face, Lumen's Cinzel Caps (the character's name in the names face)")
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
