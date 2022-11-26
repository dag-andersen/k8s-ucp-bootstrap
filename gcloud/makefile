cluster-name ?= "gke-cluster"
zone ?= "europe-west9-a"
zonee ?= "europe-west9"

start: create-cluster
stop: delete-cluster

# Cluster Creation ------------------------------------

cluster-exists:
	@gcloud container clusters list --zone $(zone) --project summer2021-319316 | grep $(cluster-name) > /dev/null && echo cluster $(cluster-name) exists || (echo cluster $(cluster-name) does not exist && false)

delete-cluster:
	gcloud beta container clusters delete $(cluster-name) --zone $(zone)
	kubectl config delete-context $(cluster-name) || true

create-cluster:
	export USE_GKE_GCLOUD_AUTH_PLUGIN=True
	gcloud components update
	@gcloud beta container clusters create $(cluster-name) \
		--project "summer2021-319316" \
		--zone $(zone) \
		--no-enable-basic-auth \
		--release-channel "regular" \
		--machine-type "e2-highcpu-2" \
		--image-type "COS_CONTAINERD" \
		--disk-type "pd-standard" \
		--disk-size "20" \
		--metadata disable-legacy-endpoints=true \
		--scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" \
		--max-pods-per-node "110" \
		--num-nodes "3" \
		--logging=SYSTEM,WORKLOAD \
		--monitoring=SYSTEM \
		--enable-ip-alias \
		--network "projects/summer2021-319316/global/networks/default" \
		--subnetwork "projects/summer2021-319316/regions/$(zonee)/subnetworks/default" \
		--no-enable-intra-node-visibility \
		--default-max-pods-per-node "110" \
		--no-enable-master-authorized-networks \
		--addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver \
		--max-surge-upgrade 3 \
		--max-unavailable-upgrade 0 \
		--enable-shielded-nodes \
		--node-locations $(zone)
#--enable-autoupgrade 
#--enable-autorepair 
	kubectl config delete-context $(cluster-name) || true
	gcloud container clusters get-credentials $(cluster-name) --zone $(zone) --project summer2021-319316
	kubectl config rename-context $$(kubectl config current-context) $(cluster-name)
	@echo

context:
	kubectl config delete-context $(cluster-name) || true
	gcloud container clusters get-credentials $(cluster-name) --zone $(zone) --project summer2021-319316
	kubectl config rename-context $$(kubectl config current-context) $(cluster-name)
	@echo

# Networking ------------------------------------

dns: dns-stage.dagandersen.com. dns-argo.stage.dagandersen.com.

dns-%:
	@NGINX_INGRESS_IP=$$(kubectl get service app-helm-ingress-ingress-nginx-controller -o json --context=$(cluster-name) -n ingress-nginx | jq -r '.status.loadBalancer.ingress[].ip') \
		&& echo $${NGINX_INGRESS_IP} \
		&& gcloud dns record-sets update $* --rrdatas=$${NGINX_INGRESS_IP} --type=A --ttl=300 --zone=dagandersen-zone \
			|| gcloud dns record-sets create $* --rrdatas=$${NGINX_INGRESS_IP} --type=A --ttl=300 --zone=dagandersen-zone
	@echo

wait-for-dns:
	@while ! host argo.stage.dagandersen.com; do echo "waiting for argo.stage.dagandersen.com" && sleep 30; done
	@while ! argocd login argo.stage.dagandersen.com --insecure --username=admin --password=$$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo); do echo "Trying to login to argocd" && sleep 120; done
	@open https://argo.stage.dagandersen.com

get-ips:
	gcloud compute addresses list

# Argo ------------------------------------

argo-login:
	while ! host argo.core.dagandersen.com; do echo "waiting for argo.core.dagandersen.com" && sleep 30; done
	@PASSWORD=$$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d) && \
	echo password $${PASSWORD} && \
	while ! argocd login argo.core.dagandersen.com --insecure --port-forward-namespace argocd --username=admin --password=$${PASSWORD}; do echo "Trying to login to argocd" && sleep 120; done
	export ARGOCD_OPTS='--port-forward-namespace argocd'
	@open https://argo.core.dagandersen.com
	@echo
