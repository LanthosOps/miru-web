# Deploying Miru on Render

Miru 3.0 is designed to run on Render with:

- one web service
- one worker service
- one Postgres database
- one Render Key Value instance

For the fastest setup, use the repository Blueprint at the root of the repo:

- [`render.yaml`](../../../../render.yaml)

Or use the one-click button from the main repository README.

## Branch model

- `production`: deploy branch for `app.miru.so`
- `develop`: integration branch
- `stable-3-0`: release preparation branch

## One-click deploy

1. Open the Deploy to Render button from the README.
2. Confirm the Blueprint resources.
3. Fill in the required secret values.
4. Create the stack.
5. Set `APP_BASE_URL` to your Render hostname first, then to your custom domain when DNS is ready.

## Services created by the Blueprint

- `miru-web`
- `miru-worker`
- `miru-db`
- `miru-redis`

## Required environment variables

These should be provided during Blueprint setup or immediately after first deploy:

- `APP_BASE_URL`
- `DEFAULT_MAILER_SENDER`
- `DEFAULT_FROM_EMAIL`
- `REPLY_TO_EMAIL`
- `EMAIL_DELIVERY_METHOD`
- `POSTMARK_API_TOKEN`
- `SENTRY_DSN`
- `STRIPE_SECRET_KEY`
- `STRIPE_PUBLISHABLE_KEY`
- `STRIPE_WEBHOOK_ENDPOINT_SECRET`
- `STRIPE_MONTHLY_PRICE_ID`
- `STRIPE_YEARLY_PRICE_ID`
- `STRIPE_PLAN_PAGE_URL`
- `GOOGLE_OAUTH_CLIENT_ID`
- `GOOGLE_OAUTH_CLIENT_SECRET`
- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`
- `CLOUDFLARE_R2_ACCESS_KEY_ID`
- `CLOUDFLARE_R2_SECRET_ACCESS_KEY`
- `CLOUDFLARE_R2_BUCKET_NAME`
- `CLOUDFLARE_R2_ENDPOINT`
- `CLOUDFLARE_R2_REGION`

## Custom domain

For production:

1. Add `app.miru.so` as a custom domain in Render.
2. Point DNS at the Render web service.
3. Verify `https://app.miru.so/health`.
4. Verify email/password login.
5. Verify Google OAuth after the callback host changes to the custom domain.

## Worker

The worker runs:

```bash
bundle exec rake solid_queue:start
```

Make sure the worker has the same shared app secrets as the web service.

## Internal deployment mode

`MIRU_INTERNAL_DEPLOYMENT=true` converts the deployment into a private,
unmetered operations workspace. It is a deployment identity, not a replacement
for the existing `billing_exempt` database field.

Before enabling it:

1. Set `MIRU_ALLOWED_SIGNUP_EMAILS` to the explicit owner email allowlist. An
   internal deployment with an empty allowlist fails closed.
2. Set both variables to the same values on every web and worker process.
3. Ensure an approved owner already exists. For a fresh database, set
   `MIRU_BOOTSTRAP_OWNER_EMAIL` and a one-time
   `MIRU_BOOTSTRAP_OWNER_PASSWORD`, then run
   `bundle exec rake internal_deployment:bootstrap_owner`. If the database has
   several companies, also set `MIRU_BOOTSTRAP_COMPANY_ID`. Remove the password
   from the environment immediately after the owner is created. Render's
   predeploy command runs this task automatically when the password is present.
4. Run `bundle exec rake internal_deployment:verify`. The preflight fails while
   any company has a Stripe customer or subscription identifier, appears paid,
   has an active/trialing/past-due subscription state, has a pending invitation
   outside the allowlist, or lacks an approved owner. Cancel external
   subscriptions and clear their identifiers only after confirming cancellation.
5. Keep external identity/IAP access limited to the same owners. The app also
   enforces the allowlist for password sessions, OAuth, API sessions, signup,
   invitations, OTP, passkeys, TOTP, password resets, and agent keys.

The web and worker entrypoints and Render predeploy command enforce the same
preflight, so an unsafe internal configuration fails startup instead of silently
cutting over.
OAuth buttons are shown only when both the selected provider's client ID and
secret are configured.

While enabled, Miru subscription checkout, trial creation, portal access,
subscription webhooks, scheduled Stripe synchronization, seat reconciliation,
and trial email jobs are disabled. Customer invoice payment integrations remain
available.

The internal entitlement is derived from the environment and is not persisted
to `billing_exempt`, so new and existing workspaces have the same rollback
behavior. Turning the flag off restores normal Miru branding and billing rules;
run the preflight again before turning it back on.

See [Maintaining the Lanthos fork](./lanthos-fork.md) before syncing upstream
Miru changes.

## Verification after deploy

Run these checks before cutover:

1. `https://<your-domain>/health`
2. log in with a real owner account
3. verify one worker-backed action
4. verify one mailer flow
5. check Sentry for new unresolved errors
