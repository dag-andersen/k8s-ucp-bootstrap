# Colors

echo-header		=xargs -0 gum style --foreground 120 --border-foreground 120 --border double --align center --width 60 --padding "1 1"
echo-info		=xargs -0 gum style --foreground 110 --border-foreground 110 --border double --align center --width 60
echo-question	=xargs -0 gum style --foreground 212 --border-foreground 212 --border double --align center --width 60
echo-answer		=xargs -0 gum style --foreground 050 --border-foreground 050 --border double --align center --width 60
echo-red		=xargs -0 gum style --foreground 001 --border-foreground 001 --border double --align center --width 60
echo-green		=xargs -0 gum style --foreground 120 --border-foreground 120 --border double --align center --width 60 

spin			=gum spin --title

step			= if [[ "$(STEP)" == "true" ]]; then gum confirm "continue?"; fi && 
skip			= if [[ "$(SKIP)" == "true" ]]; then ! gum confirm "skip?" || exit 0; fi &&
pre				= $(step) $(skip)

test-colors: 
	@printf test | $(echo-green)
	@printf test | $(echo-info)
	@printf test | $(echo-red)
	@printf test | $(echo-question)
	@printf test | $(echo-answer)

# Tools

install-tools:
	@brew install kind
	@brew install kubectl
	@brew install helm
	@brew install argocd
	@brew install doctl
	@brew install kustomize
	@brew install argoproj/tap/kubectl-argo-rollouts
	@brew install gum

# Start Clusters

start-core-local:
	@$(MAKE) -C ./kind											start-with-ingress 				cluster-name=core-cluster
	@$(spin) "Argo Install" 	-- $(MAKE) -C ./core-cluster	argo-install					cluster-name=core-cluster
	@$(spin) "Argo CLI login"	-- $(MAKE) -C ./core-cluster	argo-login						cluster-name=core-cluster
	@							   $(MAKE) -C ./core-cluster	argo-ui-localhost-port-forward	cluster-name=core-cluster
	@$(spin) "Bootstrapping"	-- $(MAKE) -C ./core-cluster	argo-bootstrap-kind				cluster-name=core-cluster

start-core-gcp:
	@$(MAKE) -C ./gcloud 										start							cluster-name=core-cluster
	@$(spin) "Argo Install" 	-- $(MAKE) -C ./core-cluster	argo-install					cluster-name=core-cluster
	@$(spin) "Argo CLI login"	-- $(MAKE) -C ./core-cluster	argo-login						cluster-name=core-cluster
	@$(MAKE) -C ./core-cluster									argo-ui-localhost-port-forward	cluster-name=core-cluster
	@$(MAKE) -C ./core-cluster									argo-bootstrap-gcp				cluster-name=core-cluster
	@$(MAKE) -C ./gcloud										argo-login						cluster-name=core-cluster

# Stop Clusters

stop-local:
	@$(MAKE) -C ./kind stop		cluster-name=core-cluster

stop-gcp:
	@$(MAKE) -C ./gcloud stop	cluster-name=core-cluster

# APP

start-app-local:
	@$(MAKE) -C ./kind			start-with-ingress 				cluster-name=app-cluster
	@$(MAKE) -C ./app-cluster	argo-install					cluster-name=app-cluster
	@$(MAKE) -C ./kind			apply-argo-ingress 				cluster-name=app-cluster
	@$(MAKE) -C ./app-cluster	argo-login						cluster-name=app-cluster
	@$(MAKE) -C ./app-cluster	argo-ui-localhost				cluster-name=app-cluster
	@$(MAKE) -C ./app-cluster	argo-app-bootstrap				cluster-name=app-cluster

# Utils

get-prometheus-creds:
	@printf "prometheus - username: admin, password: $$(kubectl get secret --namespace monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo)\n"

### Argo Utils

sync-apps-%:
	@$(MAKE) -C ./core-cluster	sync-apps-$*

