# kube-manager-zsh

A lightweight Zsh plugin for managing multiple Kubernetes kubeconfigs, validating cluster connections, switching contexts safely, and opening K9s with the selected context.

The plugin is designed for developers and infrastructure engineers who work with multiple Kubernetes and OpenShift clusters and want to keep their kubeconfigs organized without manually maintaining a large `~/.kube/config` file.

## Features

- Manage multiple kubeconfig files from a dedicated directory
- Generate the main `~/.kube/config` automatically
- Detect new, updated, and duplicate kubeconfigs
- Identify kubeconfigs using cluster/context information instead of relying only on file hashes
- Validate Kubernetes cluster connectivity
- Detect common connection problems:
  - authentication failures
  - expired or invalid credentials
  - unreachable API servers
  - TLS/certificate errors
- List and switch Kubernetes contexts
- Open K9s using an explicitly selected context
- Extra confirmation before opening production contexts
- Open production clusters in K9s read-only mode by default
- Create backups before replacing the main kubeconfig
- Restore previous kubeconfig backups
- Scan kubeconfigs downloaded to `~/Downloads`
- Interactive context selection using `fzf` when available
- Command-line and interactive menu modes
- Built-in help system

## Directory Structure

The plugin keeps its own files clearly separated from Kubernetes' default configuration.

```text
~/.kube/
├── config
├── configs-plugin-km/
├── backups-plugin-km/
└── state-plugin-km/
```

### `~/.kube/config`

Generated kubeconfig used by Kubernetes tools such as:

```text
kubectl
helm
k9s
```

The plugin treats this file as generated output.

### `configs-plugin-km`

Source kubeconfig files managed by the plugin.

Example:

```text
~/.kube/configs-plugin-km/
├── rke2-dev.yaml
├── rke2-prod.yaml
├── ocp-dev.yaml
├── ocp-hml.yaml
└── ocp-prod.yaml
```

### `backups-plugin-km`

Automatic backups created before replacing `~/.kube/config` or updating managed kubeconfigs.

### `state-plugin-km`

Internal plugin state used to track imported kubeconfigs and hashes.

## Requirements

Required:

- Zsh
- Oh My Zsh
- kubectl

Recommended:

- k9s
- jq
- fzf

Optional:

- OpenShift CLI (`oc`)

On macOS with Homebrew:

```bash
brew install kubectl k9s jq fzf
```

If you use OpenShift, install the `oc` CLI separately according to your OpenShift environment.

## Installation

Clone the repository:

```bash
git clone git@github.com:YOUR_USERNAME/kube-manager-zsh.git
```

Create the Oh My Zsh plugin directory:

```bash
mkdir -p ~/.oh-my-zsh/custom/plugins/kube-manager
```

Create a symbolic link to the plugin:

```bash
ln -s \
  ~/dev/pessoal/kube-manager-zsh/kube-manager.plugin.zsh \
  ~/.oh-my-zsh/custom/plugins/kube-manager/kube-manager.plugin.zsh
```

Using a symbolic link is recommended during development because changes made in the Git repository are immediately available to Oh My Zsh.

Add the plugin to your `~/.zshrc`:

```text
plugins=(
  git
  kube-manager
)
```

Reload Zsh:

```bash
source ~/.zshrc
```

Verify:

```bash
type kube-manager
type km
```

## Usage

The full command is:

```bash
kube-manager
```

A short alias is also available:

```bash
km
```

Running it without arguments opens the interactive menu:

```bash
km
```

## Commands

### Help

```bash
km help
```

Command-specific help:

```bash
km help sync
km help import
km help k9s
km help downloads
```

### List Managed Kubeconfigs

```bash
km sources
```

Alias:

```bash
km scan
```

### Scan Downloads

Check `~/Downloads` for kubeconfig files:

```bash
km downloads
```

Import or update detected kubeconfigs:

```bash
km downloads import
```

### Import a Kubeconfig

```bash
km import ~/Downloads/kubeconfig.yaml
```

The plugin determines whether the kubeconfig represents:

- a new cluster/context
- an already imported file
- an updated credential for an existing cluster
- another context pointing to the same Kubernetes API server

