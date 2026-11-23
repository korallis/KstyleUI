# relocale <PR>: rebase a PR branch onto origin/staging, resolving only locale conflicts (union of both sides' strings, then strings.py sync).
# Pushes with --force-with-lease to the PR branch. Stops if any non-locale file conflicts.
relocale() {
	local n=$1 root=/c/Projects/KstyleUI wt=/c/Users/leeba/.cache/wt-reloc-$1 br old
	br=$(cd $root && gh pr view $n --json headRefName --jq .headRefName)
	old=$(cd $root && gh pr view $n --json headRefOid --jq .headRefOid)
	(cd $root && git fetch -q origin && rm -rf $wt && git worktree add -q $wt -B tmp-reloc-$n origin/$br) || return 1
	cd $wt || return 1
	git rebase origin/staging >/dev/null 2>&1
	while [ -d .git/rebase-merge ] || [ -d "$(git rev-parse --git-path rebase-merge)" ]; do
		for u in docs/feature-map.md Tools/render/README.md; do  # doc rows added on both sides: keep both
			git diff --name-only --diff-filter=U | grep -qx "$u" || continue
			git show :1:$u > /tmp/fm1; git show :2:$u > /tmp/fm2; git show :3:$u > /tmp/fm3
			git merge-file --union -p /tmp/fm2 /tmp/fm1 /tmp/fm3 > $u && git add $u
		done
		local other; other=$(git diff --name-only --diff-filter=U | grep -v -E '^(Core/Locales/|Tools/locale/)')
		[ -n "$other" ] && { echo "#$n non-locale conflict: $other"; git rebase --abort; cd $root; git worktree remove --force $wt; git branch -D -q tmp-reloc-$n; return 1; }
		python -I - <<'EOF'
import json,subprocess
def show(s,p): return subprocess.run(['git','show',f':{s}:{p}'],capture_output=True,encoding='utf8').stdout
for lang in ['deDE','enUS','esES','frFR','zhCN']:
    p=f'Tools/locale/{lang}.json'
    if subprocess.run(['git','diff','--name-only','--diff-filter=U','--',p],capture_output=True,text=True).stdout.strip()=='' : continue
    ra,rb,r1=show(2,p),show(3,p),show(1,p); a,b=json.loads(ra),json.loads(rb); o=json.loads(r1) if r1 else {}
    if isinstance(a,list): m=sorted(set(a)|set(b))
    else:
        u={**a,**b}; u.update({k:v for k,v in a.items() if b.get(k)==o.get(k) or (u[k]==k and v!=k)})  # three-way: the PR's value wins only where the PR changed it
        m={k:u[k] for k in sorted(u)}
    open(p,'w',encoding='utf8',newline='\n').write(json.dumps(m,ensure_ascii=False,indent='\t')+('\n' if ra.endswith('\n') else ''))
EOF
		for l in deDE esES frFR zhCN; do git diff --name-only --diff-filter=U | grep -q "Core/Locales/$l.lua" && git checkout --ours -- Core/Locales/$l.lua; done
		python3 Tools/locale/strings.py sync >/dev/null 2>&1
		python3 Tools/dev/crlf.py Core/Locales/deDE.lua Core/Locales/esES.lua Core/Locales/frFR.lua Core/Locales/zhCN.lua >/dev/null 2>&1
		git add Core/Locales Tools/locale && GIT_EDITOR=true git rebase --continue >/dev/null 2>&1 || true
	done
	python3 Tools/locale/strings.py check >/dev/null 2>&1 || { echo "#$n locale check failed"; cd $root; return 1; }
	lua5.1 Tools/regression/test-syntax.lua >/dev/null 2>&1 || { echo "#$n syntax failed"; cd $root; return 1; }
	local new; new=$(git rev-parse HEAD)
	echo "#$n rebased: $old -> $new"
	cd $root
	echo "$br $old $new"
}
