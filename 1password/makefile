all: 
	@! gum confirm "Use 1password?"   || \
		(make create-1password-login  && \
		 make update-argo-credentials && \
		 make get-argo-credentials    )

set-argo-creds: update-argo-credentials get-argo-credentials

create-1password-login:
	@! op item get ArgoLogin &>/dev/null || gum confirm "Use existing Argo Credentials?" || (op item delete ArgoLogin && (make create-login-internal))

create-login-internal: 
	@op item create --category=login --title='ArgoLogin' --vault='Personal' \
		--url https://localhost/ \
		--generate-password=20,letters,digits,symbols \
		username=admin \
		&>/dev/null

update-argo-credentials:
	@argocd account update-password \
		--current-password=$$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo) \
		--new-password=$$(op read op://Personal/ArgoLogin/password) \
		&>/dev/null

get-argo-credentials:
	@echo "username: admin, password: $$(op read op://Personal/ArgoLogin/password)"

delete-1password-login:
	@op item delete ArgoLogin