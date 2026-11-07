# Generates KstyleUI v3 mockups: 3 scenes x 9 classes via the higgsfield CLI, in parallel.
import json, subprocess, sys, re
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

SP = Path("/private/tmp/claude-501/-Users-lee/1c722721-459a-44d5-9d89-4921154ab7a5/scratchpad")
OUT = SP / "mockups" / "v3"
SHEET = SP / "mockups" / "05_kit_hunter.png"
WORLD = {
    "leveling": SP / "refs" / "ref_leveling_riverglades.jpg",
    "dungeon": SP / "refs" / "ref_dungeon_hallofthanes.jpg",
    "pvp": SP / "mockups" / "v2_pvp.png",
}
STYLE = (SP / "mockups" / "style.txt").read_text().strip()

C = {
 "warrior": dict(name="Warrior", hex="#C69B6D", race="orc warrior in heavy plate with a two-handed axe", res="a red Rage bar", cast="Slam",
   ess=["Mortal Strike","Overpower","Whirlwind","Execute","Bloodrage","Recklessness"], util=["Intercept","Pummel","Intimidating Shout","Berserker Rage"],
   buffs=["Battle Shout","Enrage"], pet=None, role="the tank, holding the boss", pvpcast="Hamstring"),
 "paladin": dict(name="Paladin", hex="#F48CBA", race="dwarf paladin in gleaming plate with a mace and shield", res="a blue Mana bar", cast="Holy Light",
   ess=["Judgement","Hammer of Justice","Consecration","Divine Protection","Lay on Hands","Blessing of Freedom"], util=["Blessing of Protection","Cleanse","Divine Favor","Hammer of Wrath"],
   buffs=["Seal of Righteousness","Blessing of Might"], pet=None, role="the healer", pvpcast="Flash of Light"),
 "hunter": dict(name="Hunter", hex="#AAD372", race="troll hunter in mail armour with a bow and a large pet wolf", res="a blue Mana bar", cast="Aimed Shot",
   ess=["Aimed Shot","Multi-Shot","Arcane Shot","Rapid Fire","Concussive Shot","Feign Death"], util=["Freezing Trap","Scatter Shot","Bestial Wrath","Intimidation"],
   buffs=["Aspect of the Hawk","Rapid Fire"], pet="Wolf", role="a ranged damage dealer", pvpcast="Aimed Shot"),
 "rogue": dict(name="Rogue", hex="#FFF468", race="undead rogue in dark leather with twin daggers", res="a yellow Energy bar with five combo point pips", cast=None,
   ess=["Kick","Gouge","Kidney Shot","Evasion","Blade Flurry","Adrenaline Rush"], util=["Sprint","Vanish","Blind","Cold Blood"],
   buffs=["Slice and Dice","Blade Flurry"], pet=None, role="a melee damage dealer", pvpcast=None),
 "priest": dict(name="Priest", hex="#FFFFFF", race="night elf priestess in white and gold robes with a staff", res="a blue Mana bar", cast="Greater Heal",
   ess=["Power Word: Shield","Mind Blast","Psychic Scream","Fade","Inner Focus","Desperate Prayer"], util=["Dispel Magic","Fear Ward","Power Infusion","Shadow Word: Death"],
   buffs=["Inner Fire","Power Word: Fortitude"], pet=None, role="the healer", pvpcast="Mind Blast"),
 "shaman": dict(name="Shaman", hex="#0070DD", race="orc shaman in mail armour with a spiked mace, crackling with lightning", res="a blue Mana bar", cast="Lightning Bolt",
   ess=["Earth Shock","Stormstrike","Chain Lightning","Grounding Totem","Elemental Mastery","Nature's Swiftness"], util=["Frost Shock","Purge","Tremor Totem","Mana Tide Totem"],
   buffs=["Lightning Shield","Windfury Weapon"], pet=None, role="the healer", pvpcast="Healing Wave"),
 "mage": dict(name="Mage", hex="#3FC7EB", race="human mage in flowing violet and blue robes, casting frost", res="a blue Mana bar", cast="Frostbolt",
   ess=["Frost Nova","Blink","Cone of Cold","Counterspell","Ice Block","Evocation"], util=["Polymorph","Ice Barrier","Cold Snap","Presence of Mind"],
   buffs=["Arcane Intellect","Ice Barrier"], pet=None, role="a ranged damage dealer", pvpcast="Polymorph"),
 "warlock": dict(name="Warlock", hex="#8788EE", race="undead warlock in dark purple robes with a felhunter demon pet (a four-legged demon hound with tentacles, not a dragon)", res="a blue Mana bar", cast="Shadow Bolt",
   ess=["Death Coil","Howl of Terror","Shadowburn","Spell Lock","Fear","Soul Fire"], util=["Curse of Agony","Drain Life","Life Tap","Healthstone"],
   buffs=["Demon Armor","Shadow Trance"], pet="Felhunter", role="a ranged damage dealer", pvpcast="Fear"),
 "druid": dict(name="Druid", hex="#FF7C0A", race="tauren druid in leather and antlers, glowing with nature magic", res="a blue Mana bar", cast="Healing Touch",
   ess=["Swiftmend","Nature's Swiftness","Innervate","Barkskin","Bash","Faerie Fire"], util=["Rebirth","Tranquility","Abolish Poison","Dash"],
   buffs=["Rejuvenation","Mark of the Wild"], pet=None, role="the healer", pvpcast="Entangling Roots"),
}

