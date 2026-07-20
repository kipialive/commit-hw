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

## Next Step

Configure cert-manager and certificate handling for Traefik Reverse Proxy resources.
