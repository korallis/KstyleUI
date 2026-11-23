-- SlabGrove.lua: the druid's crest trackers, registered with SlabTrackers, each on its own switch and a full crest in every form: the shoulder medals show your effects on the target with their icon and a ring that drains over their time (as a caster, moonkin or in travel and aquatic form Moonfire or Rejuvenation on the left and Insect Swarm or Regrowth on the right; Rake and Rip in Cat Form; Demoralizing Roar and Faerie Fire in Bear Form); Clearcasting blooms leaves round the inner rim over a druid glow; the gem at the top of the ring follows the form: Swiftmend's cooldown (or Nature's Swiftness's, or Innervate's) as a caster, Nature's Swiftness's (or Innervate's) as a moonkin, your Faerie Fire on the target in Cat Form and Maul queued in Bear Form; a third medal at the top shows your Faerie Fire on an enemy or Wild Growth on a friend as a caster and Faerie Fire as a moonkin; Rake shares its medal with Pounce's bleed; a bear gets the tank glow while it holds the target's threat, Growl and Feral Charge ready on the foot perches and Primal Bite and Bash ready in the ring sockets, where a caster sees a main-hand oil socket while an oil is in the bags or on the weapon; and the major cooldowns burn on the rim. Every form's choice is built out of combat, so a shift only shows one; aura slots, cooldown duration objects and the engine's shown animations draw the timers, so Lua never reads or compares a secret.
local _, ns = ...
if select(2, UnitClass("player")) ~= "DRUID" then
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
local LEAVES, LEAF, UNFURL = 8, 14, 0.35
local DASH, BARKSKIN = { spells = { 1850, 9821 } }, { spells = { 22812 } }

local maul, bloom = {}, nil
local Oil, Flask, Ring, Gem = ns.SlabVigil.Oil, ns.SlabVigil.Flask, ns.SlabVigil.Ring, ns.SlabVigil.Gem
local Join = ns.SlabTrackers.Joined

local function Effect(spells, color, filter, forms, seat)
	return { feed = "aura", unit = "target", filter = filter or "HARMFUL|PLAYER", spells = spells, color = color, forms = forms, seat = seat }
end

local function Bloom(parent, spec, level, form)
	if form == "row" then
		return Medals.Medal(parent, { feed = "aura", spells = CLEARCASTING, texture = spec.texture, color = "pipDruidGlow", burst = spec.burst }, level)
	end
	local r = Medals.Rim(parent, { feed = "aura", spells = CLEARCASTING, ambient = "medAmbientDruid", burst = spec.burst }, level)
	r.ring, r.leaves = {}, Medals.Layer(r.lit, level + 2)
	r.unfurl = r.leaves:CreateAnimationGroup()
	local grow = r.unfurl:CreateAnimation("Scale")
	grow:SetScaleFrom(0.6, 0.6)
	grow:SetScaleTo(1, 1)
	grow:SetDuration(UNFURL)
	ns.Slab.Fade(r.unfurl, 0, 1, UNFURL)
	for k = 1, LEAVES do
		local leaf = r.add(r.leaves:CreateTexture(nil, "OVERLAY"), LEAF)
		leaf:SetTexture((K.Tokens.Texture("trackerLeaf")))
		leaf:SetBlendMode("ADD")
		leaf.angle = (k - 0.5) * 360 / LEAVES
		leaf:SetRotation(-math.rad(leaf.angle))
		r.ring[k] = leaf
	end
	bloom = r
	return r
end

local function Unfurl(_, full)
	local lit = bloom and bloom.lit
	if not (lit and lit.container) or bloom.full == full or Medals.Restricted() then
		return
	end
	if full then
		lit:AddAuraShownAnimation(bloom.unfurl)
	elseif bloom.full then
		lit:RemoveAuraShownAnimation(bloom.unfurl)
		bloom.unfurl:Stop()
	end
	bloom.full = full
end

local function Emblem(parent, spec, level, form)
	return (form == "crest" and Medals.Emblem or Medals.Medal)(parent, spec, level)
end

