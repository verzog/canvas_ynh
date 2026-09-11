#!/bin/bash

#=================================================
# COMMON VARIABLES AND HELPERS
#=================================================

# Canvas release tag being packaged (must match resources.sources.main in manifest.toml).
canvas_release="release/2026-05-20.143"

# Ruby version to build for Canvas (production docs require >= 3.4.1).
# Debian 13 (Trixie) ships 3.3, so we build our own into the app directory.
ruby_version="3.4.5"

# Node.js major version (Canvas package.json engines: node >= 20).
nodejs_version="20"

# rbenv / ruby-build are cloned into the app directory so Ruby is isolated per-app.
rbenv_root="$install_dir/.rbenv"

#=================================================
# RUBY (rbenv) HELPERS
#=================================================

# Install rbenv + ruby-build into the app directory and build the pinned Ruby.
# This is the riskiest, slowest step (~10 min compile). It is idempotent: if the
# requested Ruby is already built, it is reused.
build_ruby() {
    ynh_script_progression "Building Ruby $ruby_version (this can take several minutes)..."

    if [ ! -d "$rbenv_root" ]; then
        git clone --depth 1 https://github.com/rbenv/rbenv.git "$rbenv_root"
        git clone --depth 1 https://github.com/rbenv/ruby-build.git "$rbenv_root/plugins/ruby-build"
    fi

    # Build only if this exact version is not already present.
    if [ ! -d "$rbenv_root/versions/$ruby_version" ]; then
        # RUBY_CONFIGURE_OPTS disables docs to speed the build; jemalloc is optional.
        RBENV_ROOT="$rbenv_root" RUBY_CONFIGURE_OPTS="--disable-install-doc" \
            "$rbenv_root/bin/rbenv" install --skip-existing "$ruby_version"
    fi

    RBENV_ROOT="$rbenv_root" "$rbenv_root/bin/rbenv" global "$ruby_version"
}

# Run a command with the app's rbenv Ruby on PATH, from the install dir.
# Usage: ruby_exec bundle install --jobs=4
ruby_exec() {
    RBENV_ROOT="$rbenv_root" \
    PATH="$rbenv_root/shims:$rbenv_root/bin:$PATH" \
        "$@"
}

#=================================================
# ASSET COMPILATION HELPER
#=================================================

# Compile Canvas frontend assets (webpack). Very memory-hungry — the manifest
# declares ram.build = 4G for this reason.
compile_assets() {
    ynh_script_progression "Compiling Canvas assets (webpack — this is slow and memory-heavy)..."

    pushd "$install_dir" >/dev/null
        ruby_exec bundle exec rake canvas:compile_assets
    popd >/dev/null
}

#=================================================
# EXPERIMENTAL / FUTURE HELPERS
#=================================================

# Placeholder for a future "ship prebuilt bundle" path (see CLAUDE.md discussion):
# instead of build_ruby + compile_assets at install time, fetch a prebuilt
# ruby+assets tarball. Not implemented in this version.
