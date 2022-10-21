cluster-name ?= "gcp-k8s-prod"
env ?= "prod"
port ?= "8081"

# Utils ////////////////////////////

context:
	@kubectl config use-context $(cluster-name)

# ArgoCD ////////////////////////////

argo-install: context
	@echo "ArgoCD Install..."
	@kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@echo "Waiting for ArgoCD to get ready..." \
		&& kubectl wait -A --for=condition=ready pod -l "app.kubernetes.io/name=argocd-server" --timeout=300s || sleep 10 \
		|| kubectl wait -A --for=condition=ready pod -l "app.kubernetes.io/name=argocd-server" --timeout=300s || sleep 10 \
		|| kubectl wait -A --for=condition=ready pod -l "app.kubernetes.io/name=argocd-server" --timeout=300s
	kubectl port-forward svc/argocd-server --pod-running-timeout=10m0s -n argocd $(port):443 &>/dev/null &
	@sleep 2
	@echo

argo-login: context
	@echo "ArgoCD Login..."
	kubectl port-forward svc/argocd-server --pod-running-timeout=10m0s -n argocd $(port):443 &>/dev/null &
	@argocd login localhost:$(port) --insecure --username=admin --password=$$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo)
	@argocd repo add https://github.com/dag-andersen/cloud-infra-deployment --username dag-andersen --password $$(cat ../creds/creds-github.txt)
	@export ARGOCD_OPTS='--port-forward-namespace argocd'
	@echo

argo-ui-localhost-port-forward: context
	kubectl port-forward svc/argocd-server --pod-running-timeout=10m0s -n argocd --context $(cluster-name) $(port):443 &>/dev/null &
	@echo
	@echo "username: admin, password: $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo)"
	@open -a Safari https://localhost:$(port)
	@echo

argo-ui-localhost: context
	@echo "username: admin, password: $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo)"
	@open http://argocd.localhost
	@echo

argo-login-credentials: context
	@echo "username: admin, password: $$(kubectl -n argocd --context $(cluster-name) get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo)"

argo-app-bootstrap: context
	kubectl apply --context $(cluster-name) -f /Users/dag/CodeProjects/cloud-infra-deployment/kube-app-bootstrap/$(env)/kube-applications.yml
	@echo

argo-override: context
	@kustomize build /Users/dag/CodeProjects/cloud-infra-deployment/kube-applications/overlays/prod | kubectl apply --context $(cluster-name) -f -

prometheus:
	kubectl create namespace monitoring
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update 
	helm upgrade --namespace monitoring --install kube-stack-prometheus prometheus-community/kube-prometheus-stack --set prometheus-node-exporter.hostRootFsMount.enabled=false
