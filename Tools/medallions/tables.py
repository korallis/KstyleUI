"""The Medallions prompts table: which race and class combinations exist, and the fixed text every prompt is built from.

Keys are the game's own tokens lowercased: the race file UnitRace returns, the class file UnitClass returns, and the
sex as "male" or "female" (UnitSex 2 and 3). Prompts never name a race, place or faction of the game's setting; the
race file names are internal keys only. KSTY-87 section 3 has the race and class matrix and its sources, KSTY-88
section 2 the crest recipe whose blocks are kept here word for word.
"""

RACES = ("human", "dwarf", "nightelf", "gnome", "orc", "scourge", "tauren", "troll", "skyborne")
CLASSES = ("warrior", "paladin", "priest", "shaman", "druid", "rogue", "mage", "warlock", "hunter")
SEXES = ("male", "female")

RACE_FILES = {"human": "Human", "dwarf": "Dwarf", "nightelf": "NightElf", "gnome": "Gnome", "orc": "Orc",
              "scourge": "Scourge", "tauren": "Tauren", "troll": "Troll", "skyborne": "Skyborne"}
UNIT_SEX = {"male": 2, "female": 3}

# Server data, so not in the UI source: Blizzard's published table (KSTY-87 section 3). Skyborne is the union of
# both factions, since Lee ruled one shared heraldry for them (handoffs/medallions/COMMON.md).
VALID = {
    "human": ("hunter", "mage", "paladin", "priest", "rogue", "warlock", "warrior"),
    "dwarf": ("hunter", "paladin", "priest", "rogue", "shaman", "warrior"),
    "nightelf": ("druid", "hunter", "priest", "rogue", "warrior"),
    "gnome": ("mage", "priest", "rogue", "warlock", "warrior"),
    "orc": ("hunter", "mage", "rogue", "shaman", "warlock", "warrior"),
    "scourge": ("mage", "paladin", "priest", "rogue", "warlock", "warrior"),
    "tauren": ("druid", "hunter", "shaman", "warrior"),
    "troll": ("hunter", "mage", "priest", "rogue", "shaman", "warlock", "warrior"),
    "skyborne": ("druid", "hunter", "mage", "rogue", "shaman", "warrior"),
}

# Words no prompt may contain: the setting's trademarks and proper names.
BANNED_WORDS = ("warcraft", "blizzard", "azeroth", "horde", "alliance", "tauren", "forsaken", "scourge", "kaldorei",
                "sindorei", "quel'dorei", "stormwind", "ironforge", "darnassus", "orgrimmar", "undercity",
                "thunder bluff", "gnomeregan", "thrall", "skyborne", "arthas", "sylvanas")


def combos():
    """Every valid (race, class) pair in table order: 52."""
    return [(race, cls) for race in RACES for cls in CLASSES if cls in VALID[race]]


def portrait_keys():
    return [f"{race}_{cls}_{sex}" for race, cls in combos() for sex in SEXES]


def crest_keys():
    return [f"{race}_{cls}" for race, cls in combos()]


def split_key(key):
    parts = key.split("_")
    if len(parts) == 3 and parts[2] in SEXES:
        race, cls, sex = parts
    elif len(parts) == 2:
        (race, cls), sex = parts, None
    else:
        raise ValueError(f"not a medallion key: {key}")
    if race not in VALID or cls not in VALID[race]:
        raise ValueError(f"not a valid race and class: {key}")
    return race, cls, sex


# Portraits ---------------------------------------------------------------------------------------------------------
# The finish Lee approved (KSTY-87 probe-portraits-four.jpg): the anchor's own style block, then the reference line
# the three referenced probes used, then one character sentence built from the race, class and sex below.

