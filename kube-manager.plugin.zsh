# kube-manager.plugin.zsh
# Personal Kubernetes kubeconfig manager for Oh My Zsh.

# Paths can be overridden before loading the plugin.
# This is useful on Linux/WSL, while keeping macOS defaults unchanged.
KM_KUBE_DIR="${KM_KUBE_DIR:-${HOME}/.kube}"
KM_MAIN_CONFIG="${KM_KUBE_DIR}/config"
KM_CONFIGS_DIR="${KM_KUBE_DIR}/configs-plugin-km"
KM_BACKUPS_DIR="${KM_KUBE_DIR}/backups-plugin-km"
KM_STATE_DIR="${KM_KUBE_DIR}/state-plugin-km"
KM_STATE_FILE="${KM_STATE_DIR}/imports.tsv"
KM_DOWNLOADS_DIR="${KM_DOWNLOADS_DIR:-}"
KM_SETTINGS_FILE="${KM_STATE_DIR}/settings.conf"

# Runtime platform: macos, linux, wsl or unknown.
typeset -g KM_PLATFORM=""

# Absolute plugin path, used to load locale files next to this plugin.
KM_PLUGIN_DIR="${${(%):-%N}:A:h}"

[[ -r "${KM_PLUGIN_DIR}/locales/pt_BR.zsh" ]] && source "${KM_PLUGIN_DIR}/locales/pt_BR.zsh"
[[ -r "${KM_PLUGIN_DIR}/locales/en_US.zsh" ]] && source "${KM_PLUGIN_DIR}/locales/en_US.zsh"

typeset -g KM_LANGUAGE=""


_km_detect_platform() {
  if [[ -n "${WSL_DISTRO_NAME:-}" || -n "${WSL_INTEROP:-}" ]]; then
    KM_PLATFORM="wsl"
    return 0
  fi

  case "$(uname -s 2>/dev/null)" in
    Darwin)
      KM_PLATFORM="macos"
      ;;
    Linux)
      if [[ -r /proc/version ]] && grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
        KM_PLATFORM="wsl"
      else
        KM_PLATFORM="linux"
      fi
      ;;
    *)
      KM_PLATFORM="unknown"
      ;;
  esac
}

_km_detect_downloads_dir() {
  # Respect an explicit user override first.
  [[ -n "${KM_DOWNLOADS_DIR:-}" ]] && return 0

  case "$KM_PLATFORM" in
    wsl)
      # Prefer the Windows user's Downloads folder because browser downloads
      # normally land there when using Windows + WSL.
      if command -v cmd.exe >/dev/null 2>&1 && command -v wslpath >/dev/null 2>&1; then
        local win_profile win_home
        win_profile="$(cmd.exe /C 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r' | tail -n 1)"
        if [[ -n "$win_profile" ]]; then
          win_home="$(wslpath -u "$win_profile" 2>/dev/null)"
          if [[ -n "$win_home" && -d "$win_home/Downloads" ]]; then
            KM_DOWNLOADS_DIR="$win_home/Downloads"
            return 0
          fi
        fi
      fi
      KM_DOWNLOADS_DIR="${HOME}/Downloads"
      ;;

    linux)
      # Respect the desktop/XDG Downloads location when available.
      if command -v xdg-user-dir >/dev/null 2>&1; then
        local xdg_downloads
        xdg_downloads="$(xdg-user-dir DOWNLOAD 2>/dev/null)"
        if [[ -n "$xdg_downloads" && -d "$xdg_downloads" ]]; then
          KM_DOWNLOADS_DIR="$xdg_downloads"
          return 0
        fi
      fi
      KM_DOWNLOADS_DIR="${HOME}/Downloads"
      ;;

    macos|*)
      KM_DOWNLOADS_DIR="${HOME}/Downloads"
      ;;
  esac
}

_km_mktemp() {
  local prefix="${1:-km}"
  local temp_root="${TMPDIR:-/tmp}"
  temp_root="${temp_root%/}"

  # This template form works with both BSD mktemp (macOS)
  # and GNU coreutils mktemp (Linux/WSL).
  mktemp "${temp_root}/${prefix}.XXXXXX"
}

_km_load_language() {
  local saved=""

  if [[ -f "$KM_SETTINGS_FILE" ]]; then
    saved="$(awk -F= '$1 == "KM_LANGUAGE" {print $2; exit}' "$KM_SETTINGS_FILE" 2>/dev/null)"
  fi

  case "$saved" in
    pt_BR|en_US)
      KM_LANGUAGE="$saved"
      return 0
      ;;
  esac

  case "${LANG:-}" in
    pt_BR*|pt_PT*) KM_LANGUAGE="pt_BR" ;;
    *)             KM_LANGUAGE="en_US" ;;
  esac
}

_km_t() {
  local key="$1" value=""

  case "$KM_LANGUAGE" in
    pt_BR) value="${KM_I18N_PT_BR[$key]-}" ;;
    *)     value="${KM_I18N_EN_US[$key]-}" ;;
  esac

  [[ -n "$value" ]] || value="$key"
  printf '%s' "$value"
}

