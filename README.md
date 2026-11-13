# terraform-azurerm-helpdesk

OpenTofu / Terraform code that deploys [DuploCloud](https://duplocloud.com) **Helpdesk** into your own Azure
subscription: a VNet with NAT egress, an Application Gateway with your TLS certificate, an AKS cluster with
the Application Gateway Ingress Controller, an Azure Files NFS share, optional Azure DNS records, and the
Helpdesk Helm release.

Every layer can be **created** or can **adopt** something you already have (an existing resource group,
VNet, gateway, cluster or storage account). Adopted resources are read, never modified. So the same code
serves a greenfield subscription and one with an established platform.

This repository is used on its own, and it is also what the DuploCloud DevKit's Cloud Deployment agent
runs. The agent pins a release of this repo and generates its setup wizard from these variables. It follows
the same contract as [`terraform-aws-helpdesk`](https://github.com/duplocloud/terraform-aws-helpdesk).

## Layout

```
platform/     root 1: everything created through the Azure API (state: platform.tfstate)
app/          root 2: everything created through the Kubernetes API (state: app.tfstate)
modules/
  network/    network layer      VNet, AKS / gateway / private-endpoint subnets, NSGs, NAT gateway
  gateway/    gateway layer      Application Gateway v2 (optional WAF), public IP, TLS certificate
  aks/        cluster layer      AKS (Entra ID + Azure RBAC, CNI Overlay), AGIC add-on and its roles
  files/      storage layer      Premium Azure Files NFS share behind a private endpoint
  dns/        dns layer          A records in an existing Azure DNS zone
  addons/     addons layer       storage classes
  helpdesk/   helpdesk layer     namespace, static NFS volume, the Helpdesk Helm release
```

The `resource_group` layer is a single resource in the platform root.

There are two roots because the `app` root configures the Helm and Kubernetes providers from a cluster
that must already exist. Apply `platform` first, then `app`. The `app` root reads the platform outputs
from the platform state with `terraform_remote_state`.

## Requirements

- OpenTofu 1.10 or later. Terraform 1.10+ also works.
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) and
  [kubelogin](https://azure.github.io/kubelogin/install.html). The `app` root gets its Kubernetes token
  from kubelogin, because AKS local accounts are disabled (automation without kubelogin can pass a token
  instead: `kube_login = "token"`, see Inputs).
- An Azure identity that can create resources and role assignments: Owner, or Contributor plus Role Based
  Access Control Administrator, on the subscription (or on the resource group, with
  `resource_group.mode = "existing"`). Use `az login`, or a service principal in `ARM_CLIENT_ID`,
  `ARM_CLIENT_SECRET`, `ARM_TENANT_ID` (then set `kube_login = "spn"` in the app root).
- A storage account with a blob container for state; your identity needs Storage Blob Data Contributor
  on it.
- A TLS certificate as a PFX (full chain plus private key) covering both Helpdesk hostnames.
- A [Microsoft Foundry](https://learn.microsoft.com/azure/ai-foundry/) Claude deployment: its Anthropic
  endpoint (`https://<resource>.services.ai.azure.com/anthropic`) and key.
- For Microsoft sign-in: an Entra ID app registration (web platform) with the redirect URIs
  `https://<host>/app/signin-microsoft` and `https://<host>/api/Account/ExternalLoginCallback`, and a
  client secret.

## Inputs

Both roots take one object per layer:

```hcl
network = {
  mode     = "create"        # or "existing"
  values   = { ... }         # optional module arguments, by variable name
  provides = { ... }         # for "existing": the adopted resource's identifiers
}
```

With `mode = "create"` the layer's module runs, with `values` overriding its defaults. Every module
variable has a sensible default, so `values = {}` works. With an adopt mode, the module is not
instantiated and the root uses `provides` instead.

| Layer | Root | Modes | `provides` for adopt modes |
|---|---|---|---|
| `resource_group` | platform | `create`, `existing` | `name` |
| `network` | platform | `create`, `existing` | `vnet_id`, `aks_subnet_id`, `app_gateway_subnet_id`, `private_endpoint_subnet_id`, optional `nat_public_ip` |
| `gateway` | platform | `create`, `existing` | `app_gateway_id`, `public_ip`, `ssl_certificate_name`, optional `identity_id` |
| `cluster` | platform | `create`, `existing` (must already run AGIC for the gateway) | `cluster_name`, `cluster_id`, `cluster_endpoint`, `cluster_ca_certificate`, optional `oidc_issuer_url` |
| `storage` | platform | `create`, `existing` | `account_name`, `resource_group_name`, `backend_share_name`, optional `backend_share_gib` |
| `dns` | platform | `azure_dns` (A records in an existing zone: `values.zone_name`, `values.zone_resource_group_name`), `external` (you create the records) | none |
| `addons` | app | `create`, `existing` | none |
| `helpdesk` | app | `create` | none |

Other inputs:

- `deployment` (both roots): `{ name, region, host, xterm_host, account_id }`. `host` and
  `xterm_host` are the Helpdesk hostnames. `account_id` is the Azure subscription ID
  (the name the AWS and GCP repos use for the account or project).
- `secrets` (platform root, sensitive map): `tls_pfx_base64` (the PFX, base64-encoded) and
  `tls_pfx_password`. Not needed when `gateway.values.key_vault_secret_id` points at a Key Vault
  certificate (with `key_vault_identity_id`), or when the gateway is adopted.
- `state` (app root): `{ resource_group_name, storage_account_name, container_name, platform_key }`,
  where the platform state lives.
- `secrets` (app root, sensitive map): `azure_api_key` (the Foundry key), `licensing_token`, and depending
  on the login method `local_admin_password`, `google_client_secret` or `microsoft_client_secret`;
  optional `slack_app_token`, `slack_bot_token`.
- `kube_login` (app root): kubelogin login method, `azurecli` (default), `spn`, `workloadidentity` or
  `msi`; or `token`, where kubelogin is not used and both providers read a pre-minted Entra ID token for
  the AKS server app from the `KUBE_TOKEN` environment variable (for automation without the kubelogin
  binary; the token is not saved in the plan file).
- `common_tags` (both roots): tags for every resource.

Pass both `secrets` maps as `TF_VAR_secrets` so they never land in a file. The module variables
(`modules/*/variables.tf`) are the full list of `values` each layer accepts, with descriptions and
defaults. Notable ones: `cluster.values.api_authorized_ip_ranges` (limit the Kubernetes API to your IP;
the NAT egress IP is added automatically), `cluster.values.node_vm_size`, `gateway.values.sku_name`
(`WAF_v2` for a web application firewall), and `helpdesk.values.login_method`, `azure_base_url`,
`auth_super_users`, `xterm_enabled`, `chart_version`.

## Usage

Greenfield example inputs are in [`examples/greenfield/`](examples/greenfield/).

```bash
az login
az account set --subscription <SUBSCRIPTION_ID>

# 1. platform
cd platform
cat > backend.hcl <<EOF
resource_group_name  = "tfstate-rg"
storage_account_name = "mytfstate"
container_name       = "tfstate"
key                  = "helpdesk/platform.tfstate"
use_azuread_auth     = true
EOF
tofu init -backend-config=backend.hcl
export TF_VAR_secrets="$(jq -n --arg pfx "$(base64 < cert.pfx | tr -d '\n')" --arg pw "$(cat cert-password.txt)" \
  '{tls_pfx_base64: $pfx, tls_pfx_password: $pw}')"
tofu plan  -var-file=../examples/greenfield/platform.tfvars.json -out=platform.tfplan
tofu apply platform.tfplan

# 2. if dns mode is "external": point both hostnames at the gateway (A records)
tofu output -json dns_records

# 3. app (wait ~5 minutes after the platform apply: the ingress controller's role
#    assignments need time to propagate)
cd ../app
sed 's/platform.tfstate/app.tfstate/' ../platform/backend.hcl > backend.hcl
tofu init -backend-config=backend.hcl
export TF_VAR_secrets='{"azure_api_key":"...","microsoft_client_secret":"..."}'
tofu plan  -var-file=../examples/greenfield/app.tfvars.json -out=app.tfplan
tofu apply app.tfplan
tofu output helpdesk_url
```

Sign in with an account listed in `auth_super_users` to get the admin role.

Destroy in the reverse order: `app`, then `platform`. Adopted resources are left untouched.

## Outputs

`platform`: resource group, network, gateway, cluster and storage identifiers (`app_gateway_public_ip`,
`cluster_name`, `cluster_endpoint`, `storage_account_name`, `nat_public_ip`, `dns_mode`, `dns_records`,
and more; see `platform/outputs.tf`). `app`: `helpdesk_url`, `load_balancer_hostname` (the gateway's public IP), `dns_records` (the
records to create when DNS is external), and the sensitive `secrets` and `generated`.

## Notes

- **Defender / Azure Policy**: if subscription policy enables Microsoft Defender or Azure Policy on the
  cluster after creation, a later plan proposes removing them. Don't apply that; set
  `cluster.values.microsoft_defender_log_analytics_workspace_id` and `azure_policy_enabled` to the
  cluster's actual values
  (`az aks show -g <rg> -n <cluster> --query "{defender:securityProfile.defender.logAnalyticsWorkspaceResourceId, policy:addonProfiles.azurepolicy.enabled}"`).
- **Your IP changed**: update `cluster.values.api_authorized_ip_ranges` and apply the platform root
  before the app root.
- **Foundry with network restrictions**: allow the `nat_public_ip` output.

## Security

- Secrets enter only through the sensitive `secrets` variables. Nothing is written to local files, and Helm
  values are passed in memory.
- The TLS certificate, the JWT shared secret and the MongoDB root password (generated with
  `random_password`) are kept in state. Protect the state storage account accordingly (Entra ID access
  only, versioning, restricted access).
- AKS local accounts are disabled; Kubernetes access is Entra ID with Azure RBAC.
- The NFS share has no public network access and no account keys; pods reach it through a private endpoint.
- Provider versions and checksums are pinned by the committed `.terraform.lock.hcl` in each root.

## Tests

```bash
cd platform && tofu init -backend=false && tofu test
cd ../app   && tofu init -backend=false && tofu test
```

The tests use mock providers and cover every layer mode; they need no Azure subscription. The platform
tests stand in for the `aks` module (`override_module`), because a mock cannot fill the AGIC identity it
reads; `tofu validate` still checks the module.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Changes must keep existing deployments upgradeable; the rules are
listed there.

## License

Apache License 2.0. See [LICENSE](LICENSE).