BUST_STYLE = (
    "Hand-painted fantasy game portrait icon. Head-and-shoulders bust, three-quarter view turned slightly to the left, "
    "the face filling the central 65 percent of the square so it survives a circular crop. Bold, instantly readable "
    "silhouette; clean crisp edges with no fuzz; a few large shapes, not fine noise. Warm key light from the upper "
    "left, cool cyan rim light on the right edge, strong value contrast on the face and eyes. Saturated but limited "
    "palette. Stylised painterly rendering with sharp edges, like premium MMO class art. Plain deep "
    "charcoal-to-black radial background. No text, no letters, no border, no frame, no ring, no logo, no watermark."
)
BUST_REFERENCE = ("Match the reference image's rendering style, brushwork, lighting, framing and level of detail "
                  "exactly, but paint a completely different character.")

BADGE_PROMPT = (
    "Make a small-size badge version of the first reference portrait, in the flat badge style of the second reference "
    "image: the same character, cropped to the face and the top of the shoulders and centred, simplified into four "
    "or five clear value groups with bold shapes, a strong dark outline around the head, minimal fine detail (no "
    "individual hair strands or fur), high contrast against a plain dark background, so it still reads at 24 pixels. "
    "No text."
)

PEOPLE = {
    "human": {
        "male": "a human man in his prime, weathered and strong-jawed, with short dark hair",
        "female": "a human woman in her prime, keen-eyed and resolute, with dark hair tied back",
    },
    "dwarf": {
        "male": "a stout, broad-shouldered mountain dwarf man with a thick braided copper-red beard bound with metal rings",
        "female": "a stout, sturdy mountain dwarf woman with thick braided auburn hair bound with metal rings and rosy cheeks",
    },
    "nightelf": {
        "male": ("a tall moonlit forest elf man with very long swept-back pointed ears, pale violet skin, long dark "
                 "teal hair and glowing silver eyes"),
        "female": ("a tall moonlit forest elf woman with very long swept-back pointed ears, pale violet skin, long "
                   "midnight-blue hair and glowing silver eyes"),
    },
    "gnome": {
        "male": "a tiny, big-eyed gnome tinkerer man with a large nose, a waxed moustache and wild bright orange hair",
        "female": "a tiny, big-eyed gnome tinkerer woman with freckles and wild bright pink pigtails",
    },
    "orc": {
        "male": "a massive green-skinned orc man with jutting lower tusks, a heavy brow and a black warrior's topknot",
        "female": "a powerful green-skinned orc woman with small jutting lower tusks, fierce eyes and braided black hair",
    },
    "scourge": {
        "male": ("a gaunt undead man risen from the grave, ashen grey-green skin drawn tight over sharp cheekbones, a "
                 "bare jawbone on one side and glowing amber eyes"),
        "female": ("a gaunt undead woman risen from the grave, ashen grey-green skin drawn tight over sharp "
                   "cheekbones, lank dark hair and glowing amber eyes"),
    },
    "tauren": {
        "male": ("a massive, gentle bull-headed minotaur man with broad curved horns wrapped in carved wooden bands, a "
                 "mane of dark brown fur and calm wise eyes"),
        "female": ("a tall bull-headed minotaur woman with gracefully curved horns, long braided hair over soft tawny "
                   "fur and calm wise eyes"),
    },
    "troll": {
        "male": ("a tall, lanky jungle troll man with blue skin, long upturned tusks, long pointed ears and a tall "
                 "swept-up red mohawk"),
        "female": ("a tall, lanky jungle troll woman with teal skin, small upturned tusks, long pointed ears and long "
                   "swept-back violet hair"),
    },
    "skyborne": {
        "male": ("an airy sky-elf man with long swept-back pointed ears and silver-white hair blown by wind, pale skin "
                 "with faint blue tattoo lines on his cheek and wind-shaped feather ornaments in his hair"),
        "female": ("an airy sky-elf woman with long swept-back pointed ears and silver-white hair blown by wind, pale "
                   "skin with faint blue tattoo lines on her cheek and wind-shaped feather ornaments in her hair"),
    },
}

