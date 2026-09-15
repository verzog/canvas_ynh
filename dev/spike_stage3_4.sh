#!/bin/bash
#
# spike_stage3_4.sh — standalone validator for Canvas config + DB init + assets.
#
# Run this AFTER spike_stage1_2.sh has succeeded on the same box (it reuses that
# scratch dir's built Ruby, Canvas source and installed gems). It does NOT use
# YunoHost helpers. It answers: do the config templates, `rake db:initial_setup`
# (non-interactive first admin) and the webpack asset compile actually work?
#
# It provisions a THROWAWAY PostgreSQL database + Redis to mimic what the
# YunoHost resource system provides. Use a disposable box/container.
#
# Usage:
#   sudo ./spike_stage3_4.sh [/path/to/scratch]     # default: /opt/canvas-spike
#
# Exit code 0 = Stages 3 and 4 succeeded.

set -euo pipefail

# If RBENV_ROOT is readonly in the ambient shell (leftover from a prior rbenv
# setup), our exports below would fail. Re-exec once in a clean environment.
if [ -z "${_SPIKE_REEXEC:-}" ] && readonly -p 2>/dev/null | grep -q ' RBENV_ROOT='; then
    exec env -u RBENV_ROOT _SPIKE_REEXEC=1 bash "$0" "$@"
fi

#=================================================
# CONFIG — keep in sync with scripts/_common.sh + conf/
#=================================================
ruby_version="3.4.5"
nodejs_min="20"

scratch="${1:-/opt/canvas-spike}"
rbenv_root="$scratch/.rbenv"
src_dir="$scratch/canvas"
log="$scratch/spike_stage3_4.log"

# Throwaway database + first-admin values (spike-local, not secrets).
db_name="canvas_spike"
db_user="canvas_spike"
db_pwd="canvas_spike_pw"
domain="${CANVAS_SPIKE_DOMAIN:-localhost}"
admin_email="${CANVAS_SPIKE_ADMIN_EMAIL:-admin@example.com}"
admin_pwd="${CANVAS_SPIKE_ADMIN_PASSWORD:-changeme12345}"
encryption_key="spike_encryption_key_at_least_20_chars_long"

say() { echo -e "\n\033[1;36m==> $*\033[0m"; }
warn() { echo -e "\033[1;33m[warn] $*\033[0m"; }
die() { echo -e "\033[1;31m[FAIL] $*\033[0m"; exit 1; }

#=================================================
# PRE-FLIGHT
#=================================================
[ "$(id -u)" -eq 0 ] || die "Run as root (sudo)."
[ -d "$rbenv_root/versions/$ruby_version" ] || die "Ruby not found in $rbenv_root. Run spike_stage1_2.sh first."
[ -f "$src_dir/Gemfile" ] || die "Canvas source not found in $src_dir. Run spike_stage1_2.sh first."
[ -d "$src_dir/vendor/bundle" ] || die "Gems not found ($src_dir/vendor/bundle). Run spike_stage1_2.sh first."

exec > >(tee -a "$log") 2>&1
start_ts=$(date +%s)

export RBENV_ROOT="$rbenv_root"
export PATH="$rbenv_root/shims:$rbenv_root/bin:$PATH"
export RAILS_ENV=production

total_ram_mb=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
say "RAM: ${total_ram_mb} MB (asset compile below needs ~4 GB; may OOM if lower)"

#=================================================
# SERVICES — PostgreSQL, Redis, Node/Yarn
#=================================================
say "Installing/starting PostgreSQL, Redis and Node.js"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends postgresql redis-server nodejs npm \
    || die "apt install of services failed."

node_major=$(node -v 2>/dev/null | sed 's/^v\([0-9]*\).*/\1/' || echo 0)
if [ "${node_major:-0}" -lt "$nodejs_min" ]; then
    warn "Distro Node is v${node_major}; Canvas needs >= $nodejs_min. Installing NodeSource $nodejs_min.x."
    curl -fsSL "https://deb.nodesource.com/setup_${nodejs_min}.x" | bash -
    apt-get install -y nodejs || die "NodeSource Node install failed."
