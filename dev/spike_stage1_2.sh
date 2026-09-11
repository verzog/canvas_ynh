#!/bin/bash
#
# spike_stage1_2.sh — standalone validator for the riskiest part of canvas_ynh.
#
# This does NOT use YunoHost helpers. Run it on a throwaway Debian 13 (Trixie)
# box or container to answer one question: do the system deps + Ruby 3.4 build +
# `bundle install` for the pinned Canvas release actually succeed on Trixie?
#
# It is deliberately isolated: everything lands in a scratch dir you choose, and
# the only system-wide change is `apt install` of build dependencies.
#
# Usage:
#   sudo ./spike_stage1_2.sh [/path/to/scratch]     # default: /opt/canvas-spike
#
# Exit code 0 = Stages 1 and 2 succeeded. Non-zero = it failed (see the log).

set -euo pipefail

#=================================================
# CONFIG — keep in sync with scripts/_common.sh
#=================================================
canvas_release="release/2026-05-20.143"
ruby_version="3.4.5"

scratch="${1:-/opt/canvas-spike}"
rbenv_root="$scratch/.rbenv"
src_dir="$scratch/canvas"
log="$scratch/spike.log"

say() { echo -e "\n\033[1;36m==> $*\033[0m"; }
warn() { echo -e "\033[1;33m[warn] $*\033[0m"; }
die() { echo -e "\033[1;31m[FAIL] $*\033[0m"; exit 1; }

#=================================================
# PRE-FLIGHT
#=================================================
[ "$(id -u)" -eq 0 ] || die "Run as root (sudo) — apt install is required."

say "Environment"
. /etc/os-release 2>/dev/null || true
echo "OS: ${PRETTY_NAME:-unknown}"
if [ "${VERSION_CODENAME:-}" != "trixie" ]; then
    warn "This spike targets Debian 13 (Trixie). Detected: ${VERSION_CODENAME:-unknown}."
fi
total_ram_mb=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
echo "RAM: ${total_ram_mb} MB"
if [ "$total_ram_mb" -lt 3800 ]; then
    warn "Less than ~4 GB RAM. The Ruby build should still pass, but a full Canvas"
    warn "asset compile (not run by this spike) is likely to OOM here."
fi

mkdir -p "$scratch"
say "Logging to $log"
exec > >(tee -a "$log") 2>&1

start_ts=$(date +%s)

#=================================================
# STAGE 1 — SYSTEM DEPENDENCIES
#=================================================
say "STAGE 1: installing system build dependencies (apt)"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends \
    build-essential git curl pkg-config \
    libpq-dev \
    zlib1g-dev libssl-dev libreadline-dev libyaml-dev libffi-dev libgdbm-dev libncurses-dev \
    libxml2-dev libxmlsec1-dev libxmlsec1-openssl libidn-dev libsqlite3-dev \
    imagemagick \
    || die "apt install failed — check package names against Trixie."
echo "System Ruby (for reference): $(ruby -v 2>/dev/null || echo 'none')"

#=================================================
# STAGE 2a — BUILD RUBY 3.4 VIA rbenv
#=================================================
say "STAGE 2a: building Ruby $ruby_version via rbenv (this takes several minutes)"
if [ ! -d "$rbenv_root" ]; then
    git clone --depth 1 https://github.com/rbenv/rbenv.git "$rbenv_root"
    git clone --depth 1 https://github.com/rbenv/ruby-build.git "$rbenv_root/plugins/ruby-build"
fi
if [ ! -d "$rbenv_root/versions/$ruby_version" ]; then
    RBENV_ROOT="$rbenv_root" RUBY_CONFIGURE_OPTS="--disable-install-doc" \
        "$rbenv_root/bin/rbenv" install --skip-existing "$ruby_version" \
        || die "Ruby $ruby_version failed to build. This is the key risk — inspect the log."
fi
export RBENV_ROOT="$rbenv_root"
export PATH="$rbenv_root/shims:$rbenv_root/bin:$PATH"
rbenv global "$ruby_version"
echo "Built Ruby: $(ruby -v)"
[ "$(ruby -e 'print RUBY_VERSION')" = "$ruby_version" ] || die "Wrong Ruby on PATH."

#=================================================
# STAGE 2b — FETCH CANVAS SOURCE
#=================================================
say "STAGE 2b: fetching Canvas source ($canvas_release)"
if [ ! -d "$src_dir" ]; then
    mkdir -p "$src_dir"
    curl -sSL "https://codeload.github.com/instructure/canvas-lms/tar.gz/refs/tags/$canvas_release" \
        | tar -xz -C "$src_dir" --strip-components=1 \
        || die "Could not download/extract Canvas source."
fi
[ -f "$src_dir/Gemfile" ] || die "Gemfile not found — source layout unexpected."

#=================================================
# STAGE 2c — bundle install (production groups only)
#=================================================
say "STAGE 2c: bundle install (without development/test)"
cd "$src_dir"
gem install bundler --no-document
bundle config set --local without 'development test'
bundle config set --local path "$src_dir/vendor/bundle"
bundle install --jobs=4 \
    || die "bundle install failed — native gem build or a version constraint. Inspect the log."

#=================================================
# RESULT
#=================================================
elapsed=$(( $(date +%s) - start_ts ))
say "SUCCESS — Stages 1 and 2 passed in $((elapsed/60))m $((elapsed%60))s"
echo "Ruby:   $(ruby -v)"
echo "Bundler: $(bundle -v)"
echo "Gems installed under: $src_dir/vendor/bundle"
echo
echo "Next unspiked risks (NOT tested here): yarn install, rake db:initial_setup,"
echo "webpack asset compile (needs ~4 GB RAM), and the systemd/nginx wiring."
echo
echo "Cleanup when done:  sudo rm -rf $scratch"
