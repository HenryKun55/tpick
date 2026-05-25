#!/usr/bin/env bash
# Wrapper used by tpick's fzf binds (Ctrl-N, Ctrl-X) so that Ctrl-C inside
# a helper script only kills the helper — not fzf.
#
# How it works: Ctrl-C sends SIGINT to every process in the foreground process
# group. The child ("$@") still receives it and reacts normally. This wrapper
# ignores SIGINT/SIGTERM in itself, so it won't die alongside the child; once
# the child exits, control returns cleanly to fzf.
trap '' INT TERM
"$@"