LAYOUT = """HUD LAYOUT (match exactly, 16:9):
- ACTION BARS ARE SMALL AND COMPACT: bottom centre, exactly two rows of 12 small square chamfered action buttons. Each button is small, about 2.2 percent of the screen width (about 42 pixels on a 1920-pixel-wide screen), with 3-pixel gaps. Both rows together span only about 28 percent of the screen width and about 9 percent of the screen height. NO text labels under the buttons: only a tiny keybind in each button's top-right corner, stack counts and cooldown numbers. Icons are KstyleUI icon set A: white light-sculpture art tinted in the CLASS COLOUR.
- COOLDOWN MANAGER directly above the action bars, centred: one row of 6 slightly larger square chamfered icons (Essential Cooldowns: {ess}) with dark radial cooldown sweeps and countdown numbers on four of them and two ready icons with a soft class-colour glow; directly beneath that row, a row of 4 smaller icons (Utility Cooldowns: {util}). To the left of the essential row, two slim tracked buff bars, each with a tiny icon, the buff name ({buffs}) and remaining seconds.
- PLAYER FRAME on the left side of the cooldown manager and TARGET FRAME on the right side of it, on the same line, forming one compact centred HUD band; each has a round portrait with a level badge, a health bar with large percentage numerals, and a thin resource bar. {castline}
- Top-right: SQUARE minimap with small chamfered corners and a class-colour hairline frame, the zone name and clock on a strip INSIDE its bottom edge, a column of small monochrome round-cornered icon buttons down its LEFT side. Under the minimap, a neat row of small square buff icons with durations.
- Bottom-left: compact smoked-glass chat panel with tabs, the active tab underlined in the class colour. Bottom-right: slim data strip with FPS, latency, gold, durability and time.
- Floating combat text numbers in the KstyleUI font rise from the target (damage) and the player (heals).
The 3D world must stay dominant: the UI uses only the edges and the compact centre-bottom band."""