local function Maul(parent, spec, level, form)
	local s = Gem(parent, spec, level, form)
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
	choice.color, choice.build = choice.color or "schoolNature", choice.build or Gem
	return choice
end

ns.SlabTrackers.Register("DRUID", {
	{ key = "crestSeeds", seat = "left", choices = {
		Effect(ROAR, "jewelCombo", nil, BEAR),
		{ forms = CAT, color = "white", known = Join(RAKE, POUNCE), feeds = { Effect(POUNCE, "jewelCombo"), Effect(RAKE, "jewelCombo") } },
		{ forms = Join(CASTER, MOONKIN), color = "white", known = Join(MOONFIRE, REJUVENATION), feeds = { Effect(MOONFIRE, "totemAir"), Effect(REJUVENATION, "schoolArcane", "HELPFUL|PLAYER") } },
	} },
	{ key = "crestSeeds", seat = "right", choices = {
		Effect(FAERIE, "schoolArcane", nil, BEAR), Effect(RIP, "jewelCombo", nil, CAT),
		{ forms = Join(CASTER, MOONKIN), color = "white", known = Join(SWARM, REGROWTH), feeds = { Effect(SWARM, "jewelHawk"), Effect(REGROWTH, "schoolNature", "HELPFUL|PLAYER") } },
	} },
	{ key = "crestThird", seat = "top", choices = {
		{ forms = CASTER, color = "white", known = Join(FAERIE, GROWTH), feeds = { Effect(FAERIE, "schoolArcane"), Effect(GROWTH, "schoolNature", "HELPFUL|PLAYER") } },
		Effect(FAERIE, "schoolArcane", nil, MOONKIN), Gems(Effect(FAERIE, "schoolArcane", nil, CAT, "lowerLeft")),
	} },
	{ key = "crestGrowl", seat = "footLeft", size = Medals.FOOT, feed = "cooldown", known = GROWL, forms = BEAR },
	{ key = "crestCharge", seat = "footRight", size = Medals.FOOT, feed = "cooldown", known = CHARGE, forms = BEAR },
	{ key = "crestBite", seat = "lowerLeft", feed = "cooldown", known = BITE, forms = BEAR, color = "jewelCombo", build = Gem },
	{ key = "crestBash", seat = "lowerRight", feed = "cooldown", known = BASH, forms = BEAR, color = "jewelCombo", build = Gem },
	{ key = "crestOil", seat = "lowerRight", feed = "enchant", slot = "MainHand", known = Oil, forms = Join(CASTER, MOONKIN), color = "jewelHoly", build = Flask },
	{ key = "crestClearcasting", seat = "rim", known = OMEN, spells = CLEARCASTING, build = Bloom, place = Ring },
	{ key = "crestSwiftmend", seat = "topGem", feed = "cooldown", choices = {
		Gems({ forms = BEAR, known = MAUL, color = "jewelCombo", build = Maul }),
		Gems({ forms = MOONKIN, known = { 17116 } }), Gems({ forms = MOONKIN, known = { 29166 } }),
		Gems({ forms = CASTER, known = { 18562 } }), Gems({ forms = CASTER, known = { 17116 } }), Gems({ forms = CASTER, known = { 29166 } }),
	} },
	{ key = "crestTankGlow", seat = "rim", feed = "threat", build = Emblem, color = "gilt", forms = BEAR, known = { 9634, 5487 } },
	{ key = "crestCooldowns", seat = "cooldowns", color = "pipDruidGlow", choices = {
		{ forms = BEAR, families = { { spells = { 22842 } }, { spells = { 5229 } }, BARKSKIN, DASH } },
		{ forms = CAT, families = { DASH, BARKSKIN } },
		{ families = { { spells = { 29166 } }, { spells = { 17116 } }, BARKSKIN, DASH, { spells = { 16689, 16810, 16811, 16812, 16813, 17329 } } } },
	} },
}, { burst = "medBurstDruid", fiveSecondForms = Join(CASTER, MOONKIN), events = { "CURRENT_SPELL_CAST_CHANGED" }, update = { "BAG_UPDATE_DELAYED", "WEAPON_ENCHANT_CHANGED" }, paint = Queued, motion = Unfurl })