### Synchronize Kubeconfigs

Rebuild the main Kubernetes configuration from all managed kubeconfigs:

```bash
km sync
```

The synchronization process:

1. Scans source kubeconfigs
2. Validates their structure
3. Checks for naming collisions
4. Creates a backup of the current `~/.kube/config`
5. Merges the source kubeconfigs
6. Flattens the resulting configuration
7. Validates the generated kubeconfig
8. Restores the previous current context when possible
9. Replaces `~/.kube/config`

The files under:

```text
~/.kube/configs-plugin-km/
```

are considered the source of truth.

The main:

```text
~/.kube/config
```

is considered generated output.

### List Contexts

```bash
km contexts
```

### Current Context

```bash
km current
```

### Change Context

Interactive:

```bash
km use
```

Directly:

```bash
km use my-cluster-context
```

The plugin asks for confirmation before changing the current context.

### Validate Clusters

Validate all configured contexts:

```bash
km validate
```

or:

```bash
km status
```

Validate a specific context:

```bash
km validate my-cluster-context
```

Possible statuses include:

```text
ONLINE
AUTH
OFFLINE
TLS
LIMITED
```

### Open K9s

Interactive context selection:

```bash
km k9s
```

Specific context:

```bash
km k9s my-cluster-context
```

Before opening K9s, the plugin:

1. Displays the selected context
2. Displays the Kubernetes API server
3. Validates connectivity
4. Requests confirmation
5. Opens K9s using the context explicitly

For contexts identified as production environments, read-only mode is offered as the default behavior.

Example:

```text
AMBIENTE IDENTIFICADO COMO PRODUÇÃO

[1] Open K9s READ-ONLY
[2] Open K9s normally
[0] Cancel
```

## Temporary Credentials

Some Kubernetes distributions, especially OpenShift environments, may generate kubeconfigs containing short-lived credentials.

The plugin does not identify kubeconfigs exclusively by SHA-256 hash.

Instead, it combines cluster/context metadata with file hashes.

Example:

```text
Same cluster + same hash
→ DUPLICATE

Same cluster + different hash
→ UPDATE

Same API server + different context
→ SAME_SERVER

Different cluster
→ NEW
```

This allows a newly downloaded OpenShift kubeconfig containing a refreshed token to replace the previously managed credential without creating unnecessary duplicate cluster entries.

## Production Safety

The plugin attempts to identify production contexts using names containing terms such as:

```text
prod
prd
production
```

Production contexts receive additional confirmation before K9s is opened.

Whenever possible, production environments should be accessed using:

```bash
k9s --readonly
```

This feature is an additional safety mechanism and should not replace proper Kubernetes RBAC policies.

## Validate Plugin Syntax

Before loading changes:

```bash
zsh -n kube-manager.plugin.zsh
```

No output means the Zsh syntax validation completed successfully.

Then reload:

```bash
source ~/.zshrc
```

## Development

Recommended repository structure:

```text
kube-manager-zsh/
├── .editorconfig
├── .gitignore
├── LICENSE
├── README.md
└── kube-manager.plugin.zsh
```

Recommended VS Code tools:

- Zsh syntax support
- `zshcheck`
- `shfmt`

## Security

Kubeconfig files may contain:

- authentication tokens
- client certificates
- private keys
- cluster endpoints

Never commit kubeconfig files to this repository.

It is strongly recommended to keep permissions restricted:

```bash
chmod 700 ~/.kube
chmod 700 ~/.kube/configs-plugin-km
chmod 700 ~/.kube/backups-plugin-km
chmod 700 ~/.kube/state-plugin-km
chmod 600 ~/.kube/config
```

## Roadmap

Possible future improvements:

- Automatic normalization of duplicated context, cluster, and user names
- Parallel cluster validation
- Better OpenShift credential detection
- Context grouping by environment
- Context grouping by organization
- Shell completion improvements
- Configurable production context patterns
- More detailed connection diagnostics
- Optional automatic cleanup of old backups

## License

This project is licensed under the MIT License.

See [LICENSE](LICENSE) for details.