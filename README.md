## My GitOps Repository

This repository contains the Kubernetes manifests and configuration for deploying applications using GitOps principles with Argo CD. It follows a modern, modular approach to infrastructure as code.

## Core Concepts

This repository is built on three key patterns: the **ApplicationSet Pattern**, the **One-Chart-Per-App Pattern**, and the **Rendered Manifests Pattern**.

### ApplicationSet Pattern

Instead of manually managing individual Argo CD `Application` resources, we use a single `ApplicationSet` resource (`bootstrap/root-app.yaml`) to generate them. This is a more powerful and declarative version of the "App of Apps" pattern.

1.  The `just bootstrap` command installs or upgrades Argo CD on the cluster.
2.  The `root-app.yaml` `ApplicationSet` and its required permissions are then applied.
3.  This `ApplicationSet` uses a `list` generator to explicitly define all the applications that should exist in the cluster.
4.  For every element in the list, it uses a `template` to generate a standard Argo CD `Application` resource.

This means that to add or remove an application from the cluster, you simply add or remove an entry from the `elements` list in `bootstrap/root-app.yaml`, push the change to Git, and then run `just bootstrap` to apply the updated configuration to the cluster.

### One-Chart-Per-App vs. Monolithic Chart

This repository avoids the **monolithic chart** pattern, where one giant Helm chart contains templates for many different applications. Instead, we use a more modern and scalable **One-Chart-Per-App** approach, which has several key benefits:

*   **Modularity & Decoupling**: Each application (e.g., `todo-app`, `cloudflare-tunnel`) is its own self-contained Helm chart. You can update one application without any risk of affecting another.
*   **Simplicity & Clarity**: Each chart is small, focused, and easy to understand. Its `values.yaml` file only contains configuration relevant to that specific application.
*   **Leveraging the Community**: For common platform tools, we can point an Argo CD `Application` directly to official, community-maintained Helm charts, saving a massive amount of time and effort.

### Rendered Manifests Pattern

Instead of having Argo CD render Helm charts directly in the cluster, we pre-render them into plain Kubernetes YAML files. These final manifests are stored in the `rendered-manifests/` directory and are what Argo CD actually deploys.

This gives us a clear, auditable "source of truth" in Git. We can see the exact YAML that will be applied to the cluster in every pull request, which makes debugging and code reviews much easier.

## Folder Structure

The repository is organized to cleanly separate concerns: application templates (charts), environment-specific configuration (values), and the final rendered manifests that Argo CD will deploy.

    my-gitops-repo/
    ├── bootstrap/
    │   ├── applicationset-rbac.yaml
    │   └── root-app.yaml
    ├── charts/
    │   ├── cloudflare-tunnel/
    │   └── todo-app/
    ├── rendered-manifests/
    │   └── dev/
    │       ├── platform/
    │       │   ├── argocd/
    │       │   │   └── rendered.yaml
    │       │   └── cloudflare-tunnel/
    │       │       └── rendered.yaml
    │       └── user/
    │           └── todo-app/
    │               └── rendered.yaml
    ├── values/
    │   ├── platform/
    │   │   ├── argocd-dev.yaml
    │   │   └── dev.yaml
    │   └── user/
    │       └── todo-app/
    │           └── dev.yaml
    └── justfile

*   `bootstrap/`: Contains the initial, one-time manual setup files. This includes the root `ApplicationSet` and the RBAC permissions it needs to function.
*   `charts/`: Contains our custom-written, reusable Helm charts.
*   `values/`: Contains environment-specific configuration overrides. The name `dev.yaml` refers to the **development environment**.
*   `rendered-manifests/`: Contains the final, complete Kubernetes manifests generated by `helm template`. **This is what Argo CD actually deploys.**
*   `justfile`: The automation entrypoint for rendering manifests and bootstrapping.

### Scaling to Multiple Environments

