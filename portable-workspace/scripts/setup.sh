#!/usr/bin/env bash
# scripts/setup.sh — First-time setup for PortableWork
set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

step() { echo -e "\n${BLUE}▶${RESET} ${BOLD}$1${RESET}"; }
ok()   { echo -e "  ${GREEN}✓${RESET} $1"; }
warn() { echo -e "  ${YELLOW}⚠${RESET}  $1"; }
err()  { echo -e "  ${RED}✗${RESET} $1"; exit 1; }

echo -e "\n${BOLD}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║     PortableWork Setup v1.0.0        ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════╝${RESET}"

# ── Check dependencies ──────────────────────────────────────────
step "Checking dependencies"

command -v docker >/dev/null 2>&1 && ok "Docker found" || err "Docker not found. Install from https://docker.com"
command -v git    >/dev/null 2>&1 && ok "Git found"    || err "Git not found"

if docker info >/dev/null 2>&1; then
  ok "Docker daemon running"
else
  err "Docker daemon not running. Start Docker Desktop or 'sudo systemctl start docker'"
fi

# ── Generate .env ───────────────────────────────────────────────
step "Environment configuration"

if [ ! -f .env ]; then
  cp .env.example .env
  SECRET=$(ruby -e "require 'securerandom'; puts SecureRandom.hex(64)" 2>/dev/null || \
           openssl rand -hex 64)
  sed -i.bak "s/CHANGE_ME_TO_A_LONG_RANDOM_STRING/${SECRET}/" .env
  rm -f .env.bak
  ok "Created .env with generated session secret"
  warn "Edit .env to add your GitHub token before syncing"
else
  ok ".env already exists"
fi

# ── Generate TLS cert ───────────────────────────────────────────
step "TLS certificate"

mkdir -p config/ssl
if [ ! -f config/ssl/server.key ]; then
  openssl req -x509 -nodes -days 3650 \
    -newkey rsa:2048 \
    -keyout config/ssl/server.key \
    -out    config/ssl/server.crt \
    -subj   "/C=US/ST=Local/L=Local/O=PortableWork/CN=localhost" 2>/dev/null
  ok "Generated self-signed TLS certificate (10 years)"
else
  ok "TLS certificate exists"
fi

# ── Create DB directory ─────────────────────────────────────────
step "Database"
mkdir -p db
ok "Database directory ready"

# ── Initialize git repo ─────────────────────────────────────────
step "Git repository"
if [ ! -d .git ]; then
  git init -q
  git add .
  git -c user.email="setup@portablework" -c user.name="PortableWork" \
      commit -m "chore: initial PortableWork setup" -q
  ok "Initialized git repository"
else
  ok "Git repository exists"
fi

# ── Build and start ─────────────────────────────────────────────
step "Building Docker image (this may take a moment...)"
docker compose build --quiet
ok "Image built"

step "Starting PortableWork"
docker compose up -d
ok "Started!"

# ── Done ────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}Setup complete! 🎉${RESET}"
echo ""
echo -e "  ${BOLD}Open:${RESET}   https://localhost:4567"
echo -e "  ${BOLD}Note:${RESET}   Accept the self-signed certificate warning in your browser"
echo -e "  ${BOLD}Logs:${RESET}   docker compose logs -f app"
echo -e "  ${BOLD}Stop:${RESET}   docker compose down"
echo ""
echo -e "  ${YELLOW}Next step:${RESET} Add your GitHub token in Settings for sync support"
echo ""
