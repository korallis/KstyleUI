rv () 
{ 
    n=$1;
    sha=$2;
    base=$3;
    spec=$4;
    rep=$5;
    sed -e "s/PRN/$n/g" -e "s/SHORT/${sha:0:8}/g" -e "s/SHA/$sha/g" -e "s/BASE/$base/g" -e "s/SPEC/$spec/g" -e "s|REPORT|$rep|g" specs/_verify-audit.tmpl > specs/verify-$n.md;
    cat specs/verify-$n.md specs/_footer.md > specs/_tmp-$n.md;
    node "C:/Users/leeba/orca-jev-router/orca-route.mjs" dispatch --spec-file specs/_tmp-$n.md --worktree new-child --avoid "${AVOID:?set AVOID to the author family}" 2>&1 | grep -o -E '"(agent|dispatchId)": *"[^"]+"' | head -2 | paste - -;
    rm -f specs/_tmp-$n.md
}
