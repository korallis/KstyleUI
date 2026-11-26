-- SlabGrove.lua: the druid's crest trackers, registered with SlabTrackers, each on its own switch and a full crest in every form: the shoulder figures burn down with your effects on the target (a moon, swarm, bud, sprout, claw marks, tear, roar or sparkle) (as a caster, moonkin or in travel and aquatic form Moonfire or Rejuvenation on the left and Insect Swarm or Regrowth on the right; Rake and Rip tearing across the crest in Cat Form; Demoralizing Roar over the crown and Faerie Fire in Bear Form); Clearcasting blooms leaves round the inner rim over a druid glow; the gem at the top of the ring follows the form: Swiftmend's cooldown (or Nature's Swiftness's, or Innervate's) as a caster, Nature's Swiftness's (or Innervate's) as a moonkin, your Faerie Fire on the target in Cat Form and Maul queued in Bear Form; a third figure above the crown burns down with your Faerie Fire on an enemy or Wild Growth on a friend as a caster and Faerie Fire as a moonkin; Rake shares its figure with Pounce's bleed; a bear gets the tank glow while it holds the target's threat, Growl's fang and Feral Charge's chevrons charging on the foot perches and Primal Bite and Bash ready in the ring sockets, where a caster sees a main-hand oil socket while an oil is in the bags or on the weapon; and the major cooldowns burn on the rim. Every form's choice is built out of combat, so a shift only shows one; aura slots, cooldown duration objects and the engine's shown animations draw the timers, so Lua never reads or compares a secret.
local _, ns = ...
if not (UnitClass and select(2, UnitClass("player")) == "DRUID") then
	return
end

local K = KstyleUI
local Medals = ns.SlabMedals
local IsSecret = K.Widgets.IsSecret

local MOONFIRE = { 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }
local SWARM = { 24977, 24976, 24975, 24974, 5570 }
local REJUVENATION = { 25299, 9841, 9840, 9839, 8910, 3627, 2091, 2090, 1430, 1058, 774 }
local REGROWTH = { 9858, 9857, 9856, 9750, 8941, 8940, 8939, 8938, 8936 }
local RAKE, RIP = { 9904, 1824, 1823, 1822 }, { 9896, 9894, 9752, 9493, 9492, 1079 }
local ROAR, FAERIE = { 9898, 9747, 9490, 1735, 99 }, { 9907, 9749, 778, 770 }
local MAUL = { 9881, 9880, 9745, 8972, 6809, 6808, 6807 }
local OMEN, CLEARCASTING = { 16864 }, { 16870, 457342, 467735 }
local GROWTH, POUNCE = { 1238215, 1238214, 408120 }, { 9826, 9824, 9007 }
local GROWL, CHARGE, BITE, BASH = { 6795 }, { 1238122 }, { 1238070, 1238069, 407995 }, { 8983, 6798, 5211 }
local BEAR, CAT, MOONKIN, CASTER = { 5, 8 }, { 1 }, { 31, 35 }, { 0, 3, 4 }
local LEAVES, LEAF, UNFURL, PERCH, FOOT = 8, 14, 0.35, 30, 22
local DASH, BARKSKIN = { spells = { 1850, 9821 }, sigil = "Dash" }, { spells = { 22812 }, sigil = "Bark" }

local maul, bloom = {}, nil
local Oil, Ring = ns.SlabVigil.Oil, ns.SlabVigil.Ring
local Join = ns.SlabTrackers.Joined

local function Effect(spells, figure, tint, filter, forms, seat, size)
	return { feed = "aura", unit = "target", filter = filter or "HARMFUL|PLAYER", spells = spells, figure = figure, bloom = tint, forms = forms, seat = seat, size = size }
end