Even though you may only have one cluster (`dev`), this structure is built to scale. If you were to add `test` and `prod` environments, you would simply add new folders and files.

    my-gitops-repo/
    ├── bootstrap/
    │   └── root-app.yaml         # Add a new entry for the test app here
    ├── ...
    ├── rendered-manifests/
    │   ├── dev/
    │   └── test/                 # New folder for test manifests
    ├── values/
    │   └── user/
    │       └── todo-app/
    │           ├── dev.yaml
    │           └── test.yaml       # New values for the test environment
    └── justfile                    # Updated with a 'render-todo-app-test' command

## Getting Started: Bootstrapping a New Cluster

This is the one-time process to set up a new cluster and connect it to this GitOps repository.

### Prerequisites
*   `kubectl` configured to point to your target cluster.
*   `just` installed (`brew install just` or similar).
*   The Nutanix CSI driver must be manually installed on the cluster for Persistent Volume Claims to work.

### Manual Dependencies (The "Almost" in GitOps)

This repository follows GitOps principles, but with a few exceptions that make it an "Almost GitOps" setup for now. The following components must be managed manually on the cluster:

1.  **Nutanix CSI Driver**: The storage driver that allows Kubernetes to create `PersistentVolume`s is a prerequisite and is not currently managed by this repository.

2.  **Secrets**: All secrets are managed manually and are not stored in Git. Before bootstrapping, you must create the necessary secrets on the cluster.

    *   **Example: Creating the PostgreSQL secret for `todo-app`**:
        ~~~bash
        # Note: The namespace (e.g., todo-app-dev) must exist first.
        # The Argo CD Application manifest can create it with `syncOptions.CreateNamespace=true`.
        kubectl create secret generic todo-app-db-secret \
          --from-literal=postgres-password='YOUR_SECURE_DATABASE_PASSWORD' \
          -n todo-app-dev
        ~~~

    *   **Example: Creating the Cloudflare Tunnel secret**:
        ~~~bash
        # Ensure the cloudflared namespace exists
        kubectl create ns cloudflared
        # Create the secret from your downloaded JSON key file
        kubectl create secret generic cloudflared-tunnel-credentials \
          --from-file=credentials.json=/path/to/your/tunnel-credentials.json \
          -n cloudflared
        ~~~

### Initial Bootstrap Workflow

1.  **Clone the Repository**:
    ~~~bash
    git clone https://github.com/wedgehov/gitops.git
    cd gitops
    ~~~

2.  **Render All Manifests**:
    *   Run the "meta" render command to generate all manifests for the `dev` environment.
    ~~~bash
    just render-all-dev
    ~~~

3.  **Commit and Push**:
    *   Commit all the newly generated files in `rendered-manifests/` to Git.
    ~~~bash
    git add .
    git commit -m "feat: initial render of all applications"
    git push
    ~~~

4.  **Bootstrap the Cluster**:
    *   Run the bootstrap command. This applies the `root` `ApplicationSet`, which then generates and deploys all the applications defined in its `elements` list.
    ~~~bash
    just bootstrap
    ~~~

5.  **Verify**:
    *   Open the Argo CD UI. You should see the `root` application, which will in turn create the `argocd`, `cloudflare-tunnel`, and `todo-app-dev` applications.

### Re-bootstrapping and Upgrading Argo CD

**What happens if I run `just bootstrap` again?**

It is safe to re-run `just bootstrap`. The command uses `kubectl apply`, which is declarative. If the `root` `ApplicationSet` already exists and is unchanged in Git, `kubectl` will do nothing. If you have updated `bootstrap/root-app.yaml`, it will apply those changes to the cluster.

**How do I upgrade Argo CD?**

Because Argo CD is managed by itself as a child application, upgrading it is a simple GitOps process:

1.  In the `justfile`, find the `render-argocd-dev` command and update the `--version` flag to the new version of the Argo CD Helm chart.
2.  Run `just render-all-dev` to generate the new manifests for Argo CD.
3.  Commit and push the updated `rendered-manifests/dev/platform/argocd/rendered.yaml` file.
4.  The `root` app will see that the `argocd` child application is out of sync and will automatically sync it, performing the upgrade.

