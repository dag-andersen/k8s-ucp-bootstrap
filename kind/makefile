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
