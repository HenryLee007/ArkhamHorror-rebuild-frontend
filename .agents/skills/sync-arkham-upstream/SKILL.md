---
name: sync-arkham-upstream
description: Project-specific workflow for syncing ArkhamHorror upstream rule engine, card, scenario, campaign, API, Entity, and migration changes into this repository while preserving the local UI, Docker, image, and arkham.build integration. Use when the user asks to update from halogenandtoast/ArkhamHorror, sync upstream rules/cards/scenarios, resolve upstream merge conflicts, judge npm run tc failures after sync, or prepare an upstream sync branch for dev.
---

# Sync Arkham Upstream

## Overview

Use this skill only inside `/Users/mac/Desktop/ArkhamHorror-rebuild-frontend`. Treat `git@github.com:halogenandtoast/ArkhamHorror.git` as the source of truth for game rules, cards, scenarios, campaigns, and engine behavior; preserve this fork's UI, Chinese/local deployment work, images, Docker, and `arkham.build` integration.

## Defaults

- Source remote: `upstream`
- Source URL: `git@github.com:halogenandtoast/ArkhamHorror.git`
- Source branch: `upstream/main`
- Target branch: `dev`
- Sync branch pattern: `sync/upstream-YYYYMMDD`
- Scope: ArkhamHorror main site only; do not treat `arkham.build/` as part of the upstream source repository.

## Required Reading

Before changing files, read:

- `AGENTS.md`
- `PROJECT_SUMMARY.md` section 6 for code location mapping
- `PROJECT_SUMMARY.md` section 8 for risk areas
- `docs/UPSTREAM_SYNC.md`

Do not recursively scan all of `backend/arkham-api/library/Arkham/` or `frontend/public/cards_*.json`; use targeted `rg`, `git diff --name-only`, and path filters.

## Workflow

1. Confirm the working tree:
   ```bash
   git status --short --branch
   git remote -v
   ```
   If unrelated user changes exist, do not overwrite or revert them.

2. Ensure the upstream remote:
   ```bash
   git remote add upstream git@github.com:halogenandtoast/ArkhamHorror.git
   git fetch upstream --prune
   ```
   If `upstream` already exists, only run `git fetch upstream --prune`.

3. Check whether the local branch already touched high-risk game paths:
   ```bash
   git diff --name-only dev..HEAD -- \
     backend/arkham-api/library/Arkham \
     backend/arkham-api/library/Entity \
     migrations \
     frontend/public/cards_*.json \
     backend/cards-discover
   ```
   If this prints unexpected local game-rule changes, stop and ask the user whether to keep them.

4. Create a sync branch from `dev`:
   ```bash
   git switch dev
   git pull --ff-only origin dev
   git switch -c sync/upstream-YYYYMMDD
   git merge --no-commit upstream/main
   ```

5. Resolve conflicts by ownership:
   - Prefer upstream for `backend/arkham-api/library/Arkham/`, `backend/cards-discover/`, generated card data, new card/scenario/campaign files, and rule helpers.
   - Prefer this fork for UI shell, Chinese/local UX, login changes, Docker/Nginx/image import integration, and `arkham.build/`.
   - Manually inspect `migrations/`, `Entity/`, `routes`, `Application.hs`, `Api/Handler/`, `frontend/src/arkham/api.ts`, `frontend/src/api.ts`, `frontend/src/arkham/types/`, `frontend/src/stores/user.ts`, `frontend/src/router/index.ts`, `Arkham/Message.hs`, and `Arkham/Game.hs`.

6. For deleted language files, preserve this fork's language simplification unless the user explicitly wants all upstream locales restored. Keep Simplified Chinese usable when adopting upstream i18n keys.

7. Validate TypeScript by baseline, not by absolute green. Run this from the current sync worktree so uncommitted conflict resolutions are included:
   ```bash
   .agents/skills/sync-arkham-upstream/scripts/compare-tc-baselines.sh dev upstream/main
   ```
   Treat `npm run tc` as blocking only for errors newly introduced by the sync branch and attributable to this fork's own UI/integration changes. Upstream and historical `tc` errors are recorded, not fixed as part of a rules sync.

8. Run hard validation:
   ```bash
   cd frontend && npm run build
   docker compose config --quiet
   docker compose build web
   docker compose up -d
   curl -f http://localhost:3000/health
   ```
   If local `stack` exists, also run:
   ```bash
   cd backend/arkham-api
   stack build --flag arkham-api:library-only --flag arkham-api:dev
   stack test --flag arkham-api:library-only --flag arkham-api:dev
   ```

9. Smoke-test runtime behavior:
   - Authenticate with the known local admin account if available.
   - Open `http://localhost:3000`.
   - Enter or create a game, make one action, refresh, and confirm state restores when the change affects game flow.
   - If `arkham.build` is in scope, verify `/build/browse` and a `/build-assets/optimized/*.avif` image return 200.

10. Commit only after hard validation passes and `tc` baseline differences are understood:
    ```bash
    git add <resolved-files>
    git commit -m "sync upstream game updates YYYY-MM-DD"
    ```

## TypeScript Policy

`npm run tc` currently fails on both `upstream/main` and the pre-sync `dev` baseline. Do not promise full `tc` cleanup as part of upstream rule sync.

Use this decision table:

| Result | Action |
|---|---|
| Error exists in `dev` or `upstream/main` | Record it; do not block sync solely for it. |
| Error exists only in sync branch and points to local UI/integration edits | Fix before commit. |
| Error exists only in sync branch and comes from upstream rule/API/type evolution | Verify build, Docker, and runtime. Report it as upstream/historical type debt unless runtime is broken. |
| `npm run build` fails | Block commit and fix. |
| Docker backend compile fails | Block commit and fix or ask if the failure requires upstream domain knowledge. |

## Hard Stops

Stop and ask the user when:

- Existing migrations conflict or need rewriting.
- `Entity` JSONB shapes change and the frontend decoders or migrations are unclear.
- `routes` changes without obvious Handler/Application alignment.
- Local uncommitted game-rule changes overlap upstream changes.
- Backend build/test fails inside the rule engine and the fix requires changing game behavior.
- Upstream removes or renames this fork's login, main UI, image paths, Docker routes, or `arkham.build` integration.

## Reporting

Report the source ref, target branch, sync branch, major conflict areas, hard validation results, `tc` baseline output directory and sync-only summary, touched risk areas from `PROJECT_SUMMARY.md` section 8, and whether the branch was committed or pushed.
