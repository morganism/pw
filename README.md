# PortableWork

> A self-hosted, HTTPS-secured portable workspace manager built with Ruby Sinatra, Bootstrap 5, SQLite3, and Docker Compose. Sync your entire dev environment across machines via GitHub.

![Ruby](https://img.shields.io/badge/Ruby-3.2-red) ![Sinatra](https://img.shields.io/badge/Sinatra-3.2-blue) ![Bootstrap](https://img.shields.io/badge/Bootstrap-5.3-purple) ![Docker](https://img.shields.io/badge/Docker-Compose-blue) ![SQLite](https://img.shields.io/badge/SQLite-3-green)

---

## Features

- **🔒 HTTPS by default** — Self-signed TLS cert generated on first run
- **🍎 Apple-like UI** — Bootstrap 5 with glassmorphism, fluid transitions, and SF-Pro-style typography
- **📦 Workspace management** — Create, edit, and manage portable workspace definitions
- **🐳 Docker services** — Add, start, stop, and export Docker services per workspace
- **☁️ GitHub sync** — Push/pull full workspace state (config + DB snapshot) to/from GitHub
- **🗄️ SQLite3 persistence** — All config and data stored locally in a single file
- **🔄 docker-compose.yml export** — Generate portable compose files for any workspace
- **🌙 Dark mode** — Full dark/light theme toggle with persistence
- **⚡ CLI sync** — `scripts/sync.sh` for headless push/pull from any shell

---

## Quick Start

### Option A: Docker (recommended)

```bash
# 1. Clone this repo
git clone https://github.com/morganism/pw.git
cd pw

# 2. Run setup (generates .env, TLS cert, builds image, starts container)
chmod +x scripts/setup.sh scripts/sync.sh
./scripts/setup.sh

# 3. Open in browser (accept TLS warning for self-signed cert)
open https://localhost:4567
```

### Option B: Run locally (Ruby required)

```bash
gem install bundler
bundle install

# Generate TLS cert
mkdir -p config/ssl
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout config/ssl/server.key -out config/ssl/server.crt \
  -subj "/CN=localhost" 2>/dev/null

# Start
ruby start.rb
```

---

## Configuration

Copy `.env.example` to `.env` and fill in:

| Variable | Description | Default |
|---|---|---|
| `SESSION_SECRET` | Session encryption key (generate with `openssl rand -hex 64`) | — |
| `GITHUB_TOKEN` | GitHub PAT with `repo` scope | — |
| `GITHUB_USER` | GitHub username | — |
| `PORT` | HTTPS port | `4567` |
| `RACK_ENV` | `development` or `production` | `production` |
| `DATABASE_PATH` | Path to SQLite DB | `/app/db/workspace.db` |

---

## GitHub Sync — How It Works

1. **Push** — Takes a snapshot of `workspace.db`, commits it to `.workspace/workspace.db` in your GitHub repo, and pushes.
2. **Pull** — Clones/pulls from GitHub and restores the DB snapshot if present.
3. **Sync across machines** — Pull on another machine to get the exact same workspace state.

```bash
# Push from CLI
./scripts/sync.sh push 1 "feat: add postgres service"

# Pull from CLI
./scripts/sync.sh pull 1

# Check status
./scripts/sync.sh status

# View sync log
./scripts/sync.sh log 20
```

---

## Docker Commands

```bash
# Start
docker compose up -d

# Stop
docker compose down

# View logs
docker compose logs -f app

# Rebuild after code changes
docker compose build && docker compose up -d

# Shell into app
docker compose exec app bash

# View DB
docker compose exec app sqlite3 db/workspace.db ".tables"
```

---

## Project Structure

```
portable-workspace/
├── app.rb                 # Sinatra application (routes, DB, helpers)
├── start.rb               # Puma HTTPS boot script
├── config.ru              # Rack entry point
├── Gemfile                # Ruby dependencies
├── Dockerfile             # Container definition
├── docker-compose.yml     # Full stack definition
├── .env.example           # Environment template
├── app/
│   └── views/
│       ├── layout.erb     # Master layout (nav, topbar, theme)
│       ├── index.erb      # Dashboard
│       ├── workspaces.erb # Workspace management
│       ├── services.erb   # Docker service management
│       └── settings.erb   # Configuration UI
├── config/
│   └── ssl/               # TLS certs (auto-generated, gitignored)
├── db/                    # SQLite database (gitignored, synced via GitHub)
└── scripts/
    ├── setup.sh           # First-time setup
    └── sync.sh            # CLI sync helper
```

---

## Syncing Across Machines

```bash
# Machine A: make changes, then push
./scripts/sync.sh push 1 "update: added redis service"

# Machine B: pull the latest state
git pull origin main          # get the code
./scripts/sync.sh pull 1      # restore DB state
docker compose up -d          # start services
```

---

## Security Notes

- The auto-generated TLS cert is self-signed — browsers will show a warning. Accept it for local use, or configure a real cert via Traefik (see `docker-compose.yml` comments).
- Never commit `.env` to git (it's in `.gitignore`).
- The GitHub token is stored in the SQLite DB — ensure DB is backed up securely.
- Use `SESSION_SECRET` of at least 64 random hex characters.

---

## License

MIT
