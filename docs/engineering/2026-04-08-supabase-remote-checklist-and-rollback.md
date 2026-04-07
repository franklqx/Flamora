# Supabase Remote Checklist And Rollback

This document records which Supabase changes from the `codex/home-plan-rebuild` branch have already affected the remote project, and what to do if we want to roll them back later.

## What Has Already Changed Remotely

### Database migrations already applied

1. [20260407_rebuild_fire_goal_setup_state.sql](/Users/staygreen/Documents/GitHub/Flamora/Fire%20cursor/supabase/migrations/20260407_rebuild_fire_goal_setup_state.sql)
2. [20260408_active_plans_unique_constraint.sql](/Users/staygreen/Documents/GitHub/Flamora/Fire%20cursor/supabase/migrations/20260408_active_plans_unique_constraint.sql)

### Database schema impact

`fire_goals` was extended with:
- `retirement_spending_monthly`
- `lifestyle_preset`
- `withdrawal_rate_assumption`
- `inflation_assumption`
- `return_assumption`

`fire_goals` was also relaxed:
- `current_age` is now nullable
- `target_retirement_age` is now nullable

New tables:
- `user_setup_state`
- `active_plans`

New index:
- `idx_active_plans_one_per_user`

### Edge Functions already deployed

Modified existing functions:
- [save-fire-goal](/Users/staygreen/Documents/GitHub/Flamora/Fire%20cursor/supabase/functions/save-fire-goal/index.ts)
- [get-active-fire-goal](/Users/staygreen/Documents/GitHub/Flamora/Fire%20cursor/supabase/functions/get-active-fire-goal/index.ts)
- [generate-plans](/Users/staygreen/Documents/GitHub/Flamora/Fire%20cursor/supabase/functions/generate-plans/index.ts)

New functions:
- [get-setup-state](/Users/staygreen/Documents/GitHub/Flamora/Fire%20cursor/supabase/functions/get-setup-state/index.ts)
- [apply-selected-plan](/Users/staygreen/Documents/GitHub/Flamora/Fire%20cursor/supabase/functions/apply-selected-plan/index.ts)
- [preview-simulator](/Users/staygreen/Documents/GitHub/Flamora/Fire%20cursor/supabase/functions/preview-simulator/index.ts)
- [mark-setup-step](/Users/staygreen/Documents/GitHub/Flamora/Fire%20cursor/supabase/functions/mark-setup-step/index.ts)

Shared helper added:
- [fire-math.ts](/Users/staygreen/Documents/GitHub/Flamora/Fire%20cursor/supabase/functions/_shared/fire-math.ts)

### Function config already changed

Both of these local config files were updated to include the new functions and `verify_jwt = false` declarations:
- [config.toml](/Users/staygreen/Documents/GitHub/Flamora/Fire%20cursor/supabase/config.toml)
- [functions/config.toml](/Users/staygreen/Documents/GitHub/Flamora/Fire%20cursor/supabase/functions/config.toml)

In practice, the new functions were deployed with `--no-verify-jwt`, so the live behavior is now:
- gateway-level JWT verification is disabled for these functions
- each function validates the bearer token internally using `supabase.auth.getUser(token)`

## What Does Not Automatically Roll Back

Switching back to an old Git branch will restore:
- local Swift code
- local Supabase source files
- local docs

Switching back to an old Git branch will not restore:
- live Edge Function deployments
- already applied database migrations
- already created remote tables/indexes/columns

## Safe Mental Model

Git branch state and remote Supabase state are separate.

You can safely go back to an older code branch without losing the branch history, but the remote backend will stay on the newer schema/functions until we explicitly roll it back.

## Recommended Rollback Strategy

### Level 1: code-only rollback

Use this if we only want to stop using the new Home/setup system in the app.

Steps:
1. Switch back to the old Git branch.
2. Rebuild the app.
3. Leave remote Supabase as-is if old app code still works against the newer functions.

This is the lowest-risk option.

### Level 2: function rollback

Use this if the old app code is not compatible with the live Edge Functions.

Rollback order:
1. Redeploy old versions of:
   - `save-fire-goal`
   - `get-active-fire-goal`
   - `generate-plans`
2. Stop calling these new functions from the app:
   - `get-setup-state`
   - `apply-selected-plan`
   - `preview-simulator`
   - `mark-setup-step`
3. Optionally remove the new functions from config after we are sure nothing calls them.

Important:
- function rollback is safer than database rollback
- the database can keep extra tables/columns around without breaking anything if old functions ignore them

### Level 3: full Supabase rollback

Use this only if we truly want to erase the new backend model.

Recommended order:
1. Roll back function usage first
2. Remove new function deployments if desired
3. Remove the partial unique index
4. Drop `active_plans`
5. Drop `user_setup_state`
6. Drop new `fire_goals` columns
7. Only then consider restoring `NOT NULL` on age columns

## Dangerous Part

The most dangerous rollback step is restoring:
- `fire_goals.current_age` to `NOT NULL`
- `fire_goals.target_retirement_age` to `NOT NULL`

That should only happen after checking whether any remote rows now contain null values.

If nulls exist, the `ALTER COLUMN ... SET NOT NULL` will fail until the data is cleaned up.

## Suggested SQL Rollback Draft

Use only after function rollback is complete and after verifying the data.

```sql
DROP INDEX IF EXISTS public.idx_active_plans_one_per_user;

DROP TABLE IF EXISTS public.active_plans;
DROP TABLE IF EXISTS public.user_setup_state;

ALTER TABLE public.fire_goals
  DROP COLUMN IF EXISTS retirement_spending_monthly,
  DROP COLUMN IF EXISTS lifestyle_preset,
  DROP COLUMN IF EXISTS withdrawal_rate_assumption,
  DROP COLUMN IF EXISTS inflation_assumption,
  DROP COLUMN IF EXISTS return_assumption;
```

Only after checking data:

```sql
ALTER TABLE public.fire_goals
  ALTER COLUMN current_age SET NOT NULL,
  ALTER COLUMN target_retirement_age SET NOT NULL;
```

## Recommended Default Decision

If we dislike this branch later, prefer:
- keep the remote schema
- redeploy old function code only if needed
- switch the app back in Git

This is much safer than aggressively rolling the database backward.
