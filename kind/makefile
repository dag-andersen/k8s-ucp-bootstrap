cluster-name ?= "kind-cluster"

start: delete create
start-with-ingress: delete create-with-ingress
stop: delete

# Kind -------

cluster-exists:
	@kind get clusters | grep $(cluster-name) > /dev/null && echo cluster $(cluster-name) already exists || (echo cluster $(cluster-name) does not exist && false)

create: 
	@echo "Setting up cluster..."
	@kind create cluster --name $(cluster-name) --wait 5m
	@kubectl config delete-context $(cluster-name) || true
	@kubectl config rename-context $$(kubectl config current-context) $(cluster-name)

create-with-ingress:
	@echo "Setting up cluster with ingress..."
	@kind create cluster --name $(cluster-name) --wait 5m --config ./kind-cluster.yml
	@kubectl config delete-context $(cluster-name) || true
	@kubectl config rename-context $$(kubectl config current-context) $(cluster-name)
	@gum spin -- kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
	@gum spin --title "Sleeping" -- sleep 5
	@gum spin --title "waiting for ingress" -- kubectl wait -n ingress-nginx \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/component=controller \
		--timeout=150s
	@gum spin -- kubectl apply -f test-setup.yml
	@gum spin sleep 10
	@echo "Testing if ingress is working..."
	curl localhost/test
	@echo

delete:
	@kind delete cluster --name $(cluster-name)
	@kubectl config delete-context $(cluster-name) && gum spin sleep 3 || true

apply-argo-ingress:
	kubectl apply -f argo-ingress.yml --context $(cluster-name)

# ---------------------------------------------------------------------------
# IGNORE EVERYTHING UNDER THIS LINE - IT IS JUST KEEPT FOR REFERENCE --------
# ---------------------------------------------------------------------------

env ?= "stage"

# kube-apply-tracker --------
upload-kube-apply-tracker:
	kubectl apply -f role.yml 
	docker build -t kube-apply-tracker:argotest ../kube-apply-tracker
	kind load docker-image kube-apply-tracker:argotest --name testkind  
	docker exec -it testkind-control-plane crictl images

manual-apply-kube-apply-tracker:
	kustomize build ../kube-apply-tracker/k8s/overlays/stage | kubectl apply -f -

manual-argo-create-kube-apply-tracker:
	argocd app create apply-tracker --sync-policy --repo https://github.com/dag-andersen/cloud-infra-deployment --path ../kube-apply-tracker/k8s/overlays/stage --dest-server https://kubernetes.default.svc --dest-namespace default


# Linkerd --------
linkerd:
	linkerd check --pre
	linkerd install | kubectl apply -f -
	linkerd check
	linkerd viz install | kubectl apply -f -

linkerd-inject:
	kubectl get deploy -o yaml | linkerd inject - | kubectl apply -f -

linkerd-ui:
	linkerd viz dashboard &>/dev/null &

buoyant:
	install curl -sL buoyant.cloud/install | sh
	linkerd buoyant install | kubectl apply -f -
	linkerd check --wait 5m


# Kube-Monkey ------------
kube-monkey:
	@helm repo add kubemonkey https://asobti.github.io/kube-monkey/charts/repo
	@helm repo update
	helm delete kube-monkey || true
	helm install kube-monkey kubemonkey/kube-monkey --version 1.4.0 \
		--set config.dryRun=false \
		--set config.whitelistedNamespaces="{default}" \
		--set config.debug.enabled=true \
		--set config.debug.schedule_immediate_kill=true
	sleep 5
	kubectl rollout status deployment kube-monkey

kube-monkey-logs:
	@kubectl logs -f deployment.apps/kube-monkey

# Litmus --------
litmus:
	helm repo add litmuschaos https://litmuschaos.github.io/litmus-helm/
	kubectl create ns litmus
	helm install chaos litmuschaos/litmus --namespace=litmus
	sleep 5
	kubectl get pods -n litmus | grep '1/1'
	kubectl get crds | grep chaos

# Argo --------
argo-bootstrap:
	kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	sleep 10
	kubectl wait -A --for=condition=ready pod -l "app.kubernetes.io/name=argocd-server" --timeout=120s
	kubectl port-forward svc/argocd-server -n argocd 8080:443 &>/dev/null &
	sleep 2

argo-login:
	argocd login localhost:8080 --insecure --username=admin --password=$$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo)
	argocd repo add https://github.com/dag-andersen/cloud-infra-deployment --username dag-andersen --password $$(cat ../creds/creds-github.txt)
	export ARGOCD_OPTS='--port-forward-namespace argocd'

argo-ui:
	@kubectl wait -A --for=condition=ready pod -l "app.kubernetes.io/name=argocd-server"
	@kubectl port-forward svc/argocd-server -n argocd 8080:443 &>/dev/null &
	@echo
	@echo "username: admin, password: $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo)"
	@open https://localhost:8080

argo-initial-app:
	kubectl apply -f ../../cloud-infra-deployment/kube-app-bootstrap/$(env)/kube-applications.yml

argo-workflow-setup:
	kubectl create ns argo
	kubectl apply -n argo -f https://raw.githubusercontent.com/argoproj/argo-workflows/stable/manifests/quick-start-postgres.yaml
	kubectl create clusterrolebinding dagandersen-cluster-admin-binding --clusterrole=cluster-admin --user=dagbjerreandersen@gmail.com
	kubectl -n argo port-forward deployment/argo-server 2746:2746 &

argo-rollout-setup:
	kubectl create namespace argo-rollouts
	kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

install-hello-server:
	kustomize build ../hello-example | kubectl apply --wait -f -