sync-apps:
	@printf "Now Syncing: \n$$(echo $${APPS} | tr " " "\n")" | $(echo-info)
	@argocd app sync $${APPS} --async || true
	@printf "Waiting sync" | $(echo-info)
	@while ! argocd app wait $${APPS} --timeout 30 > /dev/null; do echo "Waiting for apps [$${APPS}] to be ready" && make sleep-20 && argocd app sync $${APPS} --async || true; done
	@printf "Synced" | $(echo-info)

delete-app-%:
	@$(MAKE) -C ./core-cluster	delete-app-$*

delete-apps:
	@printf "Now Deleting: \n$$(echo $${APPS} | tr " " "\n")" | $(echo-info)
	@rm temp-apps-to-delete.txt || true
	@echo $(APPS) | xargs -n 1 argocd app manifests $* >> temp-apps-to-delete.txt
	@cat temp-apps-to-delete.txt | kubectl delete --ignore-not-found=true -f -
	@rm temp-apps-to-delete.txt || true
	@printf "Deleted" | $(echo-info)

### Waits

wait-for-cluster-%:
	@$(MAKE) -C ./core-cluster	wait-for-cluster-$*			cluster-name=core-cluster
	
wait-for-database-%:
	@$(MAKE) -C ./core-cluster	wait-for-$*-database		cluster-name=core-cluster	

wait-for-delete-database-%:
	@$(MAKE) -C ./core-cluster	wait-for-delete-$*-database	cluster-name=core-cluster	

### ------

add-gcp-cluster-%:
	@$(MAKE) -C ./gcloud 		context 						cluster-name=gcp-k8s-$*
	@$(MAKE) -C ./core-cluster 	argocd-cluster-add-gcp-k8s-$*

sleep-%:
	@$(spin) "Sleeping $*" sleep $*

onePassword:
	@$(MAKE) -C ./1password		set-argo-creds

# APPS

gcp-apps-argo: 
	@$(MAKE) -C ./gcloud 		context 						cluster-name=gcp-k8s-prod
	@$(MAKE) -C ./app-cluster	argo-install					cluster-name=gcp-k8s-prod
	@$(MAKE) -C ./app-cluster	argo-login						cluster-name=gcp-k8s-prod
	@$(MAKE) -C ./app-cluster	argo-ui-localhost-port-forward	cluster-name=gcp-k8s-prod
	@$(MAKE) -C ./app-cluster	argo-app-bootstrap				cluster-name=gcp-k8s-prod
	@$(MAKE) -C ./gcloud 		wait-for-dns 					cluster-name=gcp-k8s-prod

apps-bootstrap:
	@$(MAKE) -C ./app-cluster	argo-app-boostrap cluster-name=gcp-k8s-prod

# COMMANDS 

start:
	@printf 'Utilizing Kubernetes as an universal control plane!' | $(echo-header)
	@printf 'Where should the core cluster be created?' | $(echo-question)
	@CORE=$$(gum choose "local" "gcp") && \
	printf "Answer: \n$${CORE}" | $(echo-answer) && \
	printf 'What should be installed?' | $(echo-question) && \
	OPTIONS=$$(gum choose "skip" "prod-cluster" "stage-cluster" "quote-app-with-gcp-database" "quote-app-with-aws-database" --no-limit) && \
	printf "Answer: \n$${OPTIONS}" | $(echo-answer) && \
	make start-internal CORE=$${CORE} OPTIONS=" $$(echo $${OPTIONS}) "

