# Maintaining the Lanthos fork

The Lanthos Ops application is a source-owned fork of
`https://github.com/saeloun/miru-web.git`. It is presented and operated as one
Lanthos product; upstream Miru is a code source, not a separately exposed
employee product.

## Baseline and remotes

- Lanthos repository: `https://github.com/LanthosOps/miru-web.git`
- Upstream repository: `https://github.com/saeloun/miru-web.git`
- Initial Lanthos integration baseline: upstream `develop` at `4a60e7c`
- Protected Lanthos integration branch: `develop`

Configure the upstream remote without changing `origin`:

```bash
git remote add upstream https://github.com/saeloun/miru-web.git
git fetch upstream --prune
```

## Sync cadence

Review upstream monthly and immediately for security advisories. Sync through a
dedicated `codex/upstream-miru-YYYY-MM` branch and a draft pull request. Never
merge an upstream branch directly into a deployed branch.

1. Fetch `upstream/develop` and record the before/after SHAs in the pull request.
2. Merge or cherry-pick into the sync branch.
3. Resolve conflicts while preserving Lanthos internal-mode guarantees.
4. Run the regression suite below and all repository-required Council reviews.
5. Promote only after an owner confirms the internal experience and access gate.

## Conflict hotspots

Pay special attention to:

- `InternalDeployment`, its preflight/bootstrap services, and startup scripts
- session issuance in password, OAuth, OTP, passkey, TOTP, mobile, and agent-key flows
- invitation creation, resend, update, and redemption
- `CompanyAccessPayload` and the distinction between environment-derived
  internal access and persisted `billing_exempt`
- Stripe checkout, portal, webhooks, synchronization, trials, and seat jobs
- application/mailer layouts, `BrandLogo`, authentication pages, settings
  routes, invoices, exports, and mobile shells
- any new telemetry, CRM, billing, notification, or third-party integration

## Required regression suite

At minimum, every upstream sync must run:

```bash
bin/vite build --clear --mode=test
bundle exec rspec spec/services/internal_deployment_preflight_spec.rb \
  spec/services/internal_deployment_bootstrap_owner_spec.rb \
  spec/services/create_invited_user_service_spec.rb \
  spec/requests/api/v1/users spec/requests/api/v1/mobile \
  spec/requests/api/v1/agent spec/requests/users/omniauth_callbacks \
  spec/requests/api/v1/subscriptions_controller_spec.rb \
  spec/requests/webhooks/stripe_controller_spec.rb \
  spec/jobs/sync_stripe_subscriptions_job_spec.rb \
  spec/jobs/sync_stripe_subscription_company_job_spec.rb
bundle exec rspec spec/system/authentication spec/system/settings/billing_spec.rb
bundle exec rubocop
pnpm lint
git diff --check
```

Run `MIRU_INTERNAL_DEPLOYMENT=true bundle exec rake internal_deployment:verify`
against a production-like database before any cutover. A failing preflight is a
release blocker, not a warning.

## Release boundary

Upstream syncs remain owner-only until the Lanthos draft pull request is
reviewed, merged, deployed to an internal environment, and explicitly approved.
Do not invite employees, enable public signup, send onboarding notifications, or
expose an upstream-branded route as part of a sync.
