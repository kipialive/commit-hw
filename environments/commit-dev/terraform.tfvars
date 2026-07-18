gcp_project_a_id = "000000000000"
gcp_project_b_id = "111111111111"

### Council Bluffs, Iowa, USA
gcp_region  = "us-central1"
gcp_zone    = "us-central1-a"

env_name              = "commit-dev-tf-main-env"
env_name_short        = "commit-dev"
git_branch_env_name   = "main"

###### ###### ###### ###### ###### ###### 
### VPC "A" CommIT - CIDR blocks/range ###
###### ###### ###### ###### ###### ###### 

vpc_a_subnet_cidr = "10.0.1.0/24"

###### ###### ###### ###### ###### ###### 
### VPC "B" CommIT - CIDR blocks/range ###
###### ###### ###### ###### ###### ###### 

vpc_b_subnet_cidr     = "10.0.2.0/24"
vpc_b_psc_nat_cidr    = "10.0.3.0/24"
vpc_b_proxy_only_cidr = "10.129.0.0/23"

###### ###### ###### ###### ###### ###### 
### GKE - CIDR blocks/range  ###
###### ###### ###### ###### ###### ###### 

gke_pod_cidr_range      = "172.16.0.0/16"
gke_service_cidr_range  = "172.17.0.0/20"