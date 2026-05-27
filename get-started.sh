#!/usr/bin/env bash
: <<DOCXX
Add description
Author: morgan@morganism.dev
Date: Wed 27 May 2026 20:26:53 BST
DOCXX

[[ -e "portablework.tar.gz" ]] && tar xzf portablework.tar.gz && cd portable-workspace

[[ -e "scripts/setup.sh" ]] && chmod +x scripts/setup.sh scripts/sync.sh
./scripts/setup.sh
open https://localhost:4567
