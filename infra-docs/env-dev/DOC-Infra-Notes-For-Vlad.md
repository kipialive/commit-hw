###### ###### ###### ###### ###### ######
### **GCP Cloud** ###
###### ###### ###### ###### ###### ######

## Log Out from GCP Accounts ##
gcloud auth revoke --all
gcloud auth application-default revoke

## The authentication with the gcloud CLI
gcloud auth login

## Generate Terraform Credentials (ADC)
### To have Terraform automatically configure your account
gcloud auth application-default login
# gcloud auth application-default login --no-browser

## Set your default Project ID
gcloud config set project project-0895aaca-3d6c-4e15-b58
gcloud auth application-default set-quota-project project-0895aaca-3d6c-4e15-b58

###### ###### ###### ###### ###### ######
### **Terraform** ###
###### ###### ###### ###### ###### ######

cd ~/HW/commit-hw/environments/commit-dev

terraform init && terraform validate && terraform plan -out tfplan
terraform show -no-color tfplan > tfplan_as_is.txt

terraform apply "tfplan"

###### ###### ######

## Create GCS bucket for TF
gcloud storage buckets create gs://commit-hw-terraform \
    --project="project-0895aaca-3d6c-4e15-b58" \
    --location="us-central1"

## List all buckets in your default active project
gcloud storage buckets list 
gcloud storage buckets list "gs://commit-hw*"
## OR ## 
gcloud storage ls gs://commit-hw*

##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### 
### Create Second GCP Progect
##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### 

# !!! Create MANUALY via UI a new Project="supple-lock-502820-g3" under kipialive-org, and get a ID of it.
gcloud projects list

## Get Billing Account ID
gcloud beta billing accounts list

### The ID must be unique, you can use one similar to the first one, changing one digit
# gcloud projects create project-b-unique-id
gcloud projects create project-0895aaca-3d6c-4e15-s27

### Link it to your billing account (your $300 Free Program), otherwise you won't be able to enable GKE or load balancers within it. You can find your billing account ID with the command
gcloud beta billing projects link supple-lock-502820-g3 --billing-account=01E981-F0DDA6-BC8E54

##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### 
### Activate Compute Engine API on both Projects and GKE API on Project "B" ###
##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### 
gcloud services enable compute.googleapis.com --project=project-0895aaca-3d6c-4e15-b58
gcloud services enable compute.googleapis.com --project=supple-lock-502820-g3
gcloud services enable container.googleapis.com --project=supple-lock-502820-g3



##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### 
### GKE - Get credentials for kubectl
##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### 

gcloud components install gke-gcloud-auth-plugin
gcloud container clusters get-credentials commit-dev-gke-cluster --region us-central1 --project supple-lock-502820-g3

kgn -o wide
kubectl get nodes -o wide


##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### 
### SSH to GKE
##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### 

gcloud compute ssh <node_name> --zone <zone> --project <project_id>

##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### 
### Cloudflare Configuration ###
##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### 

# Domain: cloudsmesh.be

## api.commit-dev.cloudsmesh.be -> 136.69.54.142 ##
Type: A
Name: api.commit-dev 
Target: 136.69.54.142
Proxy status: OFF


## *.dev.cloudsmesh.be -> 172.17.10.17 ##
Type: A
Name: *.dev 
Target: 172.17.10.17
Proxy status: DNS only

##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### 
### Twingate VPN Configuration ###
##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### 

# Create Resource in "CommIT HW Network [Dev]" Network
Label: CommIT HW Domain
Address: *.dev.cloudsmesh.be

##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### 
### To-Do
##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### 


[Done] 1. **Защита сетевого периметра (Firewall Rules):**
В GCP, в отличие от AWS Security Groups, правила файрвола настраиваются прямо на уровне VPC-сетей. Нужно будет заблокировать весь входящий трафик по умолчанию и точечно разрешить взаимодействие между компонентами.

[Done] 2. **Создание инфраструктуры GKE Standard (`main-10-gke.tf`):**
Развертывание самого приватного production-кластера Kubernetes в `Project B`, его привязка к изолированной подсети `commit-dev-subnet-b` и вторичным диапазонам для Pods/Services.


[Done] 3. **Связывание двух периметров (Private Service Connect / PSC):**
Это ключевая часть архитектуры. Нам нужно будет настроить публикацию сервиса (Service Attachment) в `Project B` и подключить его в `Project A`, чтобы трафик из публичного контура безопасно попадал в приватный кластер без использования классического VPC Peering.

[Done] 4. **Настройка Внешнего Балансировщика и Cloud Armor в Project A:**
Создание публичной точки входа (External HTTPS Load Balancer), подключение SSL/TLS сертификатов и настройка политик безопасности Cloud Armor для защиты от DDoS и WAF-угроз на внешнем периметре.

**Что не хватает**

[Done] 1. **DNS-запись**
   Добавить в панели домена `cloudsmesh.be` A-запись:
   `api.commit-dev.cloudsmesh.be -> 136.69.54.142`.
   После propagation Google-managed SSL сможет выпуститься и привязаться к LB.

[Done] 2. **IngressRoute для API**
   Сейчас есть только dashboard route: [ingressroute-traefik-dashboard.yaml](/Users/kipialive/HW/commit-hw/.github/helm-charts/env-dev/traefik-reverse-proxy/traefik/templates/ingressroutes/ingressroute-traefik-dashboard.yaml:17).
   Не вижу `IngressRoute` или `Ingress` для `api.commit-dev.cloudsmesh.be`. Нужно добавить route до реального Service приложения и проверить:
   `kubectl get ingressroutes -A`
   `kubectl describe ingressroute ...`

[Done] 3. **Приложение не задеплоено**
   В репозитории нет manifests/Helm chart для “Some App” из схемы: Deployment, Service, health endpoint, env/secrets, route. Без этого Traefik может быть healthy, но публичный запрос будет получать `503`.

[OK] 4. **CI/CD включен не полностью**
   Workflows есть, WIF используется, но push-trigger выключен через `never-trigger-this-branch`: [.github/workflows/env-dev--deploy-traefik-reverse-proxy.yaml](/Users/kipialive/HW/commit-hw/.github/workflows/env-dev--deploy-traefik-reverse-proxy.yaml:5). Нужно включить `main` или сделать главный orchestrator workflow, который запускает install sealed-secrets -> cert-manager -> Traefik -> app deploy.

[OK-for-HW] 5. **GitHub Actions WIF нужно довести**
   Terraform WIF есть: [main-20-github-actions-wif.tf](/Users/kipialive/HW/commit-hw/environments/commit-dev/main-20-github-actions-wif.tf:13). Но надо проверить GitHub environment secrets:
   `COMMIT_HW_GCP_PROJECT_ID_B`, `COMMIT_HW_GCP_REGION_DEV`, `COMMIT_HW_GCP_PROJECT_B_NUMBER`, `COMMIT_HW_GCP_SERVICE_ACCOUNT_PROJECT_B`.
   Также лучше заменить hardcoded service account email на Terraform variable/output.

[Done] 6. **HTTPS all the way**
   На схеме требуется HTTPS до конца, а backend в External LB сейчас `protocol = "HTTP"`: [main-14-external-lb-armor.tf](/Users/kipialive/HW/commit-hw/environments/commit-dev/main-14-external-lb-armor.tf:112). Нужно решить: либо оставить SSL termination на Google LB и HTTP до Traefik, либо реально настроить HTTPS backend до Traefik `websecure`.

[Done] 7. **Sealed Secrets**
   Workflow установки есть: [.github/workflows/env-dev--installation-sealed-secrets-controller.yaml](/Users/kipialive/HW/commit-hw/.github/workflows/env-dev--installation-sealed-secrets-controller.yaml:88). Но нужно подтвердить, что controller установлен в GKE, публичный cert актуален, и все пароли/API keys лежат как SealedSecret, а не обычные Secret.

[Done] 8. **Cert-manager опционально**
   Workflow и chart есть, но он настроен на Route53 DNS-01: [.github/helm-charts/env-dev/cert-manager/values.yaml](/Users/kipialive/HW/commit-hw/.github/helm-charts/env-dev/cert-manager/values.yaml:12). Если DNS реально не в AWS Route53, этот путь не сработает. Для текущего `api.commit-dev.cloudsmesh.be` проще Google-managed SSL через LB; cert-manager оставить как optional и описать.

[Done] 9. **Убрать AWS-следы из GCP проекта**
   В Traefik chart есть AWS `StorageClass` с `ebs.csi.aws.com`: [store_tls_certificates.yaml](/Users/kipialive/HW/commit-hw/.github/helm-charts/env-dev/traefik-reverse-proxy/traefik/templates/storage/store_tls_certificates.yaml:10). Для GKE это надо удалить или заменить на GCE PD provisioner/storage class.

[Done] 10. **Разделить порядок Terraform/Helm**
   `main-11-psc-attachment.tf` читает Kubernetes Service Traefik: [main-11-psc-attachment.tf](/Users/kipialive/HW/commit-hw/environments/commit-dev/main-11-psc-attachment.tf:19). Значит Terraform apply зависит от предварительно установленного Traefik. Нужно явно описать staged deployment в README.

[Done] 11. **Документация**
   README почти пустой. Нужно добавить архитектуру, prerequisites, порядок запуска, CI/CD secrets, DNS, smoke tests, troubleshooting `503`/SSL.

[Done] 12. **Финальная валидация**
   Я прогнал локально:
   `helm lint` для cert-manager проходит.
   `helm lint` для Traefik проходит с предупреждением, что dependency `traefik` не скачана.
   `helm template` Traefik сейчас падает без `helm dependency build`.
   `terraform fmt -check` показывает неотформатированные файлы.
   `terraform validate` не удалось из-за локальной проблемы provider plugins в `.terraform`, надо прогнать после чистого `terraform init -upgrade`.


##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### 
### Delete environments ###
##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### 

~ ❯ gcloud projects delete project-0895aaca-3d6c-4e15-b58 
Your project will be deleted: [project-0895aaca-3d6c-4e15-b58]

Do you want to continue (Y/n)?  Y

Deleted [https://cloudresourcemanager.googleapis.com/v1/projects/project-0895aaca-3d6c-4e15-b58].

You can undo this operation for a limited period by running the command below.
    $ gcloud projects undelete project-0895aaca-3d6c-4e15-b58

See https://cloud.google.com/resource-manager/docs/creating-managing-projects for information on shutting down projects.


~ ❯ gcloud projects delete supple-lock-502820-g3
Your project will be deleted: [supple-lock-502820-g3]

Do you want to continue (Y/n)?  Y

Deleted [https://cloudresourcemanager.googleapis.com/v1/projects/supple-lock-502820-g3].

You can undo this operation for a limited period by running the command below.
    $ gcloud projects undelete supple-lock-502820-g3

See https://cloud.google.com/resource-manager/docs/creating-managing-projects for information on shutting down projects.