# _locfix.py <old_head>: in a rebased checkout, restore staging's translation wherever the PR did not change that key itself.
import json, subprocess, sys
old = sys.argv[1]
def git(*a): return subprocess.run(['git', *a], capture_output=True, encoding='utf8').stdout
base = git('merge-base', old, 'origin/staging').strip()
def load(rev, p):
	t = git('show', f'{rev}:{p}')
	return json.loads(t) if t else {}
total = 0
for lang in ['deDE', 'esES', 'frFR', 'zhCN']:
	p = f'Tools/locale/{lang}.json'
	raw = open(p, encoding='utf8').read(); cur = json.loads(raw)
	stg, o, b = load('origin/staging', p), load(old, p), load(base, p)
	fixed = [k for k, v in stg.items() if k in cur and cur[k] != v and o.get(k) == b.get(k)]
	for k in fixed: cur[k] = stg[k]
	total += len(fixed)
	if fixed:
		print(lang, fixed)
		open(p, 'w', encoding='utf8', newline='\n').write(json.dumps({k: cur[k] for k in sorted(cur)}, ensure_ascii=False, indent='\t') + ('\n' if raw.endswith('\n') else ''))
print('restored', total)