CALLINGS = {
    "warrior": ("warrior, wearing battered steel plate pauldrons over a red tabard, the hilt of a greatsword over the "
                "shoulder, warm ember light from below on one side"),
    "paladin": ("holy knight, wearing polished plate armour with a gilded pauldron engraved with a radiant sun, a faint "
                "golden holy light rising from below"),
    "priest": ("priest, wearing white and gold vestments with a high collar and a thin halo-like circlet, soft "
               "pearl-white holy light around the face"),
    "shaman": ("shaman, wearing a grey wolf-pelt hood and a necklace of carved stone and bone totems, faint blue storm "
               "light crackling in the eyes and around one raised fist"),
    "druid": ("druid, wearing a mantle of antlers, leaves and moss over the shoulders, soft amber and green nature "
              "light glowing on the leaves"),
    "rogue": ("rogue, wearing a dark leather hood and a scarf pulled down from the face, a curved dagger held close, "
              "thin wisps of smoke and a pale gold glint on the blade"),
    "mage": ("mage, wearing a high-collared robe embroidered with arcane sigils, a swirl of glowing icy-cyan arcane "
             "light curling around one shoulder"),
    "warlock": ("warlock, wearing a dark violet robe with horned shoulder pieces and hanging chains, a writhing "
                "sickly green flame floating above one palm"),
    "hunter": ("hunter, wearing a fur-lined leather mantle with hawk feathers, a longbow over the shoulder, soft "
               "moss-green light in the eyes"),
}


def bust_prompt(race, cls, sex):
    return f"{BUST_STYLE} {BUST_REFERENCE} Character: {PEOPLE[race][sex]}, a {CALLINGS[cls]}."


# Crests --------------------------------------------------------------------------------------------------------------
# KSTY-88's recipe: one race master per race (referenced to the crest anchor for style only), then every other
# class of that race as an edit of its master that keeps the frame and replaces the centre emblem.

CREST_STYLE_REFERENCE = (
    "Use the reference image only for its rendering style: the same painterly finish, lighting direction, cool rim "
    "light, level of detail, thin dark outline, straight-on camera, canvas size, placement in the canvas and fully "
    "transparent background. Do not copy its shape, materials, colours or symbols."
)
CREST_HEADER = ("Heraldic crest for a fantasy RPG game interface: one ornate emblem, centred, seen straight on, "
                "isolated on a fully transparent background.")
CREST_FINISH = (
    "Finish: premium hand-painted fantasy game-art icon with rich materials: polished metal edges with specular "
    "highlights, glossy enamel, cut gems catching the light, depth from bevels and recessed engraving, a cool rim light "
    "from the upper left, deep contact shadows. Crisp clean silhouette with a thin dark outline so it still reads at 64 "
    "pixels. The crest fills about 80 percent of the canvas height and is perfectly left-right symmetrical."
)
CREST_EXCLUSIONS = ("No text, no letters, no numbers, no faces, no characters, no scenery, no background, no cast "
                    "shadow outside the crest.")
EDIT_EXCLUSIONS = "No text, no letters, no numbers, no faces, no characters, no scenery, no background."

# The class each race master carries: KSTY-88's Latin square, so each race and each class appears once.
MASTER_CLASS = {"human": "paladin", "dwarf": "shaman", "nightelf": "druid", "gnome": "mage", "orc": "warrior",
                "scourge": "warlock", "tauren": "hunter", "troll": "priest", "skyborne": "rogue"}

