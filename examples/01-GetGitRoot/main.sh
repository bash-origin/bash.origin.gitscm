#!/usr/bin/env bash.origin.script

depend {
    "gitscm": "@../..#s1"
}

echo "Git root: $(CALL_gitscm get_git_root)"

echo "OK"