fi
echo "Node: $(node -v)"
npm install --global yarn@1.19.1 >/dev/null 2>&1 || die "yarn install (npm global) failed."
echo "Yarn: $(yarn -v)"

systemctl start postgresql redis-server 2>/dev/null || service postgresql start || true

#=================================================
# THROWAWAY DATABASE (mimics the YunoHost postgresql resource)
#=================================================
say "Provisioning throwaway PostgreSQL database '$db_name' (recreated each run)"
sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='$db_user'" | grep -q 1 \
    || sudo -u postgres psql -c "CREATE ROLE $db_user LOGIN PASSWORD '$db_pwd';"
# Drop any leftover DB from a previous run so db:initial_setup starts clean.
sudo -u postgres psql -c "DROP DATABASE IF EXISTS $db_name;"
sudo -u postgres psql -c "CREATE DATABASE $db_name OWNER $db_user;"

#=================================================
# STAGE 3 — CONFIG FILES (mirrors conf/*.yml templates)
#=================================================
say "STAGE 3: writing Canvas config files"
cd "$src_dir"
mkdir -p config

cat > config/database.yml <<EOF
production:
  adapter: postgresql
  encoding: utf8
  database: $db_name
  host: localhost
  username: $db_user
  password: "$db_pwd"
  timeout: 5000
  pool: 5
EOF

cat > config/security.yml <<EOF
production:
  encryption_key: "$encryption_key"
EOF

cat > config/domain.yml <<EOF
production:
  domain: "$domain"
  ssl: true
EOF

cat > config/outgoing_mail.yml <<EOF
production:
  address: "localhost"
  port: 25
  domain: "$domain"
  outgoing_address: "no-reply@$domain"
  default_name: "Canvas"
EOF

cat > config/redis.yml <<EOF
production:
  url:
    - redis://localhost:6379/0
EOF

cat > config/cache_store.yml <<EOF
production:
  cache_store: redis_cache_store
EOF

echo "Config written: $(ls config/*.yml | tr '\n' ' ')"

#=================================================
# STAGE 4a — yarn install (JS deps)
#=================================================
say "STAGE 4a: yarn install"
yarn install --pure-lockfile || die "yarn install failed."

#=================================================
# STAGE 4b — asset compile (the heavy one) — BEFORE db init
#=================================================
# Must precede db:initial_setup: brand-CSS migrations need the gulp-rev asset
# manifest. COMPILE_ASSETS_BRAND_CONFIGS=0 skips DB-dependent brand configs here.
say "STAGE 4b: rake canvas:compile_assets (slow, memory-heavy)"
COMPILE_ASSETS_BRAND_CONFIGS=0 bundle exec rake canvas:compile_assets \
    || die "Asset compile failed — often OOM on < 4 GB RAM, or a Node/yarn issue."

#=================================================
# STAGE 4c — db:initial_setup (schema + first admin)
#=================================================
say "STAGE 4c: rake db:initial_setup (non-interactive first admin)"
CANVAS_LMS_ADMIN_EMAIL="$admin_email" \
CANVAS_LMS_ADMIN_PASSWORD="$admin_pwd" \
CANVAS_LMS_ACCOUNT_NAME="canvas_spike" \
CANVAS_LMS_STATS_COLLECTION="opt_out" \
    bundle exec rake db:initial_setup \
    || die "db:initial_setup failed — inspect the log."

#=================================================
# RESULT
#=================================================
elapsed=$(( $(date +%s) - start_ts ))
say "SUCCESS — Stages 3 and 4 passed in $((elapsed/60))m $((elapsed%60))s"
echo "Compiled assets under: $src_dir/public"
echo
echo "Still unspiked: running Puma + delayed_job under systemd, nginx reverse"
echo "proxy, and the full YunoHost install/upgrade/backup/restore cycle."
echo
echo "Cleanup:"
echo "  sudo -u postgres psql -c 'DROP DATABASE IF EXISTS $db_name;'"
echo "  sudo -u postgres psql -c 'DROP ROLE IF EXISTS $db_user;'"
echo "  sudo rm -rf $scratch"