local function Bloom(parent, spec, level, form)
	if form == "row" then
		return Medals.Figure(parent, { feed = "aura", spells = CLEARCASTING, figure = "trackerLeaf", burst = spec.burst, bloom = "schoolNature" }, level)
	end
	local r = Medals.Rim(parent, { feed = "aura", spells = CLEARCASTING, ambient = "medAmbientDruid", burst = spec.burst }, level)
	r.ring, r.moving, r.calm = {}, Medals.Mirror(r, r.lit, level + 2, false), Medals.Mirror(r, r.lit, level + 2, false)
	r.leaves = Medals.Layer(r.moving.lit, level + 2)
	r.unfurl = r.leaves:CreateAnimationGroup()
	local grow = r.unfurl:CreateAnimation("Scale")
	grow:SetScaleFrom(0.6, 0.6)
	grow:SetScaleTo(1, 1)
	grow:SetDuration(UNFURL)
	grow:SetSmoothing(K.Tokens.Smoothing.enter)
	ns.Slab.Fade(r.unfurl, 0, 1, UNFURL)
	for k = 1, LEAVES do
		for _, layer in ipairs({ r.leaves, r.calm.lit }) do
			local leaf = r.add(layer:CreateTexture(nil, "OVERLAY"), LEAF)
			leaf:SetTexture((K.Tokens.Texture("trackerLeaf")))
			leaf:SetBlendMode("ADD")
			leaf.angle = (k - 0.5) * 360 / LEAVES
			leaf:SetRotation(-math.rad(leaf.angle))
			if r.ring[k] then
				r.ring[k].twin = leaf
			else
				r.ring[k] = leaf
			end
		end
	end
	if r.lit.container then
		r.moving.lit:AddAuraShownAnimation(r.unfurl)
		r.unfurl:SetScript("OnPlay", function()
			r.late = r.moving:GetAlpha() == 0 and GetTime() + UNFURL or nil
		end)
	end
	bloom = r
	return r
end

local function Unfurl(_, full)
	if not bloom then
		return
	end
	bloom.full = full
	local left = full and bloom.moving:GetAlpha() == 0 and bloom.late and bloom.late - GetTime() or 0
	if left > 0 then
		C_Timer.After(left, function()
			Unfurl(nil, bloom.full)
		end)
		return
	end
	bloom.moving:SetAlpha(full and 1 or 0)
	bloom.calm:SetAlpha(full and 0 or 1)
end

local function Emblem(parent, spec, level, form)
	return (form == "crest" and Medals.Emblem or Medals.Threat)(parent, spec, level)
end