_km_is_yes() {
  case "$1" in
    s|S|sim|SIM|y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

_km_save_language() {
  local lang="$1" label

  case "$lang" in
    pt_BR) label='Português (Brasil)' ;;
    en_US) label='English' ;;
    *)
      printf "$(_km_t invalid_language)\n" "$lang"
      return 1
      ;;
  esac

  printf 'KM_LANGUAGE=%s\n' "$lang" > "$KM_SETTINGS_FILE"
  chmod 600 "$KM_SETTINGS_FILE" 2>/dev/null || true
  KM_LANGUAGE="$lang"
  printf "$(_km_t language_changed)\n" "$label"
}

_km_language() {
  local lang="$1" selected

  if [[ -n "$lang" ]]; then
    _km_save_language "$lang"
    return $?
  fi

  if command -v fzf >/dev/null 2>&1; then
    selected="$(printf '%s\n' \
      'pt_BR  Português (Brasil)' \
      'en_US  English' | fzf \
      --prompt="$(_km_t language_prompt)" \
      --height='~40%' \
      --layout=reverse \
      --border \
      --no-multi \
      --cycle \
      --header="$(_km_t nav_hint)")" || return 0
    lang="${selected%% *}"
  else
    printf '%s\n' '1) Português (Brasil)' '2) English'
    printf '%s' "$(_km_t choose_prompt)"
    IFS= read -r selected
    case "$selected" in
      1) lang='pt_BR' ;;
      2) lang='en_US' ;;
      *) return 0 ;;
    esac
  fi

  _km_save_language "$lang"
}

KM_RED=$'\033[31m'
KM_GREEN=$'\033[32m'
KM_YELLOW=$'\033[33m'
KM_CYAN=$'\033[36m'
KM_BOLD=$'\033[1m'
KM_RESET=$'\033[0m'

alias km='kube-manager'

_km_ensure_dirs() {
  mkdir -p "$KM_KUBE_DIR" "$KM_CONFIGS_DIR" "$KM_BACKUPS_DIR" "$KM_STATE_DIR"
  chmod 700 "$KM_KUBE_DIR" "$KM_CONFIGS_DIR" "$KM_BACKUPS_DIR" "$KM_STATE_DIR" 2>/dev/null || true
  touch "$KM_STATE_FILE"
  chmod 600 "$KM_STATE_FILE" 2>/dev/null || true
  [[ -f "$KM_SETTINGS_FILE" ]] && chmod 600 "$KM_SETTINGS_FILE" 2>/dev/null || true
}

_km_require() {
  local missing=0 cmd
  local required=(kubectl jq awk sed grep find sort paste cut tr head tail basename date mktemp uname)

  for cmd in "${required[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      printf '%s%s%s: ' "$KM_RED" "$(_km_t error_prefix)" "$KM_RESET"
      printf "$(_km_t missing_dependency)\n" "$cmd"
      missing=1
    fi
  done

  if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
    printf '%s%s%s: ' "$KM_RED" "$(_km_t error_prefix)" "$KM_RESET"
    printf "$(_km_t missing_dependency)\n" 'sha256sum/shasum'
    missing=1
  fi

  [[ "$missing" -eq 0 ]]
}

_km_file_hash() {
  local file="$1"

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    return 1
  fi
}

_km_source_files() {
  find "$KM_CONFIGS_DIR" -type f \( -name '*.yaml' -o -name '*.yml' -o -name '*.conf' -o -name 'kubeconfig*' \) -print | sort
}

_km_kubeconfig_json() {
  kubectl config view --kubeconfig="$1" --raw -o json 2>/dev/null
}

_km_is_kubeconfig() {
  local json
  json="$(_km_kubeconfig_json "$1")" || return 1
  printf '%s' "$json" | jq -e '(.clusters | length) > 0 and (.contexts | length) > 0' >/dev/null 2>&1
}

_km_identity_from_file() {
  local json ctx cluster namespace server
  json="$(_km_kubeconfig_json "$1")" || return 1

  ctx="$(printf '%s' "$json" | jq -r '."current-context" // empty')"
  if [ -z "$ctx" ]; then
    ctx="$(printf '%s' "$json" | jq -r '.contexts[0].name // empty')"
  fi
  [ -n "$ctx" ] || return 1

  cluster="$(printf '%s' "$json" | jq -r --arg ctx "$ctx" '.contexts[]? | select(.name == $ctx) | .context.cluster' | head -n 1)"
  namespace="$(printf '%s' "$json" | jq -r --arg ctx "$ctx" '.contexts[]? | select(.name == $ctx) | (.context.namespace // "-")' | head -n 1)"
  server="$(printf '%s' "$json" | jq -r --arg cluster "$cluster" '.clusters[]? | select(.name == $cluster) | .cluster.server' | head -n 1)"

  [ -n "$server" ] || return 1
  printf '%s|%s|%s\n' "$server" "$ctx" "$namespace"
}

_km_server_from_file() {
  local identity
  identity="$(_km_identity_from_file "$1")" || return 1
  printf '%s\n' "${identity%%|*}"
}

_km_context_from_file() {
  local json ctx
  json="$(_km_kubeconfig_json "$1")" || return 1
  ctx="$(printf '%s' "$json" | jq -r '."current-context" // empty')"
  if [ -z "$ctx" ]; then
    ctx="$(printf '%s' "$json" | jq -r '.contexts[0].name // empty')"
  fi
  printf '%s\n' "$ctx"
}

