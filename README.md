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

Private platform access is also working through Twingate:

```text
https://traefik-dashboard.dev.cloudsmesh.be/dashboard/
https://uptime.dev.cloudsmesh.be/
```

The private routes use a Let's Encrypt wildcard certificate issued by cert-manager for `*.dev.cloudsmesh.be`.

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

Private platform flow:

```text
Mac Twingate client
-> Twingate relay/control plane
-> Twingate connector pod in GKE
-> traefik-reverse-proxy Service ClusterIP 172.17.10.17
-> Traefik websecure entryPoint
-> private app IngressRoute
-> Kubernetes Service
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
- `.github/workflows/env-dev--installation-cert-manager.yaml`
- `.github/workflows/env-dev--installation-uptime-kuma.yaml`

Additional workflows:

- `.github/workflows/env-dev--deploy-traefik-reverse-proxy.yaml`
- `.github/workflows/env-dev--installation-sealed-secrets-controller.yaml`
- `.github/workflows/env-dev--deploy-all.yaml`

The GitHub environment `commit-dev` must contain:

- `COMMIT_HW_GCP_PROJECT_ID_B`
- `COMMIT_HW_GCP_REGION_DEV`
- `COMMIT_HW_GCP_PROJECT_B_NUMBER`
- `COMMIT_HW_GCP_SERVICE_ACCOUNT_PROJECT_B`

### Deploy All

`.github/workflows/env-dev--deploy-all.yaml` is the post-Terraform Kubernetes stack orchestrator. It does not create Terraform resources, Cloudflare DNS records, or Twingate account resources. It only calls the existing reusable GitHub Actions workflows in order:

```text
sealed-secrets
-> cert-manager
-> traefik
-> commit-api
-> uptime-kuma
-> ingressroutes
```

Use it after the GCP infrastructure exists and the required manual/private prerequisites are already in place.

## Deployment Order

1. Apply base Terraform for VPC, GKE, NAT, and initial networking.
2. Deploy Sealed Secrets controller.
3. Create and commit the sealed Cloudflare API token for cert-manager DNS-01.
4. Deploy cert-manager resources and issue the `*.dev.cloudsmesh.be` wildcard certificate.
5. Deploy Traefik Reverse Proxy.
6. Apply Terraform resources that depend on the Traefik Service: PSC attachment, PSC endpoint, PSC NEG, External HTTPS LB, and Google-managed SSL.
7. Configure Cloudflare DNS records as `DNS only`.
8. Deploy `commit-api`.
9. Install Twingate connector in GKE and configure private resources.
10. Deploy Uptime Kuma.
11. Deploy or refresh Traefik IngressRoutes.
12. Validate public and private endpoints.

After Terraform and manual prerequisites are ready, `.github/workflows/env-dev--deploy-all.yaml` can run the Kubernetes/application part in one pass.

## Current Kubernetes Routing

`commit-api` is deployed as an HTTPS-only demo backend. It exposes:

- `/healthz` -> `ok`
- `/` -> JSON status response

The Traefik `IngressRoute` for `api.commit-dev.cloudsmesh.be` lives in the Traefik chart:

```text
.github/helm-charts/env-dev/traefik-reverse-proxy/traefik/templates/ingressroutes/ingressroute-commit-api.yaml
```

The application chart does not own the route.

Private platform routes live in the same Traefik chart:

```text
.github/helm-charts/env-dev/traefik-reverse-proxy/traefik/templates/ingressroutes/ingressroute-traefik-dashboard.yaml
.github/helm-charts/env-dev/traefik-reverse-proxy/traefik/templates/ingressroutes/ingressroute-uptime-kuma.yaml
```

They use:

```text
traefik-reverse-proxy/dev-cloudsmesh-be-prod-tls
```

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

Sealed Secrets controller is installed in GKE. It is used for:

- Traefik Dashboard basic-auth secret.
- Cloudflare DNS-01 API token for cert-manager.

Plain Kubernetes Secret manifests should not be committed. Only `SealedSecret` manifests are stored in Git.

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
uptime.dev.cloudsmesh.be
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

## Uptime Kuma

Uptime Kuma is deployed in the `monitoring` namespace with a `ClusterIP` Service on port `3001`.

```text
https://uptime.dev.cloudsmesh.be/
```

The Traefik route uses the same wildcard certificate:

```text
traefik-reverse-proxy/dev-cloudsmesh-be-prod-tls
```

Recommended monitor for Traefik Dashboard:

```text
Monitor Type: HTTP(s)
Friendly Name: Traefik Dashboard
URL: https://traefik-dashboard.dev.cloudsmesh.be/dashboard/
Accepted Status Codes: 401
Heartbeat Interval: 60 seconds
Retries: 3
Timeout: 10 seconds
Certificate Expiry Notification: ON
```

`401` is the healthy expected status for this monitor because the dashboard route is protected by basic-auth and should challenge unauthenticated requests.

## Manual Prerequisites

Cloudflare DNS:

```text
api.commit-dev.cloudsmesh.be -> 136.69.54.142
*.dev.cloudsmesh.be -> 172.17.10.17
Proxy status: DNS only
```

cert-manager DNS-01:

```text
Secret: cert-manager/cloudflare-api-token-secret
Key: api-token
Stored in Git as a SealedSecret
```

Twingate:

```text
Connector: installed in GKE through Helm
Private resource: *.dev.cloudsmesh.be
Target: 172.17.10.17
Access: Root-Admin or selected users/groups
```

Terraform:

```text
external_lb_public_ip = 136.69.54.142
Traefik ClusterIP = 172.17.10.17
Traefik ILB VIP = 10.20.0.7
```

The Twingate connector runs inside GKE, so private DNS points to the Traefik `ClusterIP` instead of the GCP Internal LoadBalancer VIP.

## Final Validation

Public API:

```bash
dig api.commit-dev.cloudsmesh.be +short
curl -Iv https://api.commit-dev.cloudsmesh.be/
curl https://api.commit-dev.cloudsmesh.be/
```

Expected:

```text
136.69.54.142
HTTP/2 200
{"status":"ok","service":"commit-api","environment":"commit-dev","transport":"https-all-the-way"}
```

Private Traefik Dashboard through Twingate:

```bash
dig traefik-dashboard.dev.cloudsmesh.be +short
curl -Iv https://traefik-dashboard.dev.cloudsmesh.be/dashboard/
```

Expected:

```text
SSL certificate verify ok
HTTP/2 401
www-authenticate: Basic realm="traefik"
```

Uptime Kuma:

```bash
curl -Iv https://uptime.dev.cloudsmesh.be/
kubectl get pods,svc,pvc -n monitoring -o wide
kubectl get ingressroute uptime-kuma -n traefik-reverse-proxy
```

cert-manager:

```bash
kubectl get clusterissuer
kubectl get certificate -A
kubectl get secret dev-cloudsmesh-be-prod-tls -n traefik-reverse-proxy
```

## Next Step

Commit the current working state, then use Uptime Kuma to monitor the public API and private platform routes.
