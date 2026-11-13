# Contributing

## Development

```bash
tofu fmt -recursive
cd platform && tofu init -backend=false && tofu validate && tofu test
cd ../app   && tofu init -backend=false && tofu validate && tofu test
cd .. && tflint --init && tflint --recursive --config "$PWD/.tflint.hcl"
```

CI runs the same commands with OpenTofu 1.13.2 and TFLint 0.65.0 on every pull request.

## The contract

The DuploCloud Cloud Deployment agent pins releases of this repo, renders a setup wizard from the module
variables, and runs the two roots. This repo follows the same contract as `terraform-aws-helpdesk`; keep
these properties, or the agent (and every other cloud's equivalent repo) breaks:

- **Layout**: `platform/`, `app/`, `modules/<module>/` at the repo root. Roots reference modules as
  `../modules/<module>`. Each root has `versions.tf`, `backend.tf` with an empty `backend "azurerm" {}`
  block, `variables.tf`, `main.tf`, `outputs.tf`, `tests/`, and a committed `.terraform.lock.hcl`.
- **Layers**: `resource_group`, `network`, `gateway`, `cluster`, `storage`, `dns` in `platform`; `addons`,
  `helpdesk` in `app`. Each is one root variable `{ mode, values, provides }`.
- **Modes**: `create` runs the layer's module (`count = 1`). An adopt mode runs it with `count = 0` and
  reads `var.<layer>.provides.<name>` instead. Adopt modes never create anything that changes the adopted
  resource. (`resource_group` is a single resource in the root rather than a module.)
- **Values**: roots pass module arguments as `try(var.<layer>.values.<name>, null)` so an omitted value
  falls back to the module default. Every module variable that a user can set has a `description`.
- **Root inputs**: `deployment` `{ name, region, host, xterm_host, account_id }`, `state` (app root),
  `secrets` (sensitive map: the TLS certificate in `platform`, application secrets in `app`),
  `common_tags`.
- **Outputs**: the output names in `platform/outputs.tf` and `app/outputs.tf` are part of the contract.
- **No secrets on disk**: no `local_file`/`local_sensitive_file`; secrets only via `var.secrets`; generated
  secrets via `random_password`.
- **No `ui.yaml`** or other wizard files: the agent keeps its presentation layer in its own repo.

## Where this repo differs from `terraform-aws-helpdesk`

Deliberate, so keep them unless the AWS repo changes too:

- **Two extra platform layers.** `resource_group` holds everything the deployment creates (a single
  resource in the root, no module). `gateway` is the Application Gateway v2 that serves Helpdesk through the
  AGIC add-on, where AWS uses an ALB created by the load balancer controller.
- **`secrets` on the platform root too.** It carries the TLS certificate for the gateway (`tls_pfx_base64`,
  `tls_pfx_password`), unless `gateway.values.key_vault_secret_id` names a Key Vault certificate. AWS issues
  the certificate with ACM and needs no platform secrets.
- **`kube_login` on the app root.** AKS runs with local accounts off, so the Kubernetes and Helm providers
  authenticate with Entra ID through kubelogin, or with `token`, which reads a pre-minted token from the
  `KUBE_TOKEN` environment variable (the agent uses this; a token in a variable would be saved in the plan
  file). AWS gets a token without an exec plugin.
- **No `certificate_arn` output.** The certificate is the uploaded PFX or an existing Key Vault certificate,
  so there is no issuance or DNS validation to wait for.
- **Validation blocks on the layer variables** (`platform/variables.tf`, `app/variables.tf`), as on GCP.
  They reject inputs that would otherwise plan and fail late (a gateway with no certificate, `azure_dns`
  with no zone, a missing admin email).
- **Names reused from AWS where the concept is the same**, even though the Azure values differ:
  `deployment.account_id` is the subscription ID, `vpc_id` the VNet ID, `load_balancer_hostname` the
  gateway's public IP, and `state.bucket` the state storage account (`state.resource_group_name` and
  `state.container_name` are optional and default to the agent's names).
- **Each module has its own `versions.tf`** and **CI also runs TFLint** (`.tflint.hcl`), as on GCP.
- **Sign-in is the local admin only** (`helpdesk.values.local_admin_email`, `secrets.local_admin_password`),
  as on GCP; the local admin is the only super user. SSO is set up in Helpdesk after deployment.

## Upgrade safety

Every release reaches existing deployments: the agent moves customers to the newly pinned release on their
next plan. A user always reviews the plan before anything is applied, but a release must not make that plan
destructive for no reason.

- Renaming or moving a resource (including into or out of a module, or changing a `count`/`for_each` key)
  needs a `moved` block.
- A new variable must have a `default` (and `nullable = false` unless null means something). A deployment
  created with an older release must plan without new inputs.
- Removing or renaming a variable or an output, changing a variable's type, or a provider major version
  bump is a **breaking change**: list it under "Breaking changes" in the release notes.
- Do not change defaults that would replace existing resources (VM sizes, CIDRs, names, zones) without a
  breaking-change note.

## Providers and lock files

After changing a `required_providers` block, regenerate the lock files for all platforms the agent runs on:

```bash
for r in platform app; do
  (cd $r && tofu init -backend=false -upgrade && tofu providers lock \
     -platform=linux_amd64 -platform=linux_arm64 -platform=darwin_amd64 -platform=darwin_arm64)
done
```

## Releases

Semver tags `vX.Y.Z` on `main`, never moved or deleted (the agent pins the tag and its commit SHA). The
GitHub release notes list, per module: variables added, removed or changed; outputs added or removed;
provider version changes; and a "Breaking changes" section (or "None").