_km_sanitize_name() {
  printf '%s' "$1" | sed 's/[^A-Za-z0-9._-]/-/g; s/--*/-/g; s/^-//; s/-$//'
}

_km_state_line() {
  awk -F '\t' -v id="$1" '$1 == id {print; exit}' "$KM_STATE_FILE" 2>/dev/null
}

_km_state_set() {
  local identity="$1" hash="$2" source="$3" now tmp
  now="$(date '+%Y-%m-%dT%H:%M:%S%z')"
  tmp="$(_km_mktemp km-state)" || return 1
  awk -F '\t' -v id="$identity" '$1 != id' "$KM_STATE_FILE" > "$tmp" 2>/dev/null || true
  printf '%s\t%s\t%s\t%s\n' "$identity" "$hash" "$source" "$now" >> "$tmp"
  mv "$tmp" "$KM_STATE_FILE"
  chmod 600 "$KM_STATE_FILE" 2>/dev/null || true
}

_km_find_source_by_identity() {
  local wanted="$1" source identity
  _km_source_files | while IFS= read -r source; do
    [ -n "$source" ] || continue
    identity="$(_km_identity_from_file "$source" 2>/dev/null)" || continue
    if [ "$identity" = "$wanted" ]; then
      printf '%s\n' "$source"
      break
    fi
  done
}

_km_find_source_by_server() {
  local wanted="$1" source server
  _km_source_files | while IFS= read -r source; do
    [ -n "$source" ] || continue
    server="$(_km_server_from_file "$source" 2>/dev/null)" || continue
    if [ "$server" = "$wanted" ]; then
      printf '%s\n' "$source"
      break
    fi
  done
}

_km_backup_main_config() {
  local stamp dest
  [ -f "$KM_MAIN_CONFIG" ] || return 0
  stamp="$(date '+%Y%m%d-%H%M%S')"
  dest="${KM_BACKUPS_DIR}/config-${stamp}.yaml"
  cp "$KM_MAIN_CONFIG" "$dest" || return 1
  chmod 600 "$dest" 2>/dev/null || true
  printf '%s\n' "$dest"
}

_km_backup_source() {
  local source="$1" stamp base dest
  [ -f "$source" ] || return 0
  stamp="$(date '+%Y%m%d-%H%M%S')"
  base="$(basename "$source")"
  dest="${KM_BACKUPS_DIR}/source-${base}-${stamp}.bak"
  cp "$source" "$dest" || return 1
  chmod 600 "$dest" 2>/dev/null || true
  printf '%s\n' "$dest"
}

_km_classify_file() {
  local file="$1" identity hash line old_hash old_source existing server same_server

  _km_is_kubeconfig "$file" || {
    printf 'INVALID\n'
    return 0
  }

  identity="$(_km_identity_from_file "$file")" || {
    printf 'INVALID\n'
    return 0
  }
  hash="$(_km_file_hash "$file")"

  line="$(_km_state_line "$identity")"
  if [ -n "$line" ]; then
    old_hash="$(printf '%s\n' "$line" | awk -F '\t' '{print $2}')"
    old_source="$(printf '%s\n' "$line" | awk -F '\t' '{print $3}')"
    if [ "$hash" = "$old_hash" ]; then
      printf 'DUPLICATE|%s\n' "$old_source"
    else
      printf 'UPDATE|%s\n' "$old_source"
    fi
    return 0
  fi

  existing="$(_km_find_source_by_identity "$identity")"
  if [ -n "$existing" ]; then
    old_hash="$(_km_file_hash "$existing")"
    if [ "$hash" = "$old_hash" ]; then
      printf 'DUPLICATE|%s\n' "$existing"
    else
      printf 'UPDATE|%s\n' "$existing"
    fi
    return 0
  fi

  server="$(_km_server_from_file "$file")"
  same_server="$(_km_find_source_by_server "$server")"
  if [ -n "$same_server" ]; then
    printf 'SAME_SERVER|%s\n' "$same_server"
  else
    printf 'NEW|\n'
  fi
}

