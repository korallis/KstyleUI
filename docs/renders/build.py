"""Build portable desktop and phone galleries after running render.py with Blender."""
import base64
from pathlib import Path

HERE = Path(__file__).resolve().parent
CLASSES = [
    ('Hunter', 'The aura kit is on staging; further hunter conversion is in progress.'),
    ('Mage', 'Mage glyph and sigil auras are on staging; some rail spells still need auras.'),
    ('Warlock', 'Warlock glyph and sigil auras are on staging; some rail spells still need auras.'),
    ('Warrior', 'Warrior crest object and sigil aura work is on staging.'),
    ('Paladin', 'Paladin crest object and sigil aura work is on staging.'),
    ('Rogue', 'Rogue crest object and sigil aura work is on staging.'),
    ('Priest', 'The newer priest figure and sigil aura conversion is in review, not on staging.'),
    ('Druid', 'The newer druid figure and sigil aura conversion is in review, not on staging.'),
    ('Shaman', 'The newer shaman figure and sigil aura conversion is in review, not on staging.'),
]

style = '''
:root{color-scheme:dark;background:#0d1119;color:#eee6d4;font-family:system-ui,sans-serif}
*{box-sizing:border-box}body{margin:0}header,main,footer{max-width:1150px;margin:auto;padding:24px}
header{padding-top:50px}h1,h2{font-family:Georgia,serif;color:#f3d69b}h1{font-size:clamp(2rem,6vw,4rem);margin:.2em 0}
p{line-height:1.6;color:#d3cfc5}.eyebrow{text-transform:uppercase;letter-spacing:.16em;color:#dbb76e;font-size:.75rem}
nav{display:flex;flex-wrap:wrap;gap:10px;margin:24px 0}a{color:#f3d69b}nav a{border:1px solid #6f5a38;border-radius:30px;padding:8px 14px;text-decoration:none}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,300px),1fr));gap:18px}
article{background:#161c27;border:1px solid #4a402e;border-radius:12px;overflow:hidden}article img{display:block;width:100%;height:auto}article div{padding:0 20px 18px}article h2{margin:.4em 0}article p{margin:.5em 0}footer{border-top:1px solid #4a402e}
'''

cards = []
for name, status in CLASSES:
    data = base64.b64encode((HERE / 'media' / (name.lower() + '.png')).read_bytes()).decode('ascii')
    cards.append(f'<article id="{name.lower()}"><img src="data:image/png;base64,{data}" alt="Static {name} crest texture rendered in Blender"><div><h2>{name}</h2><p>{status}</p><p>Image: static crest texture, not an animated aura.</p></div></article>')
nav = ''.join(f'<a href="#{name.lower()}">{name}</a>' for name, _ in CLASSES)
page = f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>KstyleUI class crest renders</title><style>{style}</style></head><body><header><span class="eyebrow">KstyleUI · Artwork</span><h1>Class crest renders</h1><p>Nine class crests from the current project. These are new Blender renders of existing flat crest textures, not new three-dimensional crest models or demonstrations of animated auras.</p><p>Artwork status reflects staging at the time this page was made; in-progress changes are not a claim of completed classes.</p><nav aria-label="Jump to a class">{nav}</nav></header><main><div class="grid">{''.join(cards)}</div></main><footer><p>These stills do not show movement or prove in-game behaviour. The standalone phone copy includes its images.</p></footer></body></html>'''
for filename, heading in (('index.html', 'Class crest renders'), ('phone.html', 'Class crest renders — phone')):
    (HERE / filename).write_text(page.replace('<h1>Class crest renders</h1>', f'<h1>{heading}</h1>'), encoding='utf-8')
print('Standalone page bytes:', len(page.encode('utf-8')))