## Day-to-Day Workflow

### Updating an Existing Application

1.  **Modify**: Make changes to the application's chart in `charts/` or its configuration in the relevant `values/` file.
2.  **Render**: Run `just render-all-dev` (or the specific command, e.g., `just render-todo-app-dev`).
3.  **Commit & Push**: Commit the changes along with the updated `rendered.yaml` file and push to Git.
4.  **Sync**: Argo CD will automatically detect the change and sync your cluster. If you modified `bootstrap/root-app.yaml`, you must also run `just bootstrap` to apply the changes to the `ApplicationSet`.

### Adding a New Application

Let's say you want to add a new `blog-app` for the `dev` environment.

1.  **Create Chart**: Copy `charts/todo-app` to `charts/blog-app` and modify its templates.
2.  **Create Values**: Create `values/user/blog-app/dev.yaml` with its specific configuration (e.g., `ingress.host: blog.dev.vegard.io`).
3.  **Update `justfile`**:
    *   Add a `render-blog-app-dev` command.
    *   Add `render-blog-app-dev` to the `render-all-dev` meta-command.
4.  **Update ApplicationSet**: Add a new entry for `blog-app` to the `elements` list in `bootstrap/root-app.yaml`.
    ~~~yaml
    # ... existing elements ...
    - name: blog-app-dev
      path: rendered-manifests/dev/user/blog-app
      namespace: blog-app-dev
    ~~~
5.  **Render, Commit, Push**: Run `just render-all-dev`, commit all the new and modified files, and push to Git.
6.  **Apply to Cluster**: Run `just bootstrap` to apply the updated apply the updated `ApplicationSet`. Argo CD will then find and deploy your new blog application.

## Adding a New Platform Application (from a public chart)

Let’s say you want to add **Grafana** for monitoring.

---

### 1 · Create the Secret manually  

If the application needs credentials, create the secret first:

```bash
kubectl create ns monitoring

kubectl create secret generic grafana-admin-secret \
  --from-literal=admin-password='YOUR_SECURE_GRAFANA_PASSWORD' \
  -n monitoring
````

---

### 2 · Create a values file

Save this as **`values/platform/grafana-dev.yaml`**:

```yaml
# values/platform/grafana-dev.yaml

# Reference the manually created secret for the admin password
admin:
  existingSecret: grafana-admin-secret
  passwordKey: admin-password

ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - grafana.dev.vegard.io

# … other Grafana values …
```

---

### 3 · Update `justfile`

Add a render command for Grafana and include it in the `render-platform-dev` meta‑command.

---

### 4 · Update the `ApplicationSet`

Append a new element for Grafana in **`bootstrap/root-app.yaml`**:

```yaml
elements:
  - name: grafana
    namespace: monitoring
    chart: grafana/grafana
    valuesFile: values/platform/grafana-dev.yaml
```

---

### 5 · Render → Commit → Push

```bash
just render-all-dev
git add .
git commit -m "Add Grafana platform app"
git push origin main
```

---

### 6 · Apply to the cluster

```bash
just bootstrap
```

---

## Path to True GitOps (TODO)

To evolve this repo into *true* GitOps—where Git is the single source of truth—several manual steps must be automated:

1. **Declarative Secret Management**
   Replace `kubectl create secret` with a Git‑friendly solution:

   * **Sealed Secrets:** Kubernetes controller decrypts secrets that are stored *encrypted* in Git using the cluster’s public key.
   * **External Secrets Operator (ESO):** Manifests reference secrets in AWS Secrets Manager, Azure Key Vault, HashiCorp Vault, etc.; ESO pulls them at runtime.

2. **Declarative CSI Driver Management**
   The Nutanix CSI driver, currently a manual prerequisite, should be treated as a platform app: locate / author a Helm chart, then add it to the `ApplicationSet` so the entire storage layer is defined in Git as well.