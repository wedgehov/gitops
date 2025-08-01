# Variables for Helm charts from public repositories
ARGOCD_HELM_REPO := "https://argoproj.github.io/argo-helm"
ARGOCD_CHART_VERSION := "5.51.5"
PROMETHEUS_HELM_REPO := "https://prometheus-community.github.io/helm-charts"
PROMETHEUS_CHART_VERSION := "57.0.2" # A recent, stable version
EXTERNAL_SECRETS_HELM_REPO := "https://charts.external-secrets.io"
EXTERNAL_SECRETS_CHART_VERSION := "0.9.9"

# Meta-command to render all components for the 'dev' environment.
# This command simply calls the other, more specific render commands.
render-all-dev: render-argocd-dev render-platform-dev render-kube-prometheus-stack-dev render-external-secrets-dev render-todo-app-dev

# Bootstrap the cluster by applying the root Argo CD application
bootstrap:
	@echo "--> Ensuring argocd namespace exists..."
	# 1. Ensure the argocd namespace exists. This is safe to run multiple times.
	@kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	@echo "--> Applying Prometheus CRDs..."
	# 2. Apply the Prometheus CRDs imperatively. This is necessary before deploying the monitoring stack.
	@just install-prometheus-crds
	@echo "--> Ensuring monitoring namespace exists with correct labels..."
	# 2. Pre-create the monitoring namespace with the correct Pod Security labels to avoid race conditions.
	@kubectl apply -f static-manifests/platform/monitoring-namespace.yaml
	@echo "--> Ensuring external-secrets namespace exists..."
	# 3. Pre-create the external-secrets namespace.
	@kubectl apply -f static-manifests/platform/external-secrets-namespace.yaml
	@echo "--> Applying Argo CD manifests..."
	# 3. Apply the rendered Argo CD manifests to install or upgrade Argo CD.
	#    This is an imperative step to get the system started or to upgrade the controller itself.
	@kubectl apply -n argocd -f rendered-manifests/dev/platform/argocd/rendered.yaml
	@echo "--> Applying Argo CD Controller RBAC..."
	# 4. Grant the Argo CD controller cluster-admin rights to manage applications.
	@kubectl apply -f bootstrap/argocd-controller-clusterrolebinding.yaml
	# 5. Apply all bootstrap resources
	@echo "--> Applying bootstrap ApplicationSet..."
	@kubectl apply -n argocd -f bootstrap/

# Render platform components for the 'dev' environment
render-platform-dev:
	mkdir -p rendered-manifests/dev/platform/cloudflare-tunnel
	helm template cloudflare-tunnel ./charts/cloudflare-tunnel --namespace cloudflared -f ./values/platform/dev.yaml > ./rendered-manifests/dev/platform/cloudflare-tunnel/rendered.yaml
	echo "Rendered cloudflare-tunnel for dev."

# Install Prometheus CRDs imperatively. This is a prerequisite for the monitoring stack.
install-prometheus-crds:
	@echo "--> Applying CRDs to the cluster..."
	# Apply the CRDs from the local 'crds' directory, which are checked into Git.
	# We use --server-side to avoid the "Too long: may not be more than 262144 bytes"
	# error on large CRD annotations. The --field-manager flag identifies this
	# script as the owner of the fields. The --force-conflicts flag is used to
	# take ownership from any previous client-side-apply operations.
	@kubectl apply --server-side --force-conflicts --field-manager=bootstrap-script -f crds/prometheus/crds.yaml

render-kube-prometheus-stack-dev:
	mkdir -p rendered-manifests/dev/platform/kube-prometheus-stack
	helm repo add prometheus-community {{PROMETHEUS_HELM_REPO}} --force-update
	# Render the chart from the public repository using our custom values. CRDs are installed separately.
	helm template kube-prometheus-stack prometheus-community/kube-prometheus-stack --version {{PROMETHEUS_CHART_VERSION}} --namespace monitoring -f ./values/platform/kube-prometheus-stack-dev.yaml > ./rendered-manifests/dev/platform/kube-prometheus-stack/rendered.yaml
	echo "Rendered kube-prometheus-stack for dev."

render-external-secrets-dev:
	mkdir -p rendered-manifests/dev/platform/external-secrets
	helm repo add external-secrets {{EXTERNAL_SECRETS_HELM_REPO}} --force-update
	# Render the chart from the public repository using our custom values.
	helm template external-secrets external-secrets/external-secrets --version {{EXTERNAL_SECRETS_CHART_VERSION}} --namespace external-secrets -f ./values/platform/external-secrets-dev.yaml > ./rendered-manifests/dev/platform/external-secrets/rendered.yaml
	echo "Rendered external-secrets for dev."

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
