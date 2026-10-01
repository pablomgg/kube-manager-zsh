# English (US) translations for kube-manager.

typeset -gA KM_I18N_EN_US=(
  error_prefix "ERROR"
  warning_prefix "WARNING"
  missing_dependency "missing dependency: %s"
  file_not_found "File not found: %s"
  invalid_kubeconfig "File does not appear to be a valid kubeconfig: %s"
  duplicate_identical "already imported with identical content."
  registered_source "Registered source: %s"
  update_changed "same cluster/context, different content."
  current_file "Current: %s"
  new_file "New:     %s"
  replace_existing_question "Replace the existing kubeconfig? [y/N]: "
  cancelled "Cancelled."
  updated "Updated: %s"
  same_server_warning "a kubeconfig already points to the same API server:"
  existing_file "Existing: %s"
  new_file_aligned "New:      %s"
  same_server_explanation "This may be a refreshed credential OR another context/namespace on the same cluster."
  replace_existing_option "[1] Replace existing"
  import_separate_option "[2] Import as a separate context"
  cancel_option "[0] Cancel"
  choose_prompt "Choose: "
  choose_default_prompt "Choose [1]: "
  imported "Imported: %s"
  header_status "STATUS"
  header_file "FILE"
  header_context "CONTEXT"
  header_detail "DETAIL"
  import_update_question "Import/update this file? [y/N]: "
  duplicate_word "duplicate"
  collisions_found "Collisions found between kubeconfigs:"
  no_kubeconfigs "No kubeconfig found in %s"
  validating_collisions "Validating collisions..."
  sync_cancelled_collisions "Sync cancelled. In V1 the plugin does not silently overwrite duplicate names."
  backup_label "Backup: %s"
  consolidate_failed "Failed to generate consolidated kubeconfig."
  generated_no_contexts "Generated config has no contexts. Aborted."
  sync_complete "Sync completed. Contexts in main config: %s"
  previous_context_preserved "Previous context preserved when available: %s"
  auth_ok "auth ok"
  limited_detail "authenticated, but not allowed to perform this check"
  auth_detail "expired or invalid credential"
  tls_detail "certificate/TLS error"
  offline_detail "API server unavailable or unreachable"
  config_missing "~/.kube/config does not exist yet. Run km sync."
  select_context_prompt "Kubernetes context > "
  nav_hint "↑/↓ navigate • Enter select • Esc cancel"
  context_not_found "Context not found: %s"
  context_label "Context"
  server_label "Server"
  status_label "Status"
  detail_label "Detail"
  set_current_question "Set this as the current-context? [y/N]: "
  cluster_info_label "cluster-info:"
  k9s_not_installed "k9s is not installed."
  selected_context "Selected context"
  k9s_invalid_connection "K9s will not be opened while the connection is invalid."
  production_detected "PRODUCTION ENVIRONMENT DETECTED"
  k9s_access_mode_question "How do you want to enter K9s?"
  k9s_readonly_option "[1] READ-ONLY mode 🛡️ (recommended)"
  k9s_superman_option "[2] Superman mode 🦸 READ/WRITE"
  superman_mode_enabled "Superman mode enabled. With great power comes great responsibility..."
  confirm_prod_context "Confirm context [%s] again. Type YES to continue: "
  confirm_prod_word "YES"
  no_backups "No config backup found."
  backup_prompt "Backup > "
  current_backup "Current state backup: %s"
  restored "Restored: %s"
  pause "Press ENTER to continue..."
  current_context "Current context"
  sources "Sources"
  action_prompt "Action > "
  menu_status "Status/validate all clusters"
  menu_downloads "Check kubeconfigs in Downloads"
  menu_import "Import a specific kubeconfig"
  menu_sync "Sync configs -> ~/.kube/config"
  menu_contexts "List contexts"
  menu_use "Change current-context"
  menu_validate "Validate a context"
  menu_k9s "Open K9s"
  menu_sources "List sources"
  menu_backups "Backups"
  menu_restore "Restore backup"
  menu_language "Language"
  menu_help "Help"
  menu_exit "Exit"
  downloads_import_question "Enter Downloads import mode? [y/N]: "
  kubeconfig_path "Kubeconfig path: "
  invalid_option "Invalid option."
  import_usage "Usage: km import <file>"
  unknown_command "Unknown command: %s"
  language_title "Select language"
  language_prompt "Language > "
  language_changed "Language changed to %s."
  invalid_language "Invalid language: %s. Use pt_BR or en_US."
)

_km_help_en_US() {
  local topic="$1"
  case "$topic" in
    sync)
      cat <<'HELP'
km sync

Rebuilds ~/.kube/config using all kubeconfigs from:
  ~/.kube/configs-plugin-km/

Before replacing the main config it:
  - validates context/cluster/user collisions
  - creates a backup in backups-plugin-km
  - performs merge + flatten
  - attempts to preserve the previous current-context
HELP
      ;;
    import)
      cat <<'HELP'
km import <file>

Imports a kubeconfig into configs-plugin-km.

Rules:
  - same identity + same hash: DUPLICATE, do not import
  - same identity + different hash: UPDATE, offer replacement
  - same API server + different identity: ask whether to replace or keep separately
  - new cluster: create a new file using the context name
HELP
      ;;
    downloads)
      cat <<'HELP'
km downloads
km downloads import

Searches ~/Downloads for valid kubeconfigs and classifies them as:
  NEW          cluster/context not imported yet
  DUPLICATE    identical to a previously imported file
  UPDATE       same cluster/context, but credential/content changed
  SAME_SERVER  same API server with a different context/namespace

Use "km downloads import" to confirm each import/update interactively.
HELP
      ;;
    k9s)
      cat <<'HELP'
km k9s [context]

Validates and explicitly displays the context before opening K9s.
Always asks whether K9s should open in READ-ONLY or READ/WRITE mode.
READ-ONLY is the default. Contexts named prod/prd/production require
an additional confirmation before Superman READ/WRITE mode.
HELP
      ;;
    lang|language)
      cat <<'HELP'
km lang
km lang pt_BR
km lang en_US

Selects the language used by the interface and help.
The preference is stored at:
  ~/.kube/state-plugin-km/settings.conf
HELP
      ;;
    *)
      cat <<'HELP'
Kubernetes Config Manager (km)

Usage:
  km                         interactive menu
  km help [command]          general or command-specific help
  km sources                 list kubeconfigs in configs-plugin-km
  km scan                    alias for sources
  km downloads               check kubeconfigs in ~/Downloads
  km downloads import        import/update Downloads interactively
  km import <file>           import a specific kubeconfig
  km sync                    rebuild ~/.kube/config
  km contexts                list contexts from the main config
  km current                 show current-context
  km use [context]           select and confirm a current-context
  km status                  validate all contexts
  km validate [context]      validate one or all contexts
  km k9s [context]           validate/confirm and open K9s
  km backups                 list backups
  km restore                 restore a backup interactively
  km lang [pt_BR|en_US]      select interface language

Directories:
  ~/.kube/configs-plugin-km/   kubeconfig sources
  ~/.kube/backups-plugin-km/   plugin backups
  ~/.kube/state-plugin-km/     hashes, metadata and preferences
  ~/.kube/config               consolidated config used by kubectl/K9s

Command help:
  km help import
  km help downloads
  km help sync
  km help k9s
  km help lang
HELP
      ;;
  esac
}
