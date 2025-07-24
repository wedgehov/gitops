# My GitOps Repository

This repository contains the Kubernetes manifests and configuration for deploying applications using GitOps principles with Argo CD. It follows a modern, modular approach to infrastructure as code.

## Core Concepts

This repository is built on three key patterns: the **ApplicationSet Pattern**, the **One-Chart-Per-App Pattern**, and the **Rendered Manifests Pattern**.

### ApplicationSet Pattern

Instead of manually managing individual Argo CD `Application` resources, we use a single `ApplicationSet` resource (`bootstrap/root-app.yaml`) to generate them. This is a more powerful and declarative version of the "App of Apps" pattern.

1.  The `just bootstrap` command installs Argo CD on the cluster.
2.  The `root-app.yaml` `ApplicationSet` is then manually applied **once**.
3.  This `ApplicationSet` uses a `list` generator to explicitly define all the applications that should exist in the cluster.
4.  For every element in the list, it uses a `template` to generate a standard Argo CD `Application` resource.

This means that to add or remove an application from the cluster, you simply add or remove an entry from the `elements` list in `bootstrap/root-app.yaml` and push to Git. Argo CD handles the rest.

### One-Chart-Per-App vs. Monolithic Chart

This repository avoids the **monolithic chart** pattern, where one giant Helm chart contains templates for many different applications, all controlled by a single, massive `values.yaml` file.

Instead, we use a more modern and scalable **One-Chart-Per-App** approach. This has several key benefits:

*   **Modularity & Decoupling**: Each application (e.g., `todo-app`, `cloudflare-tunnel`) is its own self-contained Helm chart. You can update one application without any risk of affecting another. This is the "microservices" approach to infrastructure.
*   **Simplicity & Clarity**: Each chart is small, focused, and easy to understand. Its `values.yaml` file only contains configuration relevant to that specific application.
*   **Leveraging the Community**: For common platform tools like Grafana, Prometheus, or Loki, we don't need to write and maintain our own complex charts. We can point an Argo CD `Application` directly to the official, community-maintained Helm charts, saving a massive amount of time and effort.

This modular, one-chart-per-app approach is widely used in the cloud-native community because it favors decoupling and clarity. While it’s not the only valid pattern, it works well for teams with independently deployed services and aligns nicely with GitOps workflows.

### Shared Tunnel and Ingress Controller

This repository uses a single, shared Cloudflare Tunnel that forwards all traffic to a central NGINX Ingress Controller. The Ingress Controller then uses standard Kubernetes `Ingress` resources to route traffic to the correct application based on the requested hostname.

This "catch-all" tunnel pattern is a standard, scalable architecture with several key advantages over defining routing rules directly in the tunnel configuration:

*   **GitOps Ergonomics**: To add or modify an application's routing, you only change its `Ingress` manifest in Git. The core platform networking (the tunnel) remains untouched, simplifying day-to-day operations.
*   **Separation of Concerns**: The Cloudflare Tunnel has one job: provide secure transport into the cluster. The Ingress Controller handles the complex L7 routing, a task it is specifically designed for.
*   **Scalability and Observability**: You can scale the Ingress Controller like any other Kubernetes `Deployment`. All access logs, metrics, and policies are centralized at the Ingress layer, making monitoring and troubleshooting much easier.

This approach delegates routing to Kubernetes-native primitives, which is the cleaner and more maintainable long-term choice.

### Rendered Manifests Pattern

Instead of having Argo CD render Helm charts directly in the cluster, we pre-render them into plain Kubernetes YAML files. These final manifests are stored in the `rendered-manifests/` directory and are what Argo CD actually deploys.

This gives us a clear, auditable "source of truth" in Git. We can see the exact YAML that will be applied to the cluster in every pull request, which makes debugging and code reviews much easier.

### Architectural Decisions and References

The patterns chosen for this repository are based on common industry practices. The one-chart-per-app model, for example, is a strong default choice that is widely used and recommended by many practitioners for its isolation and clarity benefits [1]–[4].

#### References

[1] B. Kušen, “Helm: Best Practices,” *Opstergo Blog*, Jan. 13, 2024. [Online]. Available: https://www.opstergo.com/blog/helm-best-practices

