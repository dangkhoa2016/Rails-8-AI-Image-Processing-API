# Deploy to Modal.com — Public Production-Style Demo

> **Status:** This is the tracked production deployment contract for the public Modal demo. Production deployment is accepted only from a clean `main` checkout whose `HEAD` matches both remote `origin/main` and the peeled remote `v1.0.0` tag target.

> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](README.vi.md)

This recipe deploys the Rails API as a public production-style demo on Modal.com. Rails continues to use the standard `Authorization: Bearer <JWT>` header.

## Runtime profile

- public `@modal.web_server(..., requires_proxy_auth=False)`;
- `min_containers=0`, `max_containers=1`;
- `buffer_containers=0`, `scaledown_window=60`;
- CPU-only, `cpu=2.0`, `memory=10240` MiB;
- Rails/Puma on port `4000`, `WEB_CONCURRENCY=1`, `RAILS_MAX_THREADS=3`;
- `IMAGE_AI_MAX_CONCURRENCY=1` to keep AI inference single-flight;
- read-only Modal Volume `rails-8-ai-image-processing-models` mounted at `/rails/var/models`;
- `RACK_ATTACK_CACHE_STORE=memory`;
- `SOLID_QUEUE_IN_PUMA=true`, `JOB_CONCURRENCY=1`;
- `RAILS_ENV=production`.

Solid Queue runs inside Puma while the container is awake. This keeps the web
demo and its queue supervisor in the same bounded, scale-to-zero runtime.

## Rails production credentials

Use the standard Rails environment-specific files:

```text
config/credentials/production.yml.enc   # commit
config/credentials/production.key       # never commit
```

Create/edit them locally:

```bash
unset RAILS_MASTER_KEY
export EDITOR=nano
bin/rails credentials:edit --environment production
```

The decrypted production credentials should include at least:

```yaml
secret_key_base: <long random Rails secret>
admin_email: <real admin email>
admin_password: <real admin password>
devise_jwt_secret_key: <long random Rails secret>
```

Commit only `config/credentials/production.yml.enc`. See [CREDENTIALS.md](CREDENTIALS.md) for the full workflow.

## Modal runtime secret

Create the named secret `rails-api-production` from an out-of-repository JSON file containing only:

- `RAILS_MASTER_KEY` — exact contents of `config/credentials/production.key`;
- `DATABASE_URL`;
- `CACHE_DATABASE_URL`;
- `QUEUE_DATABASE_URL`;
- `CABLE_DATABASE_URL`;
- `SMTP_ADDRESS=smtp.resend.com`;
- `SMTP_PORT=465`;
- `SMTP_USERNAME=resend`;
- `SMTP_PASSWORD=<Resend API key>`;
- `SMTP_DOMAIN=<verified sender domain>`;
- `SMTP_AUTHENTICATION=plain`;
- `SMTP_SSL=true`;
- `SMTP_ENABLE_STARTTLS_AUTO=false`;
- `DEVISE_MAILER_SENDER=Rails 8 AI Image Processing API <contact@<verified sender domain>>`;
- `APP_HOST=<public Modal host without scheme>`;
- `APP_PROTOCOL=https`;
- `PUBLIC_DEMO_EMAIL_GUARD=true`.

```bash
chmod 600 "$HOME/.config/rails-api-production.json"
modal secret create rails-api-production \
  --from-json "$HOME/.config/rails-api-production.json"
```

`DEVISE_JWT_SECRET_KEY`, `ADMIN_EMAIL`, and `ADMIN_PASSWORD` are not separate Modal secret keys because they live inside Rails production encrypted credentials.

## Model volume

Create the production model volume before deployment and upload the exact qualified artifacts into its root:

```text
rails-8-ai-image-processing-models
├── BiRefNet-general-epoch_244.onnx
├── mobile_sam_vit_t_image_encoder.onnx
└── mobile_sam_prompt_mask_decoder.onnx
```

The application verifies filename, file size, and SHA-256 against the committed manifests before ONNX loading. The volume is mounted read-only at `/rails/var/models`; deployment never creates or mutates production model artifacts.

## Deploy

```bash
./deploy/modal/deploy.sh
```

The preflight fails unless the entire repository is clean, including untracked files; the current branch is `main`; `HEAD` exactly matches remote `origin/main`; `HEAD` exactly matches the peeled remote `v1.0.0` tag target; production credentials are tracked safely; and both the required Modal secret and model volume already exist.

Modal runs `db:prepare` and then `db:seed` before Puma starts. The first
bootstrap creates the configured admin; repeated cold starts locate the
existing admin without rewriting its credentials.

## Scale-to-zero queue semantics

Because `min_containers=0`, Modal may stop the web container after the idle
window. Solid Queue runs inside Puma while the container is awake, so the
recurring `every hour` cleanup tasks are not a 24/7 scheduling guarantee for
this demo profile. A deployment that requires strict wall-clock execution
should use a separately scheduled worker/task rather than keeping this public
demo warm.

## Public acceptance

```bash
curl -i https://<your-modal-url>/up
./deploy/modal/smoke.sh https://<your-modal-url>
```

Full smoke additionally checks Rails sign-in, standard bearer-token transport, profile access, X-Forwarded-For spoof resistance for the sign-in IP throttle, and refresh-token throttling.

For transactional-email delivery acceptance, use a fresh recipient on an allowed provider and keep the Resend API key only in your local shell:

```bash
export EMAIL_E2E_RECIPIENT='your-fresh-address@gmail.com'
export RESEND_API_KEY='re_...'
./deploy/modal/email_delivery_e2e.sh https://<your-modal-url>
unset RESEND_API_KEY
```

The script verifies that an unsupported domain is rejected before delivery, that an allowed-domain registration is accepted, and that Resend reports the resulting confirmation message as `delivered`, `opened`, or `clicked`. Final production acceptance also requires a human to open the HTTPS confirmation link, confirm sign-in, request `POST /users/password`, verify delivery of the reset email, complete the API-native `PUT /users/password` flow with the supplied token, confirm sign-in with the new password, and confirm the old password no longer works.

## Cost and abuse posture

`max_containers=1` bounds horizontal autoscaling but does not stop an attacker from keeping the one container awake. `RACK_ATTACK_CACHE_STORE=memory` is valid only while that single-container invariant remains true. This is a demo profile, not HA/SLA service or volumetric DDoS protection.