_km_import_file() {
  local file="$1" classification km_status existing identity hash ctx safe dest answer

  [[ -f "$file" ]] || {
    printf '%s%s%s: ' "$KM_RED" "$(_km_t error_prefix)" "$KM_RESET"
    printf "$(_km_t file_not_found)\n" "$file"
    return 1
  }

  if ! _km_is_kubeconfig "$file"; then
    printf '%s%s%s: ' "$KM_RED" "$(_km_t error_prefix)" "$KM_RESET"
    printf "$(_km_t invalid_kubeconfig)\n" "$file"
    return 1
  fi

  classification="$(_km_classify_file "$file")"
  km_status="${classification%%|*}"
  existing="${classification#*|}"
  identity="$(_km_identity_from_file "$file")"
  hash="$(_km_file_hash "$file")"
  ctx="$(_km_context_from_file "$file")"

  case "$km_status" in
    DUPLICATE)
      printf '%sDUPLICATE%s: %s\n' "$KM_CYAN" "$KM_RESET" "$(_km_t duplicate_identical)"
      printf "$(_km_t registered_source)\n" "$existing"
      return 0
      ;;

    UPDATE)
      printf '%sUPDATE%s: %s\n' "$KM_YELLOW" "$KM_RESET" "$(_km_t update_changed)"
      printf "$(_km_t current_file)\n" "$existing"
      printf "$(_km_t new_file)\n" "$file"
      printf '%s' "$(_km_t replace_existing_question)"
      IFS= read -r answer
      if ! _km_is_yes "$answer"; then
        printf '%s\n' "$(_km_t cancelled)"
        return 0
      fi
      _km_backup_source "$existing" >/dev/null || return 1
      cp "$file" "$existing" || return 1
      chmod 600 "$existing" 2>/dev/null || true
      _km_state_set "$identity" "$hash" "$existing"
      printf '%s' "$KM_GREEN"
      printf "$(_km_t updated)\n" "$existing"
      printf '%s' "$KM_RESET"
      return 0
      ;;

    SAME_SERVER)
      printf '%s%s%s: %s\n' "$KM_YELLOW" "$(_km_t warning_prefix)" "$KM_RESET" "$(_km_t same_server_warning)"
      printf "$(_km_t existing_file)\n" "$existing"
      printf "$(_km_t new_file_aligned)\n" "$file"
      printf '\n%s\n' "$(_km_t same_server_explanation)"
      printf ' %s\n %s\n %s\n%s' \
        "$(_km_t replace_existing_option)" \
        "$(_km_t import_separate_option)" \
        "$(_km_t cancel_option)" \
        "$(_km_t choose_prompt)"
      IFS= read -r answer
      case "$answer" in
        1)
          _km_backup_source "$existing" >/dev/null || return 1
          cp "$file" "$existing" || return 1
          chmod 600 "$existing" 2>/dev/null || true
          _km_state_set "$identity" "$hash" "$existing"
          printf '%s' "$KM_GREEN"
          printf "$(_km_t updated)\n" "$existing"
          printf '%s' "$KM_RESET"
          return 0
          ;;
        2) ;;
        *)
          printf '%s\n' "$(_km_t cancelled)"
          return 0
          ;;
      esac
      ;;
  esac

  safe="$(_km_sanitize_name "$ctx")"
  [[ -n "$safe" ]] || safe="cluster-$(printf '%s' "$hash" | cut -c1-8)"
  dest="${KM_CONFIGS_DIR}/${safe}.yaml"

  if [[ -e "$dest" ]]; then
    dest="${KM_CONFIGS_DIR}/${safe}-$(printf '%s' "$hash" | cut -c1-8).yaml"
  fi

  cp "$file" "$dest" || return 1
  chmod 600 "$dest" 2>/dev/null || true
  _km_state_set "$identity" "$hash" "$dest"

  printf '%s' "$KM_GREEN"
  printf "$(_km_t imported)\n" "$dest"
  printf '%s' "$KM_RESET"
}

_km_sources() {
  local source identity hash line old_hash km_status
  printf '%-12s %-40s %s\n' "$(_km_t header_status)" "$(_km_t header_file)" "$(_km_t header_context)"
  printf '%s\n' '--------------------------------------------------------------------------------'

  _km_source_files | while IFS= read -r source; do
    [[ -n "$source" ]] || continue
    if ! _km_is_kubeconfig "$source"; then
      printf '%-12s %-40s %s\n' 'INVALID' "$(basename "$source")" '-'
      continue
    fi

    identity="$(_km_identity_from_file "$source")"
    hash="$(_km_file_hash "$source")"
    line="$(_km_state_line "$identity")"

    if [[ -z "$line" ]]; then
      km_status='UNTRACKED'
    else
      old_hash="$(printf '%s\n' "$line" | awk -F '\t' '{print $2}')"
      if [[ "$hash" = "$old_hash" ]]; then km_status='TRACKED'; else km_status='CHANGED'; fi
    fi

    printf '%-12s %-40s %s\n' "$km_status" "$(basename "$source")" "$(_km_context_from_file "$source")"
  done
}

