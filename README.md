# commit-hw

CommIT homework infrastructure for the `commit-dev` environment.

## Architecture

The project builds a two-perimeter GCP setup:

- Project A: public perimeter with Cloud Armor, External HTTPS Load Balancer and a PSC NEG.
- Project B: private GKE Standard cluster, internal Traefik LoadBalancer and the demo API workload.
- Traffic path: user -> Google External HTTPS LB -> PSC -> Traefik `websecure` -> `commit-api` Service over HTTPS -> pod HTTPS listener.

## Manual DNS Step

The domain `cloudsmesh.be` is managed in Cloudflare. Create this DNS record manually:

- Type: `A`
- Name: `api.commit-dev`
- Target: `136.69.54.142`
- Proxy status: DNS only, unless Cloudflare proxying is intentionally part of the test.

After DNS propagation, the Google-managed certificate for `api.commit-dev.cloudsmesh.be` can become active.

## Deployment Order

1. Apply base Terraform for VPC, GKE, NAT and the initial network resources.
2. Deploy Traefik to GKE with `.github/workflows/env-dev--deploy-traefik-reverse-proxy.yaml`.
3. Apply Terraform resources that depend on the Traefik Kubernetes Service: PSC attachment, PSC endpoint, PSC NEG and External HTTPS LB.
4. Deploy the application with `.github/workflows/env-dev--deploy-commit-api.yaml`.
5. Validate the full route from the public DNS name.

The combined manual GitHub Actions entrypoint is `.github/workflows/env-dev--deploy-all.yaml`.

## GitHub Actions Secrets

The workflows authenticate to GCP through Workload Identity Federation, without static service account keys. The GitHub environment `commit-dev` must contain:

- `COMMIT_HW_GCP_PROJECT_ID_B`
- `COMMIT_HW_GCP_REGION_DEV`
- `COMMIT_HW_GCP_PROJECT_B_NUMBER`
- `COMMIT_HW_GCP_SERVICE_ACCOUNT_PROJECT_B`

## Validation Commands

```bash
kubectl get ingressroutes -A
kubectl get svc,pods -n commit-api -o wide
kubectl describe ingressroute commit-api -n commit-api
curl -Iv https://api.commit-dev.cloudsmesh.be/
curl -fsS https://api.commit-dev.cloudsmesh.be/
```

Expected API response:

```json
{"status":"ok","service":"commit-api","environment":"commit-dev","transport":"https-all-the-way"}
```

## Notes

- The API pod and Traefik backend route use HTTPS inside the cluster.
- Internal cluster certificates are generated during Helm deployment and are not committed to Git.
- `cert-manager` remains optional for public certificates because the public edge uses Google-managed SSL through the external load balancer.
