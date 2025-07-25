# Variables for Helm charts from public repositories
ARGOCD_HELM_REPO := "https://argoproj.github.io/argo-helm"
ARGOCD_CHART_VERSION := "5.51.5"
GRAFANA_HELM_REPO := "https://grafana.github.io/helm-charts"
GRAFANA_CHART_VERSION := "7.3.11" # A recent, stable version
PROMETHEUS_HELM_REPO := "https://prometheus-community.github.io/helm-charts"
PROMETHEUS_CHART_VERSION := "57.0.1" # A recent, stable version

# Meta-command to render all components for the 'dev' environment.
# This command simply calls the other, more specific render commands.
render-all-dev: render-argocd-dev render-platform-dev render-grafana-dev render-prometheus-dev render-todo-app-dev

# Bootstrap the cluster by applying the root Argo CD application
bootstrap:
	@echo "--> Ensuring argocd namespace exists..."
	# 1. Ensure the argocd namespace exists. This is safe to run multiple times.
	@kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	@echo "--> Applying Argo CD manifests..."
	# 2. Apply the rendered Argo CD manifests to install or upgrade Argo CD itself.
	#    This is the one-time imperative step to get the system started.
	@kubectl apply -n argocd -f rendered-manifests/dev/platform/argocd/rendered.yaml
	# 3. Apply all bootstrap resources, including the ApplicationSet and its RBAC permissions.
	@echo "--> Applying bootstrap ApplicationSet and RBAC..."
	@kubectl apply -n argocd -f bootstrap/


# Render platform components for the 'dev' environment
render-platform-dev:
	mkdir -p rendered-manifests/dev/platform/cloudflare-tunnel
	helm template cloudflare-tunnel ./charts/cloudflare-tunnel --namespace cloudflared -f ./values/platform/dev.yaml > ./rendered-manifests/dev/platform/cloudflare-tunnel/rendered.yaml
	echo "Rendered cloudflare-tunnel for dev."

render-grafana-dev:
	mkdir -p rendered-manifests/dev/platform/grafana
	helm repo add grafana {{GRAFANA_HELM_REPO}} --force-update
	helm template grafana grafana/grafana --version {{GRAFANA_CHART_VERSION}} --namespace monitoring -f ./values/platform/grafana-dev.yaml > ./rendered-manifests/dev/platform/grafana/rendered.yaml
	echo "Rendered grafana for dev."

render-prometheus-dev:
	mkdir -p rendered-manifests/dev/platform/prometheus-stack
	helm repo add prometheus-community {{PROMETHEUS_HELM_REPO}} --force-update
	helm template prometheus-stack prometheus-community/kube-prometheus-stack --version {{PROMETHEUS_CHART_VERSION}} --namespace monitoring -f ./values/platform/prometheus-dev.yaml > ./rendered-manifests/dev/platform/prometheus-stack/rendered.yaml
	echo "Rendered prometheus-stack for dev."

render-argocd-dev:
	mkdir -p rendered-manifests/dev/platform/argocd
	helm repo add argo {{ARGOCD_HELM_REPO}} --force-update
	helm template argocd argo/argo-cd --version {{ARGOCD_CHART_VERSION}} --namespace argocd -f ./values/platform/argocd-dev.yaml > ./rendered-manifests/dev/platform/argocd/rendered.yaml
	echo "Rendered argocd for dev."

# Render user applications for the 'dev' environment
render-todo-app-dev:
	mkdir -p rendered-manifests/dev/user/todo-app
	helm template todo-app ./charts/todo-app --namespace todo-app-dev -f ./values/user/todo-app/dev.yaml > ./rendered-manifests/dev/user/todo-app/rendered.yaml
	echo "Rendered todo-app for dev."
