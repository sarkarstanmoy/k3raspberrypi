# k3rpi

Apps for a single-node [K3s](https://k3s.io) cluster running on a Raspberry Pi.

Docker Compose runs everything **locally** for development; the Helm chart deploys
it to the **Pi**. Cluster setup itself is in [K3S_INSTALL.md](K3S_INSTALL.md).

## Running locally

```sh
./k3pi up      # build the images and start the containers
./k3pi down    # stop and remove them
```

`up` passes `--build`, so it picks up Go changes with no separate build step.
Requires Docker Desktop to be running.

Once up, the healthcheck app is on port 3000:

| URL | What it is |
| --- | --- |
| http://localhost:3000/api/v1/healthcheck | returns `Healthy` |
| http://localhost:3000/swagger/index.html | Swagger UI |

Plain `docker compose` commands work too, for anything `k3pi` doesn't cover:

```sh
docker compose logs -f     # follow logs
docker compose ps          # what's running
```

### How k3pi is put together

```
k3pi                     entrypoint: dispatches to the scripts below
scripts/k3pi/
├── _shared.sh            settings and helper functions, sourced by the others
├── cmd_up.sh             docker compose up -d --build
└── cmd_down.sh           docker compose down
docker-compose.yml       the services
```

To add a command, drop a `cmd_<name>.sh` in `scripts/k3pi/` that sources
`_shared.sh`, then add a line to the `case` block in `k3pi`.

## Deploying to the Pi

The Helm chart lives in [apps/healthcheck/chart](apps/healthcheck/chart). It pulls from the Zot registry exposed on the Pi, and you can point the chart at any image repository you push there.

### 1. Push an image from your Mac

From your Mac, log in to the Pi's registry endpoint and push the image:

```sh
# Configure Docker Desktop to allow insecure HTTP access to 192.168.1.187:30050.
# Then log in without the removed --tls-verify flag.
docker login 192.168.1.187:30050 -u admin -p <<password>>

docker build -t 192.168.1.187:30050/healthcheck:latest ./apps/healthcheck
docker push 192.168.1.187:30050/healthcheck:latest
```

To allow plain HTTP on macOS, add this to Docker Desktop's daemon config:

- Docker Desktop: Settings -> Docker Engine -> paste this JSON
- or create/edit `~/.docker/daemon.json` and add:

```json
{
  "insecure-registries": [
    "192.168.1.187:30050"
  ]
}
```

Then apply the change and restart Docker Desktop before retrying the push.

If the registry is private, use the same username/password you configured for Zot.

To verify that the image is in the Zot registry, run:

```sh
curl -s http://192.168.1.187:30050/v2/_catalog | jq
curl -s http://192.168.1.187:30050/v2/healthcheck/tags/list | jq

# If the registry is protected:
curl -u admin:<<password>> -s http://192.168.1.187:30050/v2/healthcheck/tags/list | jq
```

### 2. Refer to the image in the chart

The chart defaults to a registry-backed image name that matches the K3s node:

```yaml
image: 192.168.1.187:30050/healthcheck
tag: latest
pullPolicy: Always
```

This is the same image name used by the deployment template:

```yaml
image: "{{ .Values.image }}:{{ .Values.tag }}"
```

So when you install or upgrade the chart, you can override the repository or tag without changing the template:

```sh
helm install healthcheck apps/healthcheck/chart \
  --set image=192.168.1.187:30050/healthcheck \
  --set tag=latest \
  --set pullPolicy=Always
```

If you need private registry auth for the cluster, add an image pull secret:

```sh
kubectl -n default create secret docker-registry regcred \
  --docker-server=192.168.1.187:30050 \
  --docker-username=admin \
  --docker-password=<<password>>
```

Then in the chart values:

```yaml
imagePullSecrets:
  - name: regcred
```

### 3. Alternative: import a local image directly into K3s

If you want to skip the remote registry for a quick test, you can still import a local image into the cluster:

```sh
docker save k3rpi-healthcheck | ssh admin@192.168.1.187 'sudo k3s ctr images import -'
helm install healthcheck apps/healthcheck/chart \
  --set image=k3rpi-healthcheck --set tag=latest --set pullPolicy=IfNotPresent
```

The app is then served at http://healthcheck.192.168.1.187.nip.io/api/v1/healthcheck

## Quick start: push from your Mac and deploy via Helm

Use this exact flow for a private Zot registry on the Pi.

### 1) Log in and push the image from your Mac

```sh
docker login 192.168.1.187:30050 -u admin -p <<password>>
docker build -t 192.168.1.187:30050/healthcheck:latest ./apps/healthcheck
docker push 192.168.1.187:30050/healthcheck:latest
```

### 2) Create the pull secret in K3s

```sh
kubectl -n default create secret docker-registry regcred \
  --docker-server=192.168.1.187:30050 \
  --docker-username=admin \
  --docker-password=<<password>>
```

### 3) Install or upgrade the app with the registry image

```sh
helm upgrade --install healthcheck apps/healthcheck/chart \
  --set image=192.168.1.187:30050/healthcheck \
  --set tag=latest \
  --set pullPolicy=Always \
  --set imagePullSecrets[0].name=regcred
```

You can also do the same through a values file:

```yaml
image: 192.168.1.187:30050/healthcheck
tag: latest
pullPolicy: Always
imagePullSecrets:
  - name: regcred
```

This tells the deployment to pull from the Pi registry and use the `regcred` secret.

## Continuous integration

One workflow, [.github/workflows/ci.yml](.github/workflows/ci.yml), with a single job
`main` on `ubuntu-latest`. It runs on every push to `main` and on every pull request.

| Step | Why |
| --- | --- |
| `actions/checkout@v5` with `fetch-depth: 0` | full history, so Nx can diff against `origin/main` |
| `npx nx start-ci-run --distribute-on="3 linux-medium-js"` | hands task execution to Nx Cloud agents |
| `actions/setup-node@v5`, Node 24, `cache: npm` | toolchain plus a warm npm cache |
| `npm ci` | install from the lockfile |
| `npx nx record -- npx nx format:check --base="remotes/origin/main"` | formatting, logged to Nx Cloud |
| `npx nx run-many -t lint test build typecheck e2e` | the actual checks |
| `npx nx fix-ci` (`if: always()`) | Nx Cloud suggests fixes for failures |

Two things it does **not** do yet, worth knowing before you rely on it:

- **The Go app isn't covered.** `apps/healthcheck` has no `project.json` and there's no Nx
  Go plugin installed, so `nx run-many` finds no targets for it — `go build`, `go vet` and
  `go test` never run in CI.
- **No image build or push.** Nothing builds the Dockerfile or pushes to the registry, so
  deploys stay manual via `./k3pi push`.

The Nx Cloud steps need an `NX_CLOUD_ACCESS_TOKEN`. Without it they fail or degrade to
running everything on the one runner.

## Running CI locally with act

[act](https://github.com/nektos/act) executes the workflow on your machine in Docker
containers, so you can iterate on CI without pushing commits.

```sh
brew install act
```

Docker Desktop must be running, since act creates containers for each job.

```sh
act -l                 # list jobs in the workflow
act -n                 # dry run: validate the workflow, execute nothing
act                    # run the push event
act pull_request       # run the pull_request event instead
act -j main            # run just the 'main' job
```

### On Apple Silicon

Most action images are amd64 only, and act warns about this on M-series Macs:

```
⚠ You are using Apple M-series chip and you have not specified container architecture,
you might encounter issues while running act. If so, try running it with
'--container-architecture linux/amd64' ⚠
```

So pass it:

```sh
act --container-architecture linux/amd64
```

That runs under emulation and is noticeably slower than native.

### Secrets

This workflow needs an Nx Cloud token. Either pass it inline:

```sh
act -s NX_CLOUD_ACCESS_TOKEN=<token>
```

or put it in a `.secrets` file, which act reads by default:

```
NX_CLOUD_ACCESS_TOKEN=<token>
```

**Add `.secrets` to `.gitignore` before you create it** — it holds a live credential.

### Things that behave differently than on GitHub

- **Nx Cloud distribution doesn't distribute.** `--distribute-on="3 linux-medium-js"`
  spins up remote agents on real CI; locally everything runs in the one container.
- **`cache: npm` gives you nothing.** There's no GitHub cache backend, so `npm ci`
  downloads afresh every run.
- **Artifact upload needs a server.** Add
  `--artifact-server-path /tmp/act-artifacts` if you add steps that upload artifacts.
- **First run asks which image size to use.** Medium is the reasonable default; pin it
  explicitly with `-P ubuntu-latest=catthehacker/ubuntu:act-latest`.
- **Images are large** — several GB for the Ubuntu runner image on first pull.

