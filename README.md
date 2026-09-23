# Backoffice demo

This repository describes a separate demonstration deployment of the published `@sachahjkl/backoffice` package. It contains no backoffice source code.

## Current status

The manifest pins the published npm package at version `0.2.5`. The lock file records the archive integrity and transitive dependency versions.

Run `nix flake check` and build the image before deployment. The image uses Node.js 26, Typst, and only the published npm dependency. The application command migrates the database before it serves the packaged web application.

## Demo data

The demo uses `APP_ENV=staging` because the upstream reset action refuses other environments. Set `DEMO_PASSWORD` in Nomad Variables. On a new volume, start the application with `BOOTSTRAP_PASSWORD_SCRYPT` and the required signing keys, then sign in with the bootstrap credentials. Use the reset action in Configuration, enter `DEMO_PASSWORD`, and confirm deletion. The upstream action recreates the five standard profiles and deterministic demo data. Repeat the action to reset the demo. It deletes data on this demo volume only.

Keep the database at `/var/lib/backoffice-demo/froment.sqlite`. The Nomad Pack allocates a host volume named for the `backoffice-demo` application and `demo` environment. Never use an existing Froment volume or import production data. Back up the volume before a reset if you need to keep its current contents.

## Secrets and providers

Create the Nomad namespace `demo` and store demo-only values at `nomad/jobs/backoffice-demo` within that namespace. Supply `BOOTSTRAP_PASSWORD_SCRYPT`, `PASETO_SECRET_KEY` (a complete Ed25519 key pair), `REFRESH_HMAC_KEY`, `API_TOKEN_HMAC_KEY`, `QUOTE_LINK_HMAC_KEY`, and `DEMO_PASSWORD`. Supply `SETTINGS_ENCRYPTION_KEY` if encrypted integration settings are needed. Keep each value distinct from staging and production. The task injects them from Nomad Variables into its environment; no secret belongs in Git or the image.

The upstream provider-contract layer currently returns `mode: simulation` and `executed: false` for the five integration services. Do not configure real provider credentials for this demo. The upstream documentation notes separate explicit Resend and Stripe test flows; leave their keys unset.

## Deployment

`application.yaml` targets `https://backoffice-demo.sacha.house` and a dedicated persistent volume. `deploy/config.hcl` starts the packaged binary. `deploy/task-demo.hcl` sets the public origin and injects secrets. The platform contract uses `application.yaml`, an OCI image from `nix build .#dockerImage`, and short Nomad modules. A deployment workflow and GHCR publication require a real GitHub repository and the published npm package; none is configured here.

Before deployment, add `demo` to `services.nomadPlatform.namespaces` on the cluster. Create the dedicated Nomad host volume and the namespace-scoped secrets. Configure the repository's GitHub OIDC deployment identity, container registry, and DNS route after the repository exists. Validate `application.yaml` with `application-contract` and render the Nomad Pack before submitting a job. These infrastructure changes belong in the platform repository, not here.
