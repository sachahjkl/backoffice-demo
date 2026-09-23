# Backoffice demo

This repository describes a separate demonstration deployment of the published `@sachahjkl/backoffice` package. It contains no backoffice source code.

## Current status

The manifest pins one published npm version. The lock file records the archive integrity and transitive dependency versions.

Run `nix flake check` and build the image before deployment. The image uses Node.js 26, Typst, and only the published npm dependency. The application command migrates the database before it serves the packaged web application.

## Demo data

The demo runs with `APP_ENV=staging` and `DEMO_MODE=true`. The `seed` prestart task migrates its database and creates synthetic data before the server starts. `ENTERPRISE_NAME=ACME` names the company in each reset and its generated documents. The login page displays synthetic accounts and their shared password. A Nomad batch job restores the data daily at 04:00 UTC. The reset changes this demo database only.

Keep the database at `/var/lib/backoffice-demo/froment.sqlite`. Nomad creates the dedicated host volume for UID and GID `1000`, matching the container user. Never use an existing Froment volume or import production data. Back up the volume before a reset if you need to keep its current contents.

## Secrets and providers

Store demo-only values at `nomad/jobs/backoffice-demo` in the `demo` namespace. Supply `BOOTSTRAP_PASSWORD_SCRYPT`, `PASETO_SECRET_KEY` (a complete Ed25519 key pair), `REFRESH_HMAC_KEY`, `API_TOKEN_HMAC_KEY`, `QUOTE_LINK_HMAC_KEY`, `DEMO_PASSWORD`, and `DEMO_ACCOUNT_PASSWORD`. Make the reset secret different from the public account password. Supply `SETTINGS_ENCRYPTION_KEY` if encrypted integration settings are needed. Keep each value distinct from staging and production. The tasks inject them from Nomad Variables; no secret belongs in Git or the image.

The upstream provider-contract layer currently returns `mode: simulation` and `executed: false` for the five integration services. Do not configure real provider credentials for this demo. The upstream documentation notes separate explicit Resend and Stripe test flows; leave their keys unset.

## Deployment

`application.yaml` targets `https://backoffice-demo.sacha.house` and a dedicated persistent volume. `deploy/group-demo.hcl` seeds the database before `deploy/config.hcl` starts the server. `deploy/task-demo.hcl` sets the public origin and injects secrets. The CI workflow deploys the OCI image and registers `deploy/reset.nomad.hcl` with the deployed image digest.

The cluster has a `demo` namespace and wildcard DNS for `sacha.house`. Create the namespace-scoped secrets and enable the repository's GitHub deployment workflow. Validate `application.yaml` with `application-contract` and render the Nomad Pack before submitting the job.