def scene_prompt(scene, k, follower=False):
    c = C[k]
    cast = c["cast"] if scene != "pvp" else c["pvpcast"]
    castline = f"A slim player cast bar reading '{cast}' with a light sheen sits centred just above the cooldown manager." if cast else "No cast bar (instant abilities); show five combo point pips under the player frame."
    lay = LAYOUT.format(ess=", ".join(c["ess"]), util=", ".join(c["util"]), buffs=" and ".join(c["buffs"]), castline=castline)
    pet = f" A small pet frame for the {c['pet']} sits under the player frame." if c["pet"] else ""
    head = {
      "leveling": f"Realistic third-person World of Warcraft: Forever gameplay screenshot at 1440p in the Riverglades zone, matching the art style, lighting and terrain of reference image 2: a level 38 {c['race']} fights a Riverglade Crocolisk at the river's edge. The player is a {c['name']}; resource: {c['res']}.{pet} Also show a slim XP bar between the action bar rows and the cooldown manager, and a compact quest tracker on the right under the minimap buffs with two quests and progress counts.",
      "dungeon": f"Realistic third-person World of Warcraft: Forever gameplay screenshot at 1440p inside the Hall of Thanes dungeon, matching the art style and lighting of reference image 2: a party of five fights the molten boss Magmatus and a Dark Iron Summoner. The player is a {c['race']} ({c['name']}), playing {c['role']}; resource: {c['res']}.{pet} Also show: five compact party frames with round portraits down the left edge (class-coloured health bars, invented player names that are NOT famous Warcraft characters), boss and add health bars at top centre with a boss cast bar 'Molten Pulse', and compact threat and damage meter panels at the right edge above the data strip.",
      "pvp": f"Realistic third-person World of Warcraft: Forever gameplay screenshot at 1440p in the Darkspear Islands battleground, matching the world art, palette and composition of reference image 2 (but NOT its UI sizes): Horde and Alliance players clash on a sunset shore with wooden huts and ships. The player is a {c['race']} ({c['name']}); resource: {c['res']}.{pet} Also show: a battleground score and base strip at top centre, class-coloured enemy player nameplates with small crowd-control timers (Fear, Polymorph), a focus frame at upper left showing an enemy priest's 'Greater Heal' cast marked INTERRUPTED, and four compact friendly team frames down the left edge.",
    }[scene]
    follow = ("\nReference image 3 is the approved layout master for this scene: copy its HUD layout, element positions and element sizes exactly "
              "(compact two-row action bars, the cooldown manager rows, the player and target frames beside it, minimap, chat, meters), but replace the player character, "
              f"class colour, abilities, icons, resource bar and names with the {c['name']} described here. Do not copy the master's character or its colour.") if follower else ""
    return f"{head}\nCLASS COLOUR: {c['name']} {c['hex']}. {lay}\nThe UI components must match reference image 1 (the KstyleUI design-system sheet) exactly, recoloured to {c['hex']}.{follow}\n{STYLE}"

def run(scene, k, refs):
    name = f"{scene}_{k}"
    prompt = scene_prompt(scene, k, follower=len(refs) > 2)
    import os
    if os.environ.get("EXTRA"):
        prompt += "\n" + os.environ["EXTRA"]
    (OUT / f"{name}.prompt").write_text(prompt)
    cmd = ["higgsfield", "generate", "create", "gpt_image_2_5", "--prompt", prompt, "--aspect_ratio", "16:9",
           "--resolution", "2k", "--quality", "high", "--wait", "--wait-timeout", "20m", "--json"]
    for r in refs:
        cmd += ["--image-references", str(r)]
    p = subprocess.run(cmd, capture_output=True, text=True)
    (OUT / f"{name}.json").write_text(p.stdout)
    m = re.search(r'"result_url":\s*"([^"]+)"', p.stdout)
    if not m:
        return name, None, p.stderr[-400:]
    url = m.group(1)
    subprocess.run(["curl", "-sSL", "-o", str(OUT / f"{name}.png"), url], check=True)
    return name, url, ""

if __name__ == "__main__":
    mode = sys.argv[1]
    jobs = []
    if mode == "masters":
        for scene, k in (("leveling", "shaman"), ("dungeon", "paladin"), ("pvp", "warlock")):
            jobs.append((scene, k, [SHEET, WORLD[scene]]))
    else:
        masters = {"leveling": "shaman", "dungeon": "paladin", "pvp": "warlock"}
        only = sys.argv[2:]  # optional list of scene_class names to (re)run
        for scene, mk in masters.items():
            for k in C:
                if k == mk: continue
                n = f"{scene}_{k}"
                if only and n not in only: continue
                jobs.append((scene, k, [SHEET, WORLD[scene], OUT / f"{scene}_{mk}.png"]))
    with ThreadPoolExecutor(max_workers=8) as ex:
        for name, url, err in ex.map(lambda j: run(*j), jobs):
            print(name, url or ("FAILED " + err))
