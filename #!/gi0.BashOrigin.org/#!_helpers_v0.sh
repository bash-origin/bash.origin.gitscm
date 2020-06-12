#!/usr/bin/env bash.origin.script

function EXPORTS_get_head_rev {
    git rev-parse HEAD
}

function EXPORTS_get_git_root {
    if [ -z "$1" ]; then
        cwd="$(pwd)"
    else
        cwd="$1"
    fi
    if [ -f "$cwd/HEAD" ]; then
        echo -n "$cwd"
        return 0
    elif [ -d "$cwd/.git" ]; then
        echo -n "$cwd/.git"
        return 0
    elif [ -f "$cwd/.git" ]; then
        EXPORTS_get_git_root "$cwd/$(cat $cwd/.git | perl -pe 's/^gitdir:\s+(.+?)$/$1/')"
        return $?
    else
        EXPORTS_get_git_root "$(dirname $cwd)"
        return $?
    fi
    return 1;
}

function EXPORTS_get_closest_parent_git_root {
    if [ -z "$1" ]; then
        cwd="$(pwd)"
    else
        cwd="$1"
    fi
    if [ -e "$cwd/.git" ]; then
        echo -n "$cwd/.git"
        return 0
    else
        EXPORTS_get_closest_parent_git_root "$(dirname $cwd)"
    fi
    return 1;
}

function EXPORTS_get_branch {
    git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/' -e 's/\//_/'
}

# @source http://stackoverflow.com/a/3879077/330439
# @see https://stackoverflow.com/a/2659808
function EXPORTS_is_clean {

    if BO_has_cli_arg "--ignore-dirty" || BO_has_cli_arg "--ignore-dirt"; then
        [ -z "$BO_VERBOSE" ] || echo "[bash.origin.test][run.sh] is_pwd_working_tree_clean() 'true' due to --ignore-dirt[y] ($(pwd))"
        return 0
    fi

    # TODO: Optionally only stop if sub-path is dirty?

    # Update the index
    git update-index -q --ignore-submodules --refresh

    # Disallow unstaged changes in the working tree
    if ! git diff-files --quiet --ignore-submodules --; then
        [ -z "$BO_VERBOSE" ] || echo "[bash.origin.test][run.sh] is_pwd_working_tree_clean() 'false' due to unstaged changes ($(pwd))"
        return 1
    fi

    # Disallow uncommitted changes in the index
    if ! git diff-index --quiet --cached HEAD --ignore-submodules --; then
        [ -z "$BO_VERBOSE" ] || echo "[bash.origin.test][run.sh] is_pwd_working_tree_clean() 'false' due to uncomitted changes ($(pwd))"
        return 1
    fi

    # Disallow untracked files
    pushd "$(dirname $(EXPORTS_get_closest_parent_git_root))" > /dev/null
        untracked=$(git ls-files --exclude-standard --others --error-unmatch 2>&1)
    popd > /dev/null
    if [ "$untracked" != "" ]; then
        [ -z "$BO_VERBOSE" ] || echo "[bash.origin.test][run.sh] is_pwd_working_tree_clean() 'false' due to untracked files ($(pwd))"
        return 1
    fi

    [ -z "$BO_VERBOSE" ] || echo "[bash.origin.test][run.sh] is_pwd_working_tree_clean() 'true' due to all clean ($(pwd))"
    return 0
}

function EXPORTS_ensure_remote {
    if ! git config remote.$1.url > /dev/null; then
        git remote add $1 $2
    fi
}

function EXPORTS_ensure_local_excludes {
    local repoPath="$(EXPORTS_get_git_root)"

    if [ -f "$repoPath/HEAD" ]; then
        if [ ! -d "${repoPath}/info" ]; then
            mkdir "${repoPath}/info"
        fi
        local excludeFilePath="${repoPath}/info/exclude"
        if [ ! -e "${excludeFilePath}" ]; then
            touch "${excludeFilePath}"
        fi
        # Ensure trailing newline
        # @source http://stackoverflow.com/a/16198793/330439
        [[ $(tail -c1 "$excludeFilePath") && -f "$excludeFilePath" ]] && echo '' >> "$excludeFilePath"
        BO_log "$VERBOSE" "Checking rule '^${2}$' against exclude file: '$excludeFilePath'"
        if ! grep -qe "^${2}$" "$excludeFilePath"; then
            BO_log "$VERBOSE" "Append '${3}' to exclude file: '$excludeFilePath'"
            echo -e "${3}" >> "$excludeFilePath"
        fi

        return 0
    fi

    echo "[bash.origin.gitscm] TODO: Implement [ref: 02jnd763hflsi]"
    return 1
}

function EXPORTS_ensure_cloned_commit {

    finalClonePath="$1"
    gitRemoteUrl="$2"
    checkoutRef="$3"
    cacheClonePath="$__RT_DIRNAME__/clones/_$(BO_replace "$gitRemoteUrl" "^.+\\/([^\\/]+)\$")_$(BO_hash "$gitRemoteUrl")"

    set +e
    if [ ! -e "$cacheClonePath" ]; then
        BO_ensure_parent_dir "$cacheClonePath"
        local tmpCacheClonePath="$cacheClonePath~.tmp"
        rm -Rf "$tmpCacheClonePath" || true
        git clone "$gitRemoteUrl" "$tmpCacheClonePath"
        mv "$tmpCacheClonePath" "$cacheClonePath"
    fi

    if [ ! -e "$finalClonePath" ]; then
        BO_ensure_parent_dir "$finalClonePath"

        local tmpFinalClonePath="$finalClonePath~.tmp"
        rm -Rf "$tmpFinalClonePath" || true

        git clone "file://$cacheClonePath/.git" "$tmpFinalClonePath"
        pushd "$tmpFinalClonePath" > /dev/null
            git remote rm origin
            git remote add origin "$gitRemoteUrl"
            git fetch origin
            git remote add cache "file://$cacheClonePath/.git"
        popd > /dev/null
        mv "$tmpFinalClonePath" "$finalClonePath"
    fi

    pushd "$finalClonePath" > /dev/null
        git checkout --track "origin/$checkoutRef" 2> /dev/null || ( \
            git checkout -b "$checkoutRef" 2> /dev/null || \
            git checkout "$checkoutRef" 2> /dev/null \
        )
        git pull origin "$checkoutRef" 2> /dev/null
    popd > /dev/null
    set -e
}
