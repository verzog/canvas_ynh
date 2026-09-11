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
> This is an **early, work-in-progress** package. The scripts follow YunoHost
> packaging v2 conventions and Canvas's official production-install steps, but
> they have **not yet been validated end-to-end on a live YunoHost 12.x
> (Debian Trixie) box.** See the roadmap below.
>
> Before attempting the full YunoHost install, run `dev/spike_stage1_2.sh` on a
> throwaway Trixie box — it validates the riskiest part (system deps + Ruby 3.4
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
- [x] Standalone spike script for Stages 1–2 (`dev/spike_stage1_2.sh`)
- [ ] Run the spike on a live Trixie box (Ruby build + bundle install)
- [ ] Validate a full install/upgrade/backup/restore cycle on a live box
- [ ] Optional: ship a prebuilt Ruby+assets bundle to cut install time
- [ ] Optional: incoming mail (IMAP) and YunoHost LDAP integration

## Documentation and resources

* Upstream app code: <https://github.com/instructure/canvas-lms>
* Upstream admin doc (Production Start): <https://github.com/instructure/canvas-lms/wiki>

## License

The upstream Canvas LMS is licensed under **AGPL-3.0-or-later**. This YunoHost
packaging is distributed under the same terms.
