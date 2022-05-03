# Y Meadows Github Actions

Using these actions:

```
- uses: actions/checkout@v2-beta # check out your code
- name: Run the Trivy Scan action
  uses: ymeadows/github-actions-public/trivy-scan
```

## Action Catalog

| Directory | Purpose |
| --- | --- |
| `tag-next-version` | Increments the patch version from the highest existing tag, and tags the repo with that new version |
| `docker-build-and-push` | Builds a docker image, based on the local Dockerfile, tags and pushes it to all our registries |
| `trivy-scan` | Runs the Aqua Security Trivy security scanner on an image |

### Library Actions

These are used by the "published" actions -
nothing stops their use in workflows,
but they're not built or maintained with that in mind.

| Directory | Purpose |
| --- | --- |
| `lib/rolling-versions` | Takes a version string as input and increments it |
| `lib/setup-gcr` | Configures Google Container Registry access |


## Full Example

```
name: Build And Push

on:
  push:
    branches:
    - main
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2-beta # check out your code
    - id: increment-version
      uses: ymeadows/github-actions-public/tag-next-version@v1
      with:
        prefix: v
    - uses: ymeadows/github-actions-public/docker-build-and-push@v1
      with:
        prefix: v
        version: ${{ steps.increment-version.outputs.new-tag }}
        gcp_service_account_key: ${{ secrets.GCP_PROD_SERVICE_ACCOUNT_KEY }}
```
