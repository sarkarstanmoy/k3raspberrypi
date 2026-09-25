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
docker login 192.168.1.187:30050 -u admin -p CHANGE_ME

docker build -t 192.168.1.187:30050/healthcheck:latest ./apps/healthcheck
docker push 192.168.1.187:30050/healthcheck:latest
```

If the registry is private, use the same username/password you configured for Zot.

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
  --docker-password=CHANGE_ME
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
docker login 192.168.1.187:30050 -u admin -p CHANGE_ME
docker build -t 192.168.1.187:30050/healthcheck:latest ./apps/healthcheck
docker push 192.168.1.187:30050/healthcheck:latest
```

### 2) Create the pull secret in K3s

```sh
kubectl -n default create secret docker-registry regcred \
  --docker-server=192.168.1.187:30050 \
  --docker-username=admin \
  --docker-password=CHANGE_ME
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

## Nx workspace

<a alt="Nx logo" href="https://nx.dev" target="_blank" rel="noreferrer"><img src="https://raw.githubusercontent.com/nrwl/nx/master/images/nx-logo.png" width="45"></a>

This repo is an [Nx workspace](https://nx.dev).

[Learn more about this workspace setup and its capabilities](https://nx.dev/docs/technologies/typescript/introduction?utm_source=nx_project&utm_medium=readme&utm_campaign=nx_projects) or run `npx nx graph` to visually explore what was created. Now, let's get you up to speed!

🚀 If you haven't connected to Nx Cloud yet, [complete your setup here](https://cloud.nx.app/get-started). Get faster builds with remote caching, distributed task execution, and self-healing CI. [See how your workspace can benefit](#nx-cloud).

## Generate a library

```sh
npx nx g @nx/js:lib packages/pkg1 --publishable --importPath=@my-org/pkg1
```

## Run tasks

To build the library use:

```sh
npx nx run pkg1:build
```

To run any task with Nx use:

```sh
npx nx run <project-name>:<target>
```

These targets are either [inferred automatically](https://nx.dev/docs/concepts/inferred-tasks?utm_source=nx_project&utm_medium=readme&utm_campaign=nx_projects) or defined in the `project.json` or `package.json` files.

[More about running tasks in the docs &raquo;](https://nx.dev/docs/features/run-tasks?utm_source=nx_project&utm_medium=readme&utm_campaign=nx_projects)

## Versioning and releasing

To version and release the library use

```
npx nx release
```

Pass `--dry-run` to see what would happen without actually releasing the library.

[Learn more about Nx release &raquo;](https://nx.dev/docs/features/manage-releases?utm_source=nx_project&utm_medium=readme&utm_campaign=nx_projects)

## Keep TypeScript project references up to date

Nx automatically updates TypeScript [project references](https://www.typescriptlang.org/docs/handbook/project-references.html) in `tsconfig.json` files to ensure they remain accurate based on your project dependencies (`import` or `require` statements). This sync is automatically done when running tasks such as `build` or `typecheck`, which require updated references to function correctly.

To manually trigger the process to sync the project graph dependencies information to the TypeScript project references, run the following command:

```sh
npx nx sync
```

You can enforce that the TypeScript project references are always in the correct state when running in CI by adding a step to your CI job configuration that runs the following command:

```sh
npx nx sync:check
```

[Learn more about nx sync](https://nx.dev/reference/nx-commands#sync)

## Nx Cloud

Nx Cloud ensures a [fast and scalable CI](https://nx.dev/nx-cloud?utm_source=nx_project&utm_medium=readme&utm_campaign=nx_projects) pipeline. It includes features such as:

- [Remote caching](https://nx.dev/docs/features/ci-features/remote-cache?utm_source=nx_project&utm_medium=readme&utm_campaign=nx_projects)
- [Task distribution across multiple machines](https://nx.dev/docs/features/ci-features/distribute-task-execution?utm_source=nx_project&utm_medium=readme&utm_campaign=nx_projects)
- [Automated e2e test splitting](https://nx.dev/docs/features/ci-features/split-e2e-tasks?utm_source=nx_project&utm_medium=readme&utm_campaign=nx_projects)
- [Task flakiness detection and rerunning](https://nx.dev/docs/features/ci-features/flaky-tasks?utm_source=nx_project&utm_medium=readme&utm_campaign=nx_projects)

### Set up CI (non-Github Actions CI)

**Note:** This is only required if your CI provider is not GitHub Actions.

Use the following command to configure a CI workflow for your workspace:

```sh
npx nx g ci-workflow
```

[Learn more about Nx on CI](https://nx.dev/docs/features/ci-features?utm_source=nx_project&utm_medium=readme&utm_campaign=nx_projects)

## Install Nx Console

Nx Console is an editor extension that enriches your developer experience. It lets you run tasks, generate code, and improves code autocompletion in your IDE. It is available for VSCode and IntelliJ.

[Install Nx Console &raquo;](https://nx.dev/docs/getting-started/editor-setup?utm_source=nx_project&utm_medium=readme&utm_campaign=nx_projects)

## 🔗 Learn More

- [Nx Documentation](https://nx.dev/docs)
- [Crafting Your Workspace Tutorial](https://nx.dev/docs/getting-started/tutorials/crafting-your-workspace)
- [Module Boundaries](https://nx.dev/docs/features/enforce-module-boundaries)
- [Releasing Packages](https://nx.dev/docs/features/manage-releases)
- [Nx Plugins](https://nx.dev/docs/concepts/nx-plugins)
- [Nx Cloud](https://nx.dev/nx-cloud)

## 💬 Community

Join the Nx community:

- [Discord](https://go.nx.dev/community)
- [X (Twitter)](https://twitter.com/nxdevtools)
- [LinkedIn](https://www.linkedin.com/company/nrwl)
- [YouTube](https://www.youtube.com/@nxdevtools)
- [Blog](https://nx.dev/blog)
