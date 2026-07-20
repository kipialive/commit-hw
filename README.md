# commit-hw

CommIT homework infrastructure for the `commit-dev` environment.

## Status

The public API endpoint is working end-to-end:

```text
https://api.commit-dev.cloudsmesh.be/
```

Expected response:

```json
{"status":"ok","service":"commit-api","environment":"commit-dev","transport":"https-all-the-way"}
```

## Architecture

The project builds a two-perimeter GCP setup:

- Project A: public perimeter with Cloud Armor, External HTTPS Load Balancer, Google-managed SSL, and a PSC NEG.
- Project B: private GKE Standard cluster, internal Traefik LoadBalancer, and the `commit-api` workload.
- CI/CD: GitHub Actions authenticates to GCP through Workload Identity Federation, without static service account keys.

Traffic flow:

```text
Cloudflare DNS-only
-> Google External HTTPS Load Balancer
-> Google-managed SSL certificate
-> Private Service Connect NEG
-> PSC Service Attachment
-> GKE Internal LoadBalancer
-> Traefik websecure entryPoint
-> commit-api Kubernetes Service over HTTPS
-> nginx pod HTTPS listener
```

## DNS

The domain `cloudsmesh.be` is managed in Cloudflare.

Required record:

```text
Type: A
Name: api.commit-dev
Target: 136.69.54.142
Proxy status: DNS only
```

Private platform records after Twingate/private access is ready:

```text
Type: A
Name: *.dev
Target: 172.17.10.17
Proxy status: DNS only
```

`*.dev.cloudsmesh.be` points to the Traefik Kubernetes Service `ClusterIP` because the Twingate connector runs inside GKE. This private address is intended for access through Twingate, not directly from the public Internet.

Do not use Cloudflare `Proxied` for `api.commit-dev.cloudsmesh.be` on the free plan. Cloudflare Universal SSL covers `*.cloudsmesh.be`, but not the deeper hostname `api.commit-dev.cloudsmesh.be`. The Google-managed certificate is active when DNS resolves directly to the Google LB IP.

## GitHub Actions

Working workflows:

- `.github/workflows/env-dev--deploy-commit-api.yaml`
- `.github/workflows/env-dev--deploy-traefik-ingressroutes.yaml`

Additional workflows:

- `.github/workflows/env-dev--deploy-traefik-reverse-proxy.yaml`
- `.github/workflows/env-dev--installation-sealed-secrets-controller.yaml`
- `.github/workflows/env-dev--installation-cert-manager.yaml`
- `.github/workflows/env-dev--deploy-all.yaml`

The GitHub environment `commit-dev` must contain:

- `COMMIT_HW_GCP_PROJECT_ID_B`
- `COMMIT_HW_GCP_REGION_DEV`
- `COMMIT_HW_GCP_PROJECT_B_NUMBER`
- `COMMIT_HW_GCP_SERVICE_ACCOUNT_PROJECT_B`

## Deployment Order

1. Apply base Terraform for VPC, GKE, NAT, and initial networking.
2. Deploy Sealed Secrets controller.
3. Deploy Traefik Reverse Proxy.
4. Apply Terraform resources that depend on the Traefik Service: PSC attachment, PSC endpoint, PSC NEG, External HTTPS LB, and Google-managed SSL.
5. Configure the Cloudflare DNS record as `DNS only`.
6. Deploy `commit-api`.
7. Deploy Traefik IngressRoutes.
8. Validate the public endpoint.

## Current Kubernetes Routing

`commit-api` is deployed as an HTTPS-only demo backend. It exposes:

- `/healthz` -> `ok`
- `/` -> JSON status response

The Traefik `IngressRoute` for `api.commit-dev.cloudsmesh.be` lives in the Traefik chart:

```text
.github/helm-charts/env-dev/traefik-reverse-proxy/traefik/templates/ingressroutes/ingressroute-commit-api.yaml
```

The application chart does not own the route.

## Source Ranges

The Traefik internal LoadBalancer is restricted to:

```text
10.10.0.0/16
10.20.0.0/16
10.30.0.0/24
35.191.0.0/16
130.211.0.0/22
```

The Google ranges are required for the external Application Load Balancer / GFE path through PSC.

## Validation

```bash
dig api.commit-dev.cloudsmesh.be +short
curl -Iv https://api.commit-dev.cloudsmesh.be/
curl https://api.commit-dev.cloudsmesh.be/
kubectl get pods -n commit-api -o wide
kubectl get svc -n commit-api
kubectl get ingressroutes -A
kubectl get serverstransports -A
```

Expected DNS:

```text
136.69.54.142
```

Expected curl result:

```text
HTTP/2 200
server: nginx/1.29.8
via: 1.1 google
```

## Sealed Secrets

Sealed Secrets controller is installed in GKE. It is used for the Traefik Dashboard basic-auth secret.

## cert-manager

Public API:
api.commit-dev.cloudsmesh.be -> 136.69.54.142

```text
api.commit-dev.cloudsmesh.be
  -> Internet
  -> Google External HTTPS LB
  -> Google-managed SSL
  -> PSC
  -> Traefik
  -> commit-api HTTPS service
```

Private (Internal) platform apps:
*.dev.cloudsmesh.be -> 172.17.10.17
Access only via Twingate VPN

```text
traefik-dashboard.dev.cloudsmesh.be
coroot.dev.cloudsmesh.be
  -> Twingate VPN
  -> Twingate connector pod in GKE
  -> Traefik Kubernetes Service ClusterIP
  -> Traefik IngressRoute
  -> service
```

cert-manager is configured to issue Let's Encrypt certificates through Cloudflare DNS-01 for private Traefik platform routes.

The ClusterIssuer expects this Kubernetes Secret in the `cert-manager` namespace:

```text
Secret: cloudflare-api-token-secret
Key: api-token
```

The Cloudflare API token should have permission to edit DNS records for `cloudsmesh.be`.

Temporary plain Secret command for testing:

```bash
kubectl create secret generic cloudflare-api-token-secret \
  --namespace cert-manager \
  --from-literal=api-token='<cloudflare-api-token>'
```

For GitOps-safe storage, seal the token with Sealed Secrets and commit only the `SealedSecret` manifest.

cert-manager owns these Traefik TLS secrets:

```text
traefik-reverse-proxy/dev-cloudsmesh-be-staging-tls
traefik-reverse-proxy/dev-cloudsmesh-be-prod-tls
```

Traefik private `IngressRoute` resources reference the production secret through `tls.secretName`.

The public API stays on the Google-managed certificate attached to the external Google HTTPS Load Balancer.

## Twingate

The Twingate connector is installed in GKE through Helm. The working private access path is:

```text
Mac Twingate client
-> Twingate relay/control plane
-> Twingate connector pod in GKE
-> traefik-reverse-proxy Service ClusterIP 172.17.10.17
-> Traefik websecure
-> private app IngressRoute
```

Validation:

```bash
dig traefik-dashboard.dev.cloudsmesh.be +short
curl -Iv https://traefik-dashboard.dev.cloudsmesh.be/dashboard/
```

Expected result:

```text
SSL certificate verify ok
HTTP/2 401
www-authenticate: Basic realm="traefik"
```

`401` is expected because the Traefik Dashboard route is protected by basic-auth.

## Next Step

Add the next private platform application route, for example `coroot.dev.cloudsmesh.be`, using the same `dev-cloudsmesh-be-prod-tls` certificate.