[2] “Helm to Configure and Deploy Gen3,” *Gen3 Documentation*, Center for Translational Data Science, Univ. of Chicago. [Online]. Available: https://docs.gen3.org/gen3-resources/operator-guide/helm/

[3] D. Maze, “Answer to: ‘Should dependencies between Helm charts reflect dependencies between microservices?’” *Stack Overflow*, Mar. 10, 2019. [Online]. Available: https://stackoverflow.com/questions/55078150/should-dependencies-between-helm-charts-reflect-dependencies-between-microservic

[4] T. Royer, “3 patterns for deploying Helm charts with Argo CD,” *Red Hat Developer*, May 25, 2023. [Online]. Available: https://developers.redhat.com/articles/2023/05/25/3-patterns-deploying-helm-charts-argocd

## Folder Structure

The repository is organized to cleanly separate concerns: application templates (charts), environment-specific configuration (values), and the final rendered manifests that Argo CD will deploy.

```text
my-gitops-repo/
├── bootstrap/
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
```

*   `apps/`: Contains the Argo CD `Application` manifests that act as "pointers" to our applications. This is what the `root` app syncs.
*   `bootstrap/`: Contains the single `root-app.yaml` used for the initial, one-time manual setup.
*   `charts/`: Contains our custom-written, reusable Helm charts.
*   `values/`: Contains environment-specific configuration overrides. The name `dev.yaml` refers to the **development environment**.
*   `rendered-manifests/`: Contains the final, complete Kubernetes manifests generated by `helm template`. **This is what Argo CD actually deploys.** Committing these files to Git provides a clear, auditable record of exactly what is running in the cluster.
*   `justfile`: The automation entrypoint for rendering manifests and bootstrapping.

### Scaling to Multiple Environments

Even though you may only have one cluster (`dev`), this structure is built to scale. If you were to add `test` and `prod` environments, you would simply add new folders and files. The structure would look like this:

```
my-gitops-repo/
├── apps/
│   └── user/
│       ├── todo-app-dev.yaml
│       └── todo-app-test.yaml  # New app for the test environment
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
```

## Getting Started: Bootstrapping a New Cluster

This is the one-time process to set up a new cluster and connect it to this GitOps repository.

### Prerequisites
*   `kubectl` configured to point to your target cluster.
*   `just` installed (`brew install just` or similar).
*   A minimal Argo CD installed on the cluster.
*   The Nutanix CSI driver must be manually installed on the cluster for Persistent Volume Claims to work.

### Manual Dependencies (The "Almost" in GitOps)

This repository follows GitOps principles, but with a few exceptions that make it an "Almost GitOps" setup for now. The following components must be managed manually on the cluster:

1.  **Nutanix CSI Driver**: The storage driver that allows Kubernetes to create `PersistentVolume`s is a prerequisite and is not currently managed by this repository.

2.  **Secrets**: All secrets are managed manually and are not stored in Git. Before bootstrapping, you must create the necessary secrets on the cluster.

    *   **Example: Creating the PostgreSQL secret for `todo-app`**:
        ```bash
        # Note: The namespace (e.g., todo-app-dev) must exist first.
        # The Argo CD Application manifest can create it with `syncOptions.CreateNamespace=true`.
        kubectl create secret generic todo-app-db-secret \
          --from-literal=postgres-password='YOUR_SECURE_DATABASE_PASSWORD' \
          -n todo-app-dev
        ```

    *   **Example: Creating the Cloudflare Tunnel secret**:
        ```bash
        # Ensure the cloudflared namespace exists
        kubectl create ns cloudflared
        # Create the secret from your downloaded JSON key file
        kubectl create secret generic cloudflared-tunnel-credentials \
          --from-file=credentials.json=/path/to/your/tunnel-credentials.json \
          -n cloudflared
        ```

### Initial Bootstrap Workflow

1.  **Clone the Repository**:
    ```bash
    git clone https://github.com/wedgehov/gitops.git
    cd my-gitops-repo
    ```

2.  **Configure Repository URL**:
    *   This step is no longer needed as the repository URL is now correctly set in the template files.

3.  **Render All Manifests**:
    *   Run the "meta" render command to generate all manifests for the `dev` environment.
    ```bash
    just render-all-dev
    ```