_km_download_candidates() {
  local file base
  _km_detect_downloads_dir
  [[ -d "$KM_DOWNLOADS_DIR" ]] || return 0

  setopt local_options nonomatch 2>/dev/null || true
  for file in "$KM_DOWNLOADS_DIR"/*; do
    [ -f "$file" ] || continue
    base="$(basename "$file")"
    case "$base" in
      kubeconfig*|*.yaml|*.yml|*.conf|*.config)
        if _km_is_kubeconfig "$file"; then
          printf '%s\n' "$file"
        fi
        ;;
    esac
  done
}

_km_downloads() {
  local mode="$1" file classification km_status existing ctx answer found=0

  printf '%-14s %-35s %s\n' "$(_km_t header_status)" "$(_km_t header_file)" "$(_km_t header_context)"
  printf '%s\n' '--------------------------------------------------------------------------------'

  while IFS= read -r file <&3; do
    [[ -n "$file" ]] || continue
    found=1
    classification="$(_km_classify_file "$file")"
    km_status="${classification%%|*}"
    existing="${classification#*|}"
    ctx="$(_km_context_from_file "$file")"
    printf '%-14s %-35s %s\n' "$km_status" "$(basename "$file")" "$ctx"

    if [[ "$mode" = 'import' && "$km_status" != 'DUPLICATE' && "$km_status" != 'INVALID' ]]; then
      printf '%s' "$(_km_t import_update_question)"
      IFS= read -r answer
      _km_is_yes "$answer" && _km_import_file "$file"
      printf '\n'
    fi
  done 3< <(_km_download_candidates)
}

_km_check_collisions() {
  local tmp source json collisions
  tmp="$(_km_mktemp km-collisions)" || return 1

  _km_source_files | while IFS= read -r source; do
    [[ -n "$source" ]] || continue
    json="$(_km_kubeconfig_json "$source")" || continue
    printf '%s' "$json" | jq -r '.contexts[]?.name' | while IFS= read -r n; do printf 'context\t%s\t%s\n' "$n" "$source"; done
    printf '%s' "$json" | jq -r '.clusters[]?.name' | while IFS= read -r n; do printf 'cluster\t%s\t%s\n' "$n" "$source"; done
    printf '%s' "$json" | jq -r '.users[]?.name'    | while IFS= read -r n; do printf 'user\t%s\t%s\n' "$n" "$source"; done
  done > "$tmp"

  collisions="$(awk -F '\t' -v dup="$(_km_t duplicate_word)" '
    {
      key=$1 "\t" $2
      count[key]++
      files[key]=files[key] "\n      - " $3
    }
    END {
      for (key in count) {
        if (count[key] > 1) {
          split(key, parts, "\t")
          printf "%s %s: %s%s\n", parts[1], dup, parts[2], files[key]
        }
      }
    }
  ' "$tmp")"
  rm -f "$tmp"

  if [[ -n "$collisions" ]]; then
    printf '%s%s%s\n\n%s\n' "$KM_RED" "$(_km_t collisions_found)" "$KM_RESET" "$collisions"
    return 1
  fi
  return 0
}

_km_sync() {
  local files kubeconfig_list temp backup old_context context_count source identity hash
  files="$(_km_source_files)"
  if [[ -z "$files" ]]; then
    printf '%s' "$KM_YELLOW"
    printf "$(_km_t no_kubeconfigs)\n" "$KM_CONFIGS_DIR"
    printf '%s' "$KM_RESET"
    return 1
  fi

  printf '%s\n' "$(_km_t validating_collisions)"
  _km_check_collisions || {
    printf '\n%s\n' "$(_km_t sync_cancelled_collisions)"
    return 1
  }

  old_context="$(kubectl config current-context --kubeconfig="$KM_MAIN_CONFIG" 2>/dev/null || true)"
  backup="$(_km_backup_main_config)" || return 1
  [[ -n "$backup" ]] && printf "$(_km_t backup_label)\n" "$backup"

  kubeconfig_list="$(printf '%s\n' "$files" | paste -sd ':' -)"
  temp="$(_km_mktemp km-config)" || return 1

  if ! KUBECONFIG="$kubeconfig_list" kubectl config view --flatten --raw > "$temp"; then
    rm -f "$temp"
    printf '%s%s%s\n' "$KM_RED" "$(_km_t consolidate_failed)" "$KM_RESET"
    return 1
  fi

  context_count="$(kubectl config view --kubeconfig="$temp" -o json 2>/dev/null | jq '.contexts | length')"
  if [[ -z "$context_count" || "$context_count" -eq 0 ]]; then
    rm -f "$temp"
    printf '%s%s%s\n' "$KM_RED" "$(_km_t generated_no_contexts)" "$KM_RESET"
    return 1
  fi

  chmod 600 "$temp"
  mv "$temp" "$KM_MAIN_CONFIG"
  chmod 600 "$KM_MAIN_CONFIG" 2>/dev/null || true

  if [[ -n "$old_context" ]] && kubectl config get-contexts --kubeconfig="$KM_MAIN_CONFIG" -o name 2>/dev/null | grep -Fxq "$old_context"; then
    kubectl config use-context --kubeconfig="$KM_MAIN_CONFIG" "$old_context" >/dev/null 2>&1 || true
  fi

  _km_source_files | while IFS= read -r source; do
    [[ -n "$source" ]] || continue
    identity="$(_km_identity_from_file "$source" 2>/dev/null)" || continue
    hash="$(_km_file_hash "$source")"
    _km_state_set "$identity" "$hash" "$source"
  done

  printf '%s' "$KM_GREEN"
  printf "$(_km_t sync_complete)\n" "$context_count"
  printf '%s' "$KM_RESET"
  [[ -n "$old_context" ]] && printf "$(_km_t previous_context_preserved)\n" "$old_context"
}

_km_context_server() {
  local ctx="$1" json cluster
  json="$(kubectl config view --kubeconfig="$KM_MAIN_CONFIG" --raw -o json 2>/dev/null)" || return 1
  cluster="$(printf '%s' "$json" | jq -r --arg ctx "$ctx" '.contexts[]? | select(.name == $ctx) | .context.cluster' | head -n1)"
  printf '%s' "$json" | jq -r --arg cluster "$cluster" '.clusters[]? | select(.name == $cluster) | .cluster.server' | head -n1
}

_km_validate_context_machine() {
  local ctx="$1" output rc lower
  output="$(kubectl --kubeconfig="$KM_MAIN_CONFIG" --context="$ctx" --request-timeout=5s auth can-i get namespaces 2>&1)"
  rc=$?
  lower="$(printf '%s' "$output" | tr '[:upper:]' '[:lower:]')"

  if [[ "$rc" -eq 0 ]] && printf '%s\n' "$lower" | grep -q 'yes'; then
    printf 'ONLINE|%s\n' "$(_km_t auth_ok)"
  elif printf '%s\n' "$lower" | grep -Eq '(^|[[:space:]])no($|[[:space:]])|forbidden'; then
    printf 'LIMITED|%s\n' "$(_km_t limited_detail)"
  elif printf '%s\n' "$lower" | grep -Eq 'unauthorized|must be logged in|token.*expired|expired.*token|invalid.*token'; then
    printf 'AUTH|%s\n' "$(_km_t auth_detail)"
  elif printf '%s\n' "$lower" | grep -Eq 'x509|certificate.*expired|certificate signed by unknown'; then
    printf 'TLS|%s\n' "$(_km_t tls_detail)"
  elif printf '%s\n' "$lower" | grep -Eq 'timeout|timed out|connection refused|no route to host|dial tcp|i/o timeout|context deadline exceeded|network is unreachable'; then
    printf 'OFFLINE|%s\n' "$(_km_t offline_detail)"
  else
    printf 'ERROR|%s\n' "$(printf '%s' "$output" | head -n1)"
  fi
}

_km_status() {
  local ctx result km_status detail
  if [[ ! -f "$KM_MAIN_CONFIG" ]]; then
    printf '%s%s%s\n' "$KM_YELLOW" "$(_km_t config_missing)" "$KM_RESET"
    return 1
  fi

  printf '%-10s %-40s %s\n' "$(_km_t header_status)" "$(_km_t header_context)" "$(_km_t header_detail)"
  printf '%s\n' '------------------------------------------------------------------------------------------'
  kubectl config get-contexts --kubeconfig="$KM_MAIN_CONFIG" -o name 2>/dev/null | while IFS= read -r ctx; do
    [[ -n "$ctx" ]] || continue
    result="$(_km_validate_context_machine "$ctx")"
    km_status="${result%%|*}"
    detail="${result#*|}"
    printf '%-10s %-40s %s\n' "$km_status" "$ctx" "$detail"
  done
}

_km_select_context() {
  local contexts choice
  contexts="$(kubectl config get-contexts --kubeconfig="$KM_MAIN_CONFIG" -o name 2>/dev/null)"
  [[ -n "$contexts" ]] || return 1

  if command -v fzf >/dev/null 2>&1; then
    printf '%s\n' "$contexts" | fzf \
      --prompt="$(_km_t select_context_prompt)" \
      --height='~40%' \
      --layout=reverse \
      --border \
      --no-multi \
      --cycle \
      --header="$(_km_t nav_hint)"
    return $?
  fi

  printf '%s\n' "$contexts" | awk '{printf " %2d) %s\\n", NR, $0}' >&2
  printf '%s' "$(_km_t choose_prompt)" >&2
  IFS= read -r choice
  printf '%s\n' "$contexts" | sed -n "${choice}p"
}

_km_contexts() {
  kubectl config get-contexts --kubeconfig="$KM_MAIN_CONFIG"
}

_km_current() {
  kubectl config current-context --kubeconfig="$KM_MAIN_CONFIG"
}

_km_use() {
  local ctx="$1" server answer
  [[ -n "$ctx" ]] || ctx="$(_km_select_context)" || return 1

  if ! kubectl config get-contexts --kubeconfig="$KM_MAIN_CONFIG" -o name | grep -Fxq "$ctx"; then
    printf '%s' "$KM_RED"
    printf "$(_km_t context_not_found)\n" "$ctx"
    printf '%s' "$KM_RESET"
    return 1
  fi

  server="$(_km_context_server "$ctx")"
  printf '\n%s: %s\n%s: %s\n\n' "$(_km_t context_label)" "$ctx" "$(_km_t server_label)" "$server"
  printf '%s' "$(_km_t set_current_question)"
  IFS= read -r answer
  if _km_is_yes "$answer"; then
    kubectl config use-context --kubeconfig="$KM_MAIN_CONFIG" "$ctx"
  else
    printf '%s\n' "$(_km_t cancelled)"
  fi
}

_km_validate() {
  local ctx="$1" result km_status detail
  if [[ -z "$ctx" ]]; then
    _km_status
    return $?
  fi

  result="$(_km_validate_context_machine "$ctx")"
  km_status="${result%%|*}"
  detail="${result#*|}"
  printf '%s: %s\n%s: %s\n%s: %s\n%s: %s\n' \
    "$(_km_t context_label)" "$ctx" \
    "$(_km_t status_label)" "$km_status" \
    "$(_km_t detail_label)" "$detail" \
    "$(_km_t server_label)" "$(_km_context_server "$ctx")"

  if [[ "$km_status" = 'ONLINE' || "$km_status" = 'LIMITED' ]]; then
    printf '\n%s\n' "$(_km_t cluster_info_label)"
    kubectl --kubeconfig="$KM_MAIN_CONFIG" --context="$ctx" --request-timeout=5s cluster-info 2>&1
  fi
}

_km_is_prod_context() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | grep -Eq '(^|[-_.])(prod|prd|production)([-_.]|$)'
}

_km_k9s() {
  local ctx="$1" result km_status detail server answer mode
  command -v k9s >/dev/null 2>&1 || {
    printf '%s%s%s\n' "$KM_RED" "$(_km_t k9s_not_installed)" "$KM_RESET"
    return 1
  }

  [[ -n "$ctx" ]] || ctx="$(_km_select_context)" || return 1
  result="$(_km_validate_context_machine "$ctx")"
  km_status="${result%%|*}"
  detail="${result#*|}"
  server="$(_km_context_server "$ctx")"

  printf '\n%s%s%s\n' "$KM_BOLD" "$(_km_t selected_context)" "$KM_RESET"
  printf '%s: %s\n%s: %s\n%s: %s - %s\n\n' \
    "$(_km_t context_label)" "$ctx" \
    "$(_km_t server_label)" "$server" \
    "$(_km_t status_label)" "$km_status" "$detail"

  case "$km_status" in
    AUTH|TLS|OFFLINE|ERROR)
      printf '%s%s%s\n' "$KM_RED" "$(_km_t k9s_invalid_connection)" "$KM_RESET"
      return 1
      ;;
  esac

  if _km_is_prod_context "$ctx"; then
    printf '%s%s%s\n\n' "$KM_YELLOW" "$(_km_t production_detected)" "$KM_RESET"
  fi

  printf '%s\n' "$(_km_t k9s_access_mode_question)"
  printf ' %s\n' "$(_km_t k9s_readonly_option)"
  printf ' %s\n' "$(_km_t k9s_superman_option)"
  printf ' %s\n%s' "$(_km_t cancel_option)" "$(_km_t choose_default_prompt)"

  IFS= read -r mode
  [[ -n "$mode" ]] || mode=1

  case "$mode" in
    1)
      k9s --kubeconfig "$KM_MAIN_CONFIG" --context "$ctx" --readonly
      ;;

    2)
      if _km_is_prod_context "$ctx"; then
        printf "$(_km_t confirm_prod_context)" "$ctx"
        IFS= read -r answer

        if [[ "$answer" != "$(_km_t confirm_prod_word)" ]]; then
          printf '%s\n' "$(_km_t cancelled)"
          return 0
        fi
      fi

      printf '%s\n' "$(_km_t superman_mode_enabled)"
      k9s --kubeconfig "$KM_MAIN_CONFIG" --context "$ctx"
      ;;

    *)
      printf '%s\n' "$(_km_t cancelled)"
      ;;
  esac
}

_km_backups() {
  ls -lt "$KM_BACKUPS_DIR" 2>/dev/null || true
}

_km_restore() {
  local files selected choice current_backup
  files="$(find "$KM_BACKUPS_DIR" -type f -name 'config-*.yaml' -print | sort -r)"
  [[ -n "$files" ]] || {
    printf '%s\n' "$(_km_t no_backups)"
    return 1
  }

  if command -v fzf >/dev/null 2>&1; then
    selected="$(printf '%s\n' "$files" | fzf \
      --prompt="$(_km_t backup_prompt)" \
      --height='~40%' \
      --layout=reverse \
      --border \
      --no-multi \
      --cycle \
      --header="$(_km_t nav_hint)")" || return 1
  else
    printf '%s\n' "$files" | awk '{printf " %2d) %s\\n", NR, $0}'
    printf '%s' "$(_km_t choose_prompt)"
    IFS= read -r choice
    selected="$(printf '%s\n' "$files" | sed -n "${choice}p")"
  fi

  [[ -n "$selected" ]] || return 1
  current_backup="$(_km_backup_main_config)" || return 1
  [[ -n "$current_backup" ]] && printf "$(_km_t current_backup)\n" "$current_backup"
  cp "$selected" "$KM_MAIN_CONFIG" || return 1
  chmod 600 "$KM_MAIN_CONFIG" 2>/dev/null || true
  printf '%s' "$KM_GREEN"
  printf "$(_km_t restored)\n" "$selected"
  printf '%s' "$KM_RESET"
}

_km_help() {
  local topic="$1"
  case "$KM_LANGUAGE" in
    pt_BR) _km_help_pt_BR "$topic" ;;
    *)     _km_help_en_US "$topic" ;;
  esac
}

_km_pause() {
  printf '\n%s' "$(_km_t pause)"
  IFS= read -r _km_dummy
}

_km_menu_numeric() {
  local option file
  while true; do
    clear
    printf '%sKubernetes Config Manager%s\n\n' "$KM_BOLD" "$KM_RESET"
    printf '%s: %s\n' "$(_km_t current_context)" "$(kubectl config current-context --kubeconfig="$KM_MAIN_CONFIG" 2>/dev/null || printf '-')"
    printf '%s: %s\n\n' "$(_km_t sources)" "$KM_CONFIGS_DIR"
    printf '  1) %s\n' "$(_km_t menu_status)"
    printf '  2) %s\n' "$(_km_t menu_downloads)"
    printf '  3) %s\n' "$(_km_t menu_import)"
    printf '  4) %s\n' "$(_km_t menu_sync)"
    printf '  5) %s\n' "$(_km_t menu_contexts)"
    printf '  6) %s\n' "$(_km_t menu_use)"
    printf '  7) %s\n' "$(_km_t menu_validate)"
    printf '  8) %s\n' "$(_km_t menu_k9s)"
    printf '  9) %s\n' "$(_km_t menu_sources)"
    printf ' 10) %s\n' "$(_km_t menu_backups)"
    printf ' 11) %s\n' "$(_km_t menu_restore)"
    printf ' 12) %s\n' "$(_km_t menu_language)"
    printf '  h) %s\n' "$(_km_t menu_help)"
    printf '  0) %s\n' "$(_km_t menu_exit)"
    printf '\n%s' "$(_km_t choose_prompt)"
    IFS= read -r option

    case "$option" in
      1) _km_status; _km_pause ;;
      2)
        _km_downloads
        printf '\n%s' "$(_km_t downloads_import_question)"
        IFS= read -r option
        _km_is_yes "$option" && _km_downloads import
        _km_pause
        ;;
      3)
        printf '%s' "$(_km_t kubeconfig_path)"
        IFS= read -r file
        file="${file/#\~/$HOME}"
        _km_import_file "$file"
        _km_pause
        ;;
      4) _km_sync; _km_pause ;;
      5) _km_contexts; _km_pause ;;
      6) _km_use; _km_pause ;;
      7) option="$(_km_select_context)" && _km_validate "$option"; _km_pause ;;
      8) _km_k9s; _km_pause ;;
      9) _km_sources; _km_pause ;;
      10) _km_backups; _km_pause ;;
      11) _km_restore; _km_pause ;;
      12) _km_language ;;
      h|H|help) _km_help; _km_pause ;;
      0|q|Q) return 0 ;;
      *) printf '%s\n' "$(_km_t invalid_option)"; sleep 1 ;;
    esac
  done
}

_km_menu() {
  local selected action file answer context

  if ! command -v fzf >/dev/null 2>&1; then
    _km_menu_numeric
    return $?
  fi

  while true; do
    clear
    printf '%sKubernetes Config Manager%s\n\n' "$KM_BOLD" "$KM_RESET"
    printf '%s: %s\n' "$(_km_t current_context)" "$(kubectl config current-context --kubeconfig="$KM_MAIN_CONFIG" 2>/dev/null || printf '-')"
    printf '%s: %s\n\n' "$(_km_t sources)" "$KM_CONFIGS_DIR"

    selected="$(
      printf '%s\n' \
        "01  $(_km_t menu_status)" \
        "02  $(_km_t menu_downloads)" \
        "03  $(_km_t menu_import)" \
        "04  $(_km_t menu_sync)" \
        "05  $(_km_t menu_contexts)" \
        "06  $(_km_t menu_use)" \
        "07  $(_km_t menu_validate)" \
        "08  $(_km_t menu_k9s)" \
        "09  $(_km_t menu_sources)" \
        "10  $(_km_t menu_backups)" \
        "11  $(_km_t menu_restore)" \
        "12  $(_km_t menu_language)" \
        "H   $(_km_t menu_help)" \
        "0   $(_km_t menu_exit)" | fzf \
          --prompt="$(_km_t action_prompt)" \
          --height='~70%' \
          --layout=reverse \
          --border \
          --no-multi \
          --cycle \
          --header="$(_km_t nav_hint)"
    )" || return 0

    action="${selected%% *}"

    case "$action" in
      01) _km_status; _km_pause ;;
      02)
        _km_downloads
        printf '\n%s' "$(_km_t downloads_import_question)"
        IFS= read -r answer
        _km_is_yes "$answer" && _km_downloads import
        _km_pause
        ;;
      03)
        printf '%s' "$(_km_t kubeconfig_path)"
        IFS= read -r file
        file="${file/#\~/$HOME}"
        _km_import_file "$file"
        _km_pause
        ;;
      04) _km_sync; _km_pause ;;
      05) _km_contexts; _km_pause ;;
      06) _km_use; _km_pause ;;
      07)
        context="$(_km_select_context)" && _km_validate "$context"
        _km_pause
        ;;
      08) _km_k9s; _km_pause ;;
      09) _km_sources; _km_pause ;;
      10) _km_backups; _km_pause ;;
      11) _km_restore; _km_pause ;;
      12) _km_language ;;
      H|h) _km_help; _km_pause ;;
      0) return 0 ;;
    esac
  done
}

kube-manager() {
  _km_detect_platform
  _km_detect_downloads_dir
  _km_ensure_dirs
  _km_load_language
  _km_require || return 1

  local command="${1:-menu}"
  [[ "$#" -gt 0 ]] && shift

  case "$command" in
    menu) _km_menu ;;
    help|-h|--help) _km_help "$1" ;;
    sources|scan) _km_sources ;;
    downloads) _km_downloads "$1" ;;
    import)
      [[ -n "$1" ]] || { printf '%s\n' "$(_km_t import_usage)"; return 1; }
      _km_import_file "${1/#\~/$HOME}"
      ;;
    sync) _km_sync ;;
    contexts) _km_contexts ;;
    current) _km_current ;;
    use) _km_use "$1" ;;
    status) _km_status ;;
    validate) _km_validate "$1" ;;
    k9s) _km_k9s "$1" ;;
    backups) _km_backups ;;
    restore) _km_restore ;;
    lang|language) _km_language "$1" ;;
    *)
      printf "$(_km_t unknown_command)\n\n" "$command"
      _km_help
      return 1
      ;;
  esac
}
