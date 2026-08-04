# Runtime and avatar review

Date: 2026-08-04
Branch: `main` after `git fetch --all --prune`
Scope: task prompt comparison against current source, routes, repositories,
provider services, PWA files, E2E bridge, and deployment configuration.

## Findings and disposition

| Area | Finding | Disposition |
|---|---|---|
| Demo/E2E | old flow could block on a profile before a mock turn | simulation gateways are profile-free; config is checked only in Production |
| Network | direct service/probe paths could still reach a provider | simulation guard added to LLM/STT/TTS and voice/probe methods |
| Storage | one DB and cache namespace | Demo/E2E database, secure-storage, and TTS namespaces added |
| TTS | thinking filler and early sentence playback could duplicate/cost extra calls | filler is visual-only; one full reply synthesis path remains |
| E2E | bridge initialization happened before first frame | hooks are exposed from a post-frame callback; `APP_MODE=e2e` is supported |
| Avatar | single-image fallback was not truly layered | asset-free upper-body 2D painter now separates body, arms, hair, eyes, brows, cheeks and mouth |
| Avatar default | 3D was selected from normal chat paths | 2D is the default; 3D remains an explicit experimental Lab toggle |
| QA | fixture catalog was narrow and mostly service-level | twelve business fixtures and manifests cover happy, failure, interruption, review and summary loops; Playwright now proves the happy path through persistence and summary, with provider-request and responsive screenshot evidence |
| PWA | base-href and app runtime could disagree; E2E could inherit a worker | `APP_BASE_PATH` is compile-time checked against each base path; Production/Demo use explicit offline-first workers and E2E disables the worker |
| Avatar | mouth fallback ignored the text viseme and semantic gesture cues were absent | text-driven visemes now affect the mouth; gesture output is a bounded whitelist and drives subtle head/arm poses |
| Release | no repository CI or dual environment workflow | GitHub Actions CI and Aliyun atomic dual-environment workflow added with immutable stamping, health checks, manual ref, concurrency, and rollback; real server evidence is still required |

## Deliberate limits

No legal avatar asset or external GLB was copied into the repository. Live2D/Cubism
remains an optional future asset path because a model, Core runtime, and commercial
distribution rights were not available in this workspace. The built-in 2D painter
is therefore the reliable default and can run without network or GPU service cost.

No deployment is claimed by this review. CI/server secrets and the actual Aliyun
nginx configuration must be present before the deployment workflow can produce
public evidence.
