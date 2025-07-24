# Variables for Helm charts from public repositories
ARGOCD_HELM_REPO := "https://argoproj.github.io/argo-helm"
ARGOCD_CHART_VERSION := "5.51.5"

# Meta-command to render all components for the 'dev' environment.
# This command simply calls the other, more specific render commands.
render-all-dev: render-argocd-dev render-platform-dev render-todo-app-dev

# Bootstrap the cluster by applying the root Argo CD application
bootstrap:
	kubectl apply -f bootstrap/root-app.yaml


# Render platform components for the 'dev' environment
render-platform-dev:
	#!/usr/bin/env bash
	mkdir -p rendered-manifests/dev/platform/cloudflare-tunnel
	helm template cloudflare-tunnel ./charts/cloudflare-tunnel -f ./values/platform/dev.yaml > ./rendered-manifests/dev/platform/cloudflare-tunnel/rendered.yaml
	echo "Rendered cloudflare-tunnel for dev."

render-argocd-dev:
	#!/usr/bin/env bash
	mkdir -p rendered-manifests/dev/platform/argocd
	helm repo add argo {{ARGOCD_HELM_REPO}} --force-update
	helm template argocd argo/argo-cd --version {{ARGOCD_CHART_VERSION}} -f ./values/platform/argocd-dev.yaml > ./rendered-manifests/dev/platform/argocd/rendered.yaml
	echo "Rendered argocd for dev."

# Render user applications for the 'dev' environment
render-todo-app-dev:
	#!/usr/bin/env bash
	mkdir -p rendered-manifests/dev/user/todo-app
	helm template todo-app ./charts/todo-app -f ./values/user/todo-app/dev.yaml > ./rendered-manifests/dev/user/todo-app/rendered.yaml
	echo "Rendered todo-app for dev."
