-- test-skins-lumen.lua: shared skin colours, delegated card caps and insets, and ring check boxes.
local S = dofile("Tools/regression/skins_env.lua")

local W = S.W
local Near = W.Near
local THIN_SPACE = "\226\128\137"

local function Plain(text)
	return (tostring(text:GetText()):gsub(THIN_SPACE, ""))
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

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env, K, ns = S.New({ width = screen[1], height = screen[2], setup = WithColors })
	local Lumen, Widgets = ns.Lumen, K.Widgets
	assert(Lumen.SectionCap == Widgets.SectionCap, "skins must delegate caps to Widgets.SectionCap")
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(300, 24)
	for _, scale in ipairs({ 0.8, 1, 1.2 }) do
		parent:SetScale(scale)
		assert(Lumen.Inset(parent) == Widgets.Inset(parent, K.Tokens.Size("radius")), "skins must use the card inset at every scale")
		local cap = Lumen.SectionCap(parent, { text = "Quests", count = 15 })
		assert(cap:GetParent() == parent and Plain(cap.label) == "QUESTS" and tostring(cap.count:GetText()) == "15")
	end
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
		local titleRole = (spec.key == "character" or spec.key == "reputation" or spec.key == "merchant" or spec.key == "trainer") and "names" or "caps"
		local titlePath = ns.Style.Font(titleRole)
		local title = type(window.TitleContainer) == "table" and window.TitleContainer.TitleText or nil
		if title and windowParts and windowParts.kinds.Window then
			assert((title:GetFont()) == titlePath, spec.key .. ": the title uses the " .. titleRole .. " face")
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