start-internal:
	@if [[ "$(CORE)" == "local" ]]; then\
		$(MAKE) -C ./kind 	cluster-exists cluster-name=core-cluster &>/dev/null && gum confirm "Use existing cluster?" || (make start-core-local && make sleep-5 && make onePassword);\
	fi
	@if [[ "$(CORE)" == "gcp" ]]; then\
		$(MAKE) -C ./gcloud	cluster-exists cluster-name=core-cluster &>/dev/null && gum confirm "Use existing cluster?" || (make start-core-gcp && make sleep-5 && make onePassword);\
	fi
	@APPS="application-bootstrap-prod application-bootstrap-stage infrastructure-bootstrap crossplane gcp-provider aws-provider manifest-syncer" && \
	if [[ "$(OPTIONS)" == *"prod-cluster"* ]];			then APPS="$${APPS} gcp-cluster-prod"; fi && \
	if [[ "$(OPTIONS)" == *"stage-cluster"* ]];			then APPS="$${APPS} gcp-cluster-stage"; fi && \
	if [[ "$(OPTIONS)" == *"quote-app-with-gcp-database"* ]];	then APPS="$${APPS} gcp-database"; fi && \
	if [[ "$(OPTIONS)" == *"quote-app-with-aws-database"* ]];	then APPS="$${APPS} aws-database"; fi && \
	make sync-apps APPS="$${APPS}"
	@if [[ "$(OPTIONS)" == *"prod-cluster"* ]]; then\
			make wait-for-cluster-prod add-gcp-cluster-prod && \
		printf "Added prod cluster to argo" | $(echo-info); \
	fi
	@if [[ "$(OPTIONS)" == *"stage-cluster"* ]]; then\
			make wait-for-cluster-stage add-gcp-cluster-stage && \
		printf "Added stage cluster to argo" | $(echo-info); \
	fi
	@make database-example-gcp OPTIONS="$${OPTIONS}"
	@make database-example-aws OPTIONS="$${OPTIONS}"

database-example-%:
	@if [[ "$(OPTIONS)" == *"$*-database-example"* ]]; then\
		$(spin) "Waiting for $* database to be running" -- \
			make wait-for-database-$* && \
		printf "$* database is now running" | $(echo-info); \
		if [[ "$(OPTIONS)" == *"prod-cluster"* ]]; then		make sync-apps APPS=prod-quote-app-with-database-$*;	fi && \
		if [[ "$(OPTIONS)" == *"stage-cluster"* ]]; then	make sync-apps APPS=stage-quote-app-with-database-$*;	fi \
	fi

stop:
	@printf 'STOPPING' | $(echo-header)
	@printf 'Which core cluster should be deleted?' | $(echo-question)
	@CORE=$$(gum choose "skip" "local" "gcp") && \
	printf "Answer: \n$${CORE}" | $(echo-answer) && \
	printf 'What should be stopped before stopping core?' | $(echo-question) && \
	OPTIONS=$$(gum choose "skip" "prod-cluster" "stage-cluster" "quote-app-with-gcp-database" "quote-app-with-aws-database" --no-limit) && \
	printf "Answer: \n$${OPTIONS}" | $(echo-answer) && \
	make stop-internal CORE=$${CORE} OPTIONS=" $$(echo $${OPTIONS}) "

stop-internal:
	@if [[ "$(OPTIONS)" == *"quote-app-with-aws-database"* ]];	then APPS="$${APPS} aws-database prod-quote-app-with-database-aws stage-quote-app-with-database-aws"; fi && \
	if [[ "$(OPTIONS)" == *"quote-app-with-gcp-database"* ]];	then APPS="$${APPS} gcp-database prod-quote-app-with-database-gcp stage-quote-app-with-database-gcp"; fi && \
	if [[ "$(OPTIONS)" == *"prod-cluster"* ]];			then APPS="$${APPS} gcp-cluster-prod"; fi && \
	if [[ "$(OPTIONS)" == *"stage-cluster"* ]];			then APPS="$${APPS} gcp-cluster-stage"; fi && \
	make delete-apps APPS="$${APPS}"
	@if [[ "$(OPTIONS)" == *"quote-app-with-gcp-database"* ]]; then\
		$(spin) "Waiting for gcp database to be deleted" -- \
			make wait-for-delete-database-gcp && \
		printf "gcp Database deleted" | $(echo-info); \
	fi
	@if [[ "$(OPTIONS)" == *"quote-app-with-aws-database"* ]]; then\
		$(spin) "Waiting for aws database to be deleted" -- \
			make wait-for-delete-database-aws && \
		printf "aws Database deleted" | $(echo-info); \
	fi
	@if [[ "$(CORE)" == "local" ]]; then\
		$(spin) "Stopping local" -- \
			make stop-local && \
		printf "local core cluster deleted" | $(echo-info); \
	fi
	@if [[ "$(CORE)" == "gcp" ]]; then\
		make stop-gcp && \
		printf "gcp core cluster deleted" | $(echo-info); \
	fi