local function Maul(parent, spec, level, form)
	local s = Medals.Socket(parent, spec, level, form)
	maul[#maul + 1] = s
	return s
end

local function Queued(_, event)
	if event ~= nil and event ~= "CURRENT_SPELL_CAST_CHANGED" then
		return
	end
	local current = C_Spell and C_Spell.IsCurrentSpell
	for _, s in ipairs(maul) do
		local on = current and current(s.spec.spell)
		s.lit:SetShown(not IsSecret(on) and on == true)
	end
end

local function Gems(choice)
	choice.color, choice.build = choice.color or "schoolNature", choice.build or Medals.Socket
	return choice
end

ns.SlabTrackers.Register("DRUID", {
	{ key = "crestSeeds", seat = { -62, 40 }, size = PERCH, build = Medals.Figure, choices = {
		Effect(ROAR, "figureRoar", "jewelCombo", nil, BEAR, { 0, 88 }, 40),
		{ forms = CAT, known = Join(RAKE, POUNCE), seat = { -44, 6 }, size = 60, feeds = { Effect(POUNCE, "figureRake", "jewelCombo"), Effect(RAKE, "figureRake", "plateHostile") } },
		{ forms = Join(CASTER, MOONKIN), known = Join(MOONFIRE, REJUVENATION), feeds = { Effect(MOONFIRE, "figureMoon", "schoolArcane"),
			Effect(REJUVENATION, "figureBud", "schoolNature", "HELPFUL|PLAYER") } },
	} },
	{ key = "crestSeeds", seat = { 62, 40 }, size = PERCH, build = Medals.Figure, choices = {
		Effect(FAERIE, "figureFaerie", "schoolArcane", nil, BEAR), Effect(RIP, "figureRip", "plateHostile", nil, CAT, { 44, 6 }, 56),
		{ forms = Join(CASTER, MOONKIN), known = Join(SWARM, REGROWTH), feeds = { Effect(SWARM, "figureSwarm", "jewelHawk"),
			Effect(REGROWTH, "figureSprout", "schoolNature", "HELPFUL|PLAYER") } },
	} },
	{ key = "crestThird", seat = { 0, 92 }, size = 30, build = Medals.Figure, choices = {
		{ forms = CASTER, known = Join(FAERIE, GROWTH), feeds = { Effect(FAERIE, "figureFaerie", "schoolArcane"), Effect(GROWTH, "figureGrowth", "schoolNature", "HELPFUL|PLAYER") } },
		Effect(FAERIE, "figureFaerie", "schoolArcane", nil, MOONKIN), Gems({ feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", spells = FAERIE, color = "schoolArcane",
			forms = CAT, seat = "lowerLeft" }),
	} },
	{ key = "crestGrowl", seat = { -30, -60 }, size = FOOT, feed = "cooldown", known = GROWL, forms = BEAR, build = Medals.Figure, figure = "figureGrowl", bloom = "jewelCombo" },
	{ key = "crestCharge", seat = { 30, -60 }, size = FOOT, feed = "cooldown", known = CHARGE, forms = BEAR, build = Medals.Figure, figure = "figureCharge",
		bloom = "jewelCombo" },
	{ key = "crestBite", seat = "lowerLeft", feed = "cooldown", known = BITE, forms = BEAR, color = "jewelCombo", build = Medals.Socket },
	{ key = "crestBash", seat = "lowerRight", feed = "cooldown", known = BASH, forms = BEAR, color = "jewelCombo", build = Medals.Socket },
	{ key = "crestOil", seat = "lowerRight", feed = "enchant", slot = "MainHand", known = Oil, forms = Join(CASTER, MOONKIN), color = "jewelHoly", build = Medals.Socket },
	{ key = "crestLeaves", seat = "rim", known = OMEN, spells = CLEARCASTING, build = Bloom, place = Ring },
	{ key = "crestSwiftmend", seat = "topGem", feed = "cooldown", choices = {
		Gems({ forms = BEAR, known = MAUL, color = "jewelCombo", build = Maul }),
		Gems({ forms = MOONKIN, known = { 17116 } }), Gems({ forms = MOONKIN, known = { 29166 } }),
		Gems({ forms = CASTER, known = { 18562 } }), Gems({ forms = CASTER, known = { 17116 } }), Gems({ forms = CASTER, known = { 29166 } }),
	} },
	{ key = "crestTankGlow", seat = "rim", feed = "threat", build = Emblem, color = "gilt", forms = BEAR, known = { 9634, 5487 } },
	{ key = "crestCooldowns", seat = "cooldowns", color = "pipDruidGlow", bloom = "pipDruidGlow", choices = {
		{ forms = BEAR, families = { { spells = { 22842 }, sigil = "Mend" }, { spells = { 5229 }, sigil = "Fang" }, BARKSKIN, DASH } },
		{ forms = CAT, families = { DASH, BARKSKIN } },
		{ families = { { spells = { 29166 }, sigil = "Innervate" }, { spells = { 17116 }, sigil = "Swift" }, BARKSKIN, DASH,
				{ spells = { 16689, 16810, 16811, 16812, 16813, 17329 }, sigil = "Roots" } } },
	} },
}, { figures = true, burst = "medBurstDruid", fiveSecondForms = Join(CASTER, MOONKIN), events = { "CURRENT_SPELL_CAST_CHANGED" }, update = { "BAG_UPDATE_DELAYED", "WEAPON_ENCHANT_CHANGED" }, paint = Queued, motion = Unfurl })
