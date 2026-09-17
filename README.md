# Canvas LMS for YunoHost

[![Integration level](https://dash.yunohost.org/integration/canvas.svg)](https://dash.yunohost.org/appci/app/canvas)
[![Install Canvas with YunoHost](https://install-app.yunohost.org/install-with-yunohost.svg)](https://install-app.yunohost.org/?app=canvas)

*[Lire ce readme en français.](./README_fr.md)*

> *This package lets you install Canvas LMS quickly and simply on a YunoHost server. If you don't have YunoHost, please consult [the guide](https://yunohost.org/install) to learn how to install it.*

## Overview

Canvas LMS is the open-source Learning Management System developed by [Instructure](https://www.instructure.com/canvas). It provides course management, assignments, quizzes, grading, discussions and LTI integrations for education and training.

**Shipped version:** `release/2026-05-20.143`

> [!WARNING]
> **Canvas is a large, resource-heavy Ruby on Rails application.**
> This package builds Ruby 3.4 from source and compiles Canvas's frontend
> assets on the server. Budget **≥ 4 GB RAM to install**, **≥ 2 GB RAM to run**,
> and roughly **12 GB of disk**. It is not suitable for small VPS instances,
> and installation takes tens of minutes.

## Status of this package

> [!IMPORTANT]
> This is an **early, work-in-progress** package. A full `yunohost app install`
> has now completed end-to-end on a live YunoHost 12.1 box (Debian 12/Bookworm):
> Canvas builds, installs, starts under systemd behind nginx, and the login page
> and admin dashboard render. Upgrade / backup / restore are **not yet validated
> on a live box** — see the roadmap below.
>
> Before attempting the full YunoHost install, run `dev/spike_stage1_2.sh` on a
> throwaway box — it validates the riskiest part (system deps + Ruby 3.4
> build + `bundle install`) in isolation, without YunoHost helpers.

### Architecture notes

* **Ruby 3.4** is built per-app via `rbenv`/`ruby-build` into the install
  directory (Debian Trixie only ships Ruby 3.3, and Canvas requires ≥ 3.4.1).
* **PostgreSQL** database via the YunoHost resource system; **Redis** via apt.
* **Node.js 20 + Yarn 1.x** for the webpack asset build.
* Two systemd services: `canvas-web` (Puma) and `canvas-jobs` (delayed_job).
* Full-domain install only (Canvas cannot run under a subpath).

### Roadmap

- [x] Stage 1 — manifest, system deps, PostgreSQL + Redis provisioning, source fetch
- [x] Stage 2 — Ruby 3.4 build + `bundle install` (needs live validation)
- [x] Stage 3 — Canvas config templates
- [x] Stage 4 — `db:initial_setup` + asset compilation
- [x] Stage 5 — systemd services + nginx
- [x] Stage 6 — backup / restore / upgrade / remove
- [x] Fill the real source `sha256`
- [x] Standalone spike scripts: Stages 1–2 (`dev/spike_stage1_2.sh`) and Stages 3–4 (`dev/spike_stage3_4.sh`)
- [x] Spikes pass on a live box (Debian 12/Bookworm, YunoHost 12): Ruby build, bundle, yarn, webpack compile, full migrations, db:initial_setup
- [x] Validate a full `yunohost app install` through service start, login and dashboard (live YunoHost 12.1 / Debian 12). Required two live-only fixes: a dedicated Redis DB (`ynh_redis_get_free_db`) so `db:initial_setup` can't inherit a stale `encryption_key_hash`, and `jwt_encryption_keys` in `security.yml`
- [x] Verify the `canvas-jobs` background worker (delayed_job) runs — needs `config/delayed_jobs.yml`
- [x] Validate upgrade / backup / restore cycle on a live box (YunoHost 12.1 / Debian 12). Required fixes: v2.1 positional `ynh_backup`/`ynh_restore` syntax; `remove` must force-delete the systemd units (else an enabled orphan is resurrected on reboot); `restore` must `restart` (not `start`) canvas-web so the readiness wait sees a fresh "Listening on"
- [ ] Re-run a clean install from the fixed package to confirm no manual steps are needed
- [ ] Optional: gzip is enabled and `/dist/` assets are cached in nginx; consider tuning further to reduce outbound traffic
- [ ] Optional: outgoing email needs the server's port 25 unblocked or an SMTP relay (provider blocks port 25 by default)
- [ ] Optional: ship a prebuilt Ruby+assets bundle to cut install time
- [ ] Optional: incoming mail (IMAP) and YunoHost LDAP integration

## Documentation and resources

* Upstream app code: <https://github.com/instructure/canvas-lms>
* Upstream admin doc (Production Start): <https://github.com/instructure/canvas-lms/wiki>

## License

The upstream Canvas LMS is licensed under **AGPL-3.0-or-later**. This YunoHost
packaging is distributed under the same terms.