4.  **Commit and Push**:
    *   Commit all the newly generated files in `rendered-manifests/` to Git.
    ```bash
    git add .
    git commit -m "feat: initial render of all applications"
    git push
    ```

5.  **Bootstrap the Cluster**:
    *   Run the bootstrap command. This applies the `root` application, which will then find and deploy all the other applications from the `apps/` directory.
    ```bash
    just bootstrap
    ```

6.  **Verify**:
    *   Open the Argo CD UI. You should see the `root` application, which will in turn create the `argocd`, `cloudflare-tunnel`, and `todo-app-dev` applications.

### Re-bootstrapping and Upgrading Argo CD

**What happens if I run `just bootstrap` again?**

It is safe to re-run `just bootstrap`. The command uses `kubectl apply`, which is declarative. If the `root` application already exists and is unchanged in Git, `kubectl` will do nothing. If you have updated `bootstrap/root-app.yaml`, it will apply those changes.

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
4.  **Sync**: Argo CD will automatically detect the change and sync your cluster.

### Adding a New User Application

Let's say you want to add a new `blog-app`.

1.  **Create Chart**: Copy `charts/todo-app` to `charts/blog-app` and modify its templates.
2.  **Create Values**: Create `values/user/blog-app/dev.yaml` with its specific configuration (e.g., `ingress.host: blog.dev.vegard.io`).
3.  **Update `justfile`**:
    *   Add a `render-blog-app-dev` command.
    *   Add `render-blog-app-dev` to the `render-all-dev` meta-command.
4.  **Create Argo App Manifest**: Create `apps/user/blog-app.yaml`. This will point to the new rendered manifest path (`rendered-manifests/dev/user/blog-app`).
5.  **Render, Commit, Push**: Run `just render-all-dev`, commit all the new files, and push. The `root` app will automatically find and deploy your new blog application.

### Adding a New Platform Application (from a public chart)

Let's say you want to add Grafana for monitoring. This requires an admin password, which must not be stored in Git.

1.  **Create the Secret Manually**: First, create a Kubernetes secret on the cluster to hold the password.
    ```bash
    kubectl create secret generic grafana-admin-secret \
      --from-literal=admin-password='YOUR_SECURE_GRAFANA_PASSWORD' \
      -n monitoring
    ```

2.  **Create Argo App Manifest**: Create a new file at `apps/platform/grafana.yaml`.

3.  **Configure the Application**: Inside this file, point to the public Grafana Helm chart and use `admin.existingSecret` to reference the secret you just created.
    ```yaml
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: grafana
    spec:
      source:
        repoURL: https://grafana.github.io/helm-charts
        chart: grafana
        targetRevision: 6.58.5 # Pin to a specific version
        helm:
          values: |
            # Reference the manually created secret for the admin password
            admin:
              existingSecret: "grafana-admin-secret"
              passwordKey: "admin-password"
            ingress:
              enabled: true
              ingressClassName: nginx
              hosts:
                - grafana.dev.vegard.io
      destination:
        server: https://kubernetes.default.svc
        namespace: monitoring # Deploy it to a dedicated namespace
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
    ```
4.  **Commit & Push**: Commit the new `apps/platform/grafana.yaml` file and push. The `root` app will find and deploy Grafana for you.

## Path to True GitOps (TODO)

To evolve this repository into a true GitOps setup where Git is the single source of truth for *everything*, the following manual steps need to be automated:

1.  **Declarative Secret Management**: Instead of `kubectl create secret`, we should adopt a GitOps-friendly secret management tool. This encrypts secrets so they can be safely stored in a public Git repository.
    *   **Option A: Sealed Secrets:** A Kubernetes controller that decrypts secrets that can only be used by the intended cluster. The public key is stored in the repo, and developers use a CLI to encrypt secrets before committing them.
    *   **Option B: External Secrets Operator (ESO):** A controller that fetches secrets from an external store like Azure Key Vault, AWS Secrets Manager, or HashiCorp Vault. The Kubernetes manifests would contain references to the secrets, not the secrets themselves.

2.  **Declarative CSI Driver Management**: The Nutanix CSI driver, which is currently a manual prerequisite, should be managed as a platform application within this repository. This would involve finding or creating a Helm chart for the driver and adding it to the `apps/platform/` directory, ensuring the entire storage layer is also defined in Git.