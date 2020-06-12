#!/usr/bin/env bash.origin.script

depend {
    "gitscm": "bash.origin.gitscm # helpers/v0"
}

echo "Git root: $(CALL_gitscm get_git_root)"

echo "OK"
