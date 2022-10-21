cluster-name ?= "core-cluster"
port ?= 8080

# Utils ////////////////////////////

context:
	@kubectl config use-context $(cluster-name)
	@echo

sync-app-%: context
	argocd app wait crossplane gcp-provider --sync
	argocd app sync $*
	argocd app wait $* --sync
	@echo

delete-app-%:
	argocd app manifests $* | kubectl delete --ignore-not-found=true -f -

### wait for

wait-for-cluster-%: context
	@while ! kubectl wait managed -l "creation=crossplane" --for=condition=READY --timeout=600s; do echo "Waiting for crossplane resources to get ready" && sleep 10; done
	@make wait-for NAME=crossplane.io/gcp-k8s-np-$*				KEY=RUNNING
	@make wait-for NAME=crossplane.io/gcp-k8s-$*					KEY=RUNNING

wait-for-aws-database: context
	@make wait-for NAME=aws-database-postgres-instance	KEY=available

wait-for-gcp-database: context
	@make wait-for NAME=gcp-database-postgres-instance	KEY=RUNNABLE

wait-for:
	@while ! kubectl get managed | grep "$${NAME}" | grep "$${KEY}"; do echo "Waiting for "$${NAME}" to be $${KEY}" && sleep 30; done

wait-for-delete-gcp-database: context
	@make wait-for-delete NAME=gcp-database-postgres-instance

wait-for-delete-aws-database: context
	@make wait-for-delete NAME=aws-database-postgres-instance

wait-for-delete:
	@while kubectl get managed | grep "$${NAME}"; do echo "Waiting for "$${NAME}" to be be deleted" && sleep 30; done

# ArgoCD ////////////////////////////

argocd-cluster-add-%: context
	argocd cluster add $* --name $* -y
	@echo

argo-install: context
	@echo "ArgoCD Install..."
	@kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@echo "Waiting for ArgoCD to get ready..."
	@while ! kubectl wait -A --for=condition=ready pod -l "app.kubernetes.io/name=argocd-server" --timeout=300s; do echo "Waiting for ArgoCD to get ready..." && sleep 10; done
	@sleep 2
	@echo

argo-login: context
	@echo "ArgoCD Login..."
# echo "killing all port-forwarding" && pkill -f "port-forward" || true
# kubectl port-forward svc/argocd-server --pod-running-timeout=100m0s -n argocd $(port):443 &>/dev/null &
	@argocd login --port-forward --insecure --port-forward-namespace argocd --username=admin --password=$$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo)
	@export ARGOCD_OPTS='--port-forward-namespace argocd' 
	@echo

argo-ui-localhost-port-forward: context argo-login-credentials
	kubectl get nodes &>/dev/null
	@echo "killing all port-forwarding" && pkill -f "port-forward" || true
	kubectl port-forward svc/argocd-server --pod-running-timeout=60m0s -n argocd $(port):443 &>/dev/null &
	@open http://localhost:$(port)
	@echo

argo-ui-localhost: context argo-login-credentials
	@open http://argocd.localhost
	@echo

argo-login-credentials: context
	@echo "username: admin, password: $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo)"

## bootstrap

argo-bootstrap-creds:
	@echo "Bootstrapping credentials..."
	@kubectl create namespace crossplane-system	--dry-run=client -o yaml | kubectl apply -f -
	@kubectl create namespace argocd 			--dry-run=client -o yaml | kubectl apply -f -
	@kubectl create secret generic gcp-creds	-n crossplane-system	--from-file creds=../creds/creds-gcp.json 	--dry-run=client -o yaml | kubectl apply -f -
	@kubectl create secret generic aws-creds	-n crossplane-system	--from-file creds=../creds/creds-aws.conf 	--dry-run=client -o yaml | kubectl apply -f -
	@kubectl create secret generic do-creds		-n crossplane-system	--from-file creds=../creds/creds-do.txt   	--dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -f ../creds/repo-creds.yml

argo-bootstrap-core-%: context
	@kubectl apply -f ../../k8s-core-infra/argo-bootstrap/$*

argo-bootstrap-prod:
	@kubectl apply -f ../../cloud-infra-deployment/argo-bootstrap/prod/bootstrap.yml

argo-bootstrap-stage:
	@kubectl apply -f ../../cloud-infra-deployment/argo-bootstrap/stage/bootstrap.yml

argo-bootstrap-kind: context argo-bootstrap-creds argo-bootstrap-core-kind argo-bootstrap-prod argo-bootstrap-stage

argo-bootstrap-gcp: context argo-bootstrap-creds argo-bootstrap-core-gcp argo-bootstrap-prod argo-bootstrap-stage