HERALDRY = {
    "human": ("human kingdoms", "a classic heater shield of polished silver plate with royal-blue enamel along the "
              "border, fine gold trim, a small gold crown on a laurel wreath on top, a blue sapphire set at each upper "
              "corner"),
    "dwarf": ("mountain dwarf clans", "a broad, squat hexagonal shield of hammered dark bronze framing a slab of carved "
              "grey granite; thick angular knotwork engraved along the bronze border; heavy round rivets; a stylised "
              "mountain peak with a small anvil forged into the top of the frame; two small blood-red garnets set at "
              "the left and right corners"),
    "nightelf": ("moonlit forest elves", "a tall, slender almond-shaped shield like a pointed leaf, framed in pale "
                 "moonsilver with sweeping curved filigree, a deep violet-blue night-sky enamel border dusted with tiny "
                 "silver stars, a slim silver crescent moon rising from the top with a long owl feather curving out to "
                 "each side, a small amethyst at the bottom tip"),
    "gnome": ("gnome tinkerers", "a round shield framed by a polished brass cogwheel with sharp gear teeth, copper "
              "rivets, small curved brass pipes and a tiny pressure gauge at the top, a riveted copper field, a round "
              "sapphire lens at the bottom"),
    "orc": ("orc war clans", "a round war shield of thick riveted dark iron over stretched red-brown hide, a ring of "
            "short iron spikes around the rim and two large curved boar tusks rising from the top, crude bold hammered "
            "shapes, deep red war-paint slashes on the hide, a blood-red stone at the bottom"),
    "scourge": ("the risen undead", "a jagged, cracked kite shield of blackened iron and pale weathered bone, with torn "
                "tattered edges, iron thorns along the rim, rusted rivets, a broken iron crown with snapped points on "
                "top, faint sickly green light leaking from the cracks, a cracked jade stone at the bottom tip"),
    "tauren": ("plains tribes of the great bull-folk", "a circular totemic shield of stretched pale hide in a bent-wood "
               "hoop bound with leather cord, two great curved bull horns sweeping up from the top, eagle feathers and "
               "turquoise beads hanging at the sides, bronze fittings"),
    "troll": ("jungle trolls", "a tall oval mask-shaped shield of carved dark jungle wood and pale bone, painted with "
              "bold teal-turquoise tribal patterns, two large ivory tusks curving up from the bottom, a crest of upright "
              "feathers and hanging carved beads on top, a turquoise stone set at the top centre"),
    "skyborne": ("winged people of the high skies", "a round crest of white gold and pearl with a sky-blue enamel "
                 "border, a pair of feathered white wings spreading wide from the left and right sides, a small "
                 "spiralling cloud with a four-pointed star on top, an aquamarine at the bottom"),
}

# What an edit must keep of each race master, and where the new emblem sits.
FRAME_KEEP = {
    "human": ("the polished silver heater shield, the royal-blue enamel border, the fine gold trim, the small gold "
              "crown on its laurel wreath, the two sapphires", "on the same polished silver field"),
    "dwarf": ("the hammered bronze hexagon, the knotwork border, the rivets, the mountain peak and anvil on top, the two "
              "garnets", "on the same carved grey granite field"),
    "nightelf": ("the almond-shaped moonsilver shield and its curved filigree, the violet-blue starred enamel border, "
                 "the crescent moon and the two owl feathers on top, the amethyst at the tip", "on the same centre field"),
    "gnome": ("the brass cogwheel and its gear teeth, the copper rivets, the brass pipes and pressure gauge on top, the "
              "sapphire lens at the bottom", "on the same riveted copper field"),
    "orc": ("the round riveted dark iron rim, the ring of iron spikes, the two curved boar tusks on top, the stretched "
            "red-brown hide with red war-paint slashes, the blood-red stone at the bottom", "on the same stretched hide"),
    "scourge": ("the cracked kite shield of blackened iron and bone with its torn edges and iron thorns, the rusted "
                "rivets, the broken iron crown on top, the green light in the cracks, the cracked jade at the tip",
                "on the same centre field"),
    "tauren": ("the stretched pale hide in its bent-wood hoop and leather binding, the two great bull horns on top, the "
               "eagle feathers and turquoise beads at the sides, the bronze fittings", "on the same pale hide"),
    "troll": ("the carved dark wood and bone mask shield with its teal tribal paint, the two ivory tusks at the bottom, "
              "the feather crest and carved beads on top, the turquoise stone", "on the same carved wood field"),
    "skyborne": ("the white gold and pearl roundel, the sky-blue enamel border, the spread feathered wings, the cloud "
                 "and four-pointed star on top, the aquamarine at the bottom", "on the same pearl field"),
}

EMBLEMS = {
    "druid": ("druid, keeper of the wild", "a pair of stag antlers cradling a round full moon, with an oak leaf and an "
              "acorn beneath, inlaid in warm amber-orange enamel with a soft orange inner glow"),
    "hunter": ("hunter, master of the wild hunt", "a drawn longbow with a nocked arrow pointing up, crossed over a "
               "spread hawk's wing, inlaid in fresh moss-green enamel with a soft green inner glow"),
    "mage": ("mage, arcane scholar", "a floating six-pointed arcane crystal star ringed by two crossed orbit rings like "
             "an astrolabe, inlaid in bright icy cyan enamel with a bright arcane cyan inner glow"),
    "paladin": ("paladin, holy knight", "a radiant sunburst with a two-handed warhammer standing upright through it, "
                "inlaid in soft rose-pink enamel with a warm pink-gold holy inner glow"),
    "priest": ("priest, voice of the light", "a radiant eight-pointed star inside a halo ring with fine rays, inlaid in "
               "pearl-white enamel with a soft white-gold holy inner glow"),
    "rogue": ("rogue, shadow blade", "two crossed curved daggers beneath a small crescent moon, inlaid in pale "
              "lemon-yellow enamel with a soft pale-gold inner glow and thin wisps of dark smoke"),
    "shaman": ("shaman, storm caller", "a carved stone totem crowned with forked lightning, ringed by four small "
               "elemental runes for earth, fire, water and air, inlaid in deep cobalt-blue enamel with a soft "
               "electric-blue inner glow, and a bright sapphire set at the totem's heart"),
    "warlock": ("warlock, binder of demons", "a horned demonic sigil circle bound by iron chains around a writhing fel "
                "flame, inlaid in deep violet-purple enamel with a sickly fel-green and violet inner glow"),
    "warrior": ("warrior, battle master", "two crossed broad greatswords point-down behind a small round iron boss, "
                "inlaid in warm tan and bronze enamel with a fiery orange ember inner glow"),
}

# What an edit tells the model to drop from the master's emblem. Shaman's and warrior's are KSTY-88's own.
NOT_EMBLEM = {
    "druid": "No antlers, no moon, no amber.",
    "hunter": "No bow, no wing, no green.",
    "mage": "No crystal star, no orbit rings, no cyan.",
    "paladin": "No sunburst, no hammer, no pink.",
    "priest": "No eight-pointed star, no halo, no white glow.",
    "rogue": "No daggers, no crescent, no yellow.",
    "shaman": "No lightning, no blue.",
    "warlock": "No sigil, no chains, no violet or green flame.",
    "warrior": "No swords.",
}

# The class glow the judge expects from the emblem: a hue in degrees, or None for a white glow (priest).
# Warlock also passes on fel green. Tolerances are in imaging.HUE_TOLERANCE.
GLOW_HUES = {"druid": (30,), "hunter": (95,), "mage": (190,), "paladin": (340, 20), "priest": None,
             "rogue": (50,), "shaman": (215,), "warlock": (280, 110), "warrior": (28,)}


def master_key(race):
    return f"{race}_{MASTER_CLASS[race]}"


def is_master(key):
    race, cls, _ = split_key(key)
    return MASTER_CLASS[race] == cls


def master_prompt(race, cls):
    title, heraldry = HERALDRY[race]
    calling, emblem = EMBLEMS[cls]
    return "\n\n".join((CREST_STYLE_REFERENCE, CREST_HEADER, f"Race heraldry ({title}): {heraldry}.",
                        f"Class emblem ({calling}): in the centre field {emblem}.", CREST_FINISH, CREST_EXCLUSIONS))


def edit_prompt(race, cls):
    keep, field = FRAME_KEEP[race]
    calling, emblem = EMBLEMS[cls]
    return "\n\n".join((
        f"Edit the reference crest. Keep its whole outer frame exactly as it is: {keep}, the size, placement, lighting "
        "and transparent background. Replace only the centre field emblem and its colour.",
        f"New class emblem ({calling}): {field}, {emblem}. {NOT_EMBLEM[MASTER_CLASS[race]]}",
        EDIT_EXCLUSIONS))


def crest_prompt(race, cls):
    return master_prompt(race, cls) if MASTER_CLASS[race] == cls else edit_prompt(race, cls)
