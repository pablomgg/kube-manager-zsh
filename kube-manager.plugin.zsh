# kube-manager.plugin.zsh
# Personal Kubernetes kubeconfig manager for Oh My Zsh.

KM_KUBE_DIR="${HOME}/.kube"
KM_MAIN_CONFIG="${KM_KUBE_DIR}/config"
KM_CONFIGS_DIR="${KM_KUBE_DIR}/configs-plugin-km"
KM_BACKUPS_DIR="${KM_KUBE_DIR}/backups-plugin-km"
KM_STATE_DIR="${KM_KUBE_DIR}/state-plugin-km"
KM_STATE_FILE="${KM_STATE_DIR}/imports.tsv"
KM_DOWNLOADS_DIR="${HOME}/Downloads"

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
}

_km_require() {
  local missing=0 cmd
  for cmd in kubectl jq shasum awk sed grep find sort; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      printf '%sERRO%s: dependência ausente: %s\n' "$KM_RED" "$KM_RESET" "$cmd"
      missing=1
    fi
  done
  [ "$missing" -eq 0 ]
}

_km_file_hash() {
  shasum -a 256 "$1" | awk '{print $1}'
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
  tmp="$(mktemp -t km-state)" || return 1
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
  local file="$1" classification km_status existing identity hash ctx safe dest answer server

  [ -f "$file" ] || {
    printf '%sArquivo não encontrado:%s %s\n' "$KM_RED" "$KM_RESET" "$file"
    return 1
  }

  if ! _km_is_kubeconfig "$file"; then
    printf '%sArquivo não parece ser um kubeconfig válido:%s %s\n' "$KM_RED" "$KM_RESET" "$file"
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
      printf '%sDUPLICATE%s: já importado e conteúdo idêntico.\n' "$KM_CYAN" "$KM_RESET"
      printf 'Origem cadastrada: %s\n' "$existing"
      return 0
      ;;

    UPDATE)
      printf '%sUPDATE%s: mesmo cluster/contexto, conteúdo diferente.\n' "$KM_YELLOW" "$KM_RESET"
      printf 'Atual: %s\nNovo:  %s\n' "$existing" "$file"
      printf 'Substituir o kubeconfig existente? [s/N]: '
      IFS= read -r answer
      case "$answer" in s|S|sim|SIM|y|Y|yes|YES) ;; *) printf 'Cancelado.\n'; return 0 ;; esac
      _km_backup_source "$existing" >/dev/null || return 1
      cp "$file" "$existing" || return 1
      chmod 600 "$existing" 2>/dev/null || true
      _km_state_set "$identity" "$hash" "$existing"
      printf '%sAtualizado:%s %s\n' "$KM_GREEN" "$KM_RESET" "$existing"
      return 0
      ;;

    SAME_SERVER)
      printf '%sATENÇÃO%s: já existe um kubeconfig apontando para o mesmo API server:\n' "$KM_YELLOW" "$KM_RESET"
      printf 'Existente: %s\nNovo:      %s\n' "$existing" "$file"
      printf '\nPode ser uma credencial renovada OU outro contexto/namespace no mesmo cluster.\n'
      printf ' [1] Substituir o existente\n [2] Importar como contexto separado\n [0] Cancelar\nEscolha: '
      IFS= read -r answer
      case "$answer" in
        1)
          _km_backup_source "$existing" >/dev/null || return 1
          cp "$file" "$existing" || return 1
          chmod 600 "$existing" 2>/dev/null || true
          _km_state_set "$identity" "$hash" "$existing"
          printf '%sAtualizado:%s %s\n' "$KM_GREEN" "$KM_RESET" "$existing"
          return 0
          ;;
        2) ;;
        *) printf 'Cancelado.\n'; return 0 ;;
      esac
      ;;
  esac

  safe="$(_km_sanitize_name "$ctx")"
  [ -n "$safe" ] || safe="cluster-$(printf '%s' "$hash" | cut -c1-8)"
  dest="${KM_CONFIGS_DIR}/${safe}.yaml"

  if [ -e "$dest" ]; then
    dest="${KM_CONFIGS_DIR}/${safe}-$(printf '%s' "$hash" | cut -c1-8).yaml"
  fi

  cp "$file" "$dest" || return 1
  chmod 600 "$dest" 2>/dev/null || true
  _km_state_set "$identity" "$hash" "$dest"

  printf '%sImportado:%s %s\n' "$KM_GREEN" "$KM_RESET" "$dest"
}

_km_sources() {
  local source identity hash line old_hash km_status
  printf '%-12s %-40s %s\n' 'STATUS' 'ARQUIVO' 'CONTEXTO'
  printf '%s\n' '--------------------------------------------------------------------------------'

  _km_source_files | while IFS= read -r source; do
    [ -n "$source" ] || continue
    if ! _km_is_kubeconfig "$source"; then
      printf '%-12s %-40s %s\n' 'INVALID' "$(basename "$source")" '-'
      continue
    fi

    identity="$(_km_identity_from_file "$source")"
    hash="$(_km_file_hash "$source")"
    line="$(_km_state_line "$identity")"

    if [ -z "$line" ]; then
      km_status='UNTRACKED'
    else
      old_hash="$(printf '%s\n' "$line" | awk -F '\t' '{print $2}')"
      if [ "$hash" = "$old_hash" ]; then km_status='TRACKED'; else km_status='CHANGED'; fi
    fi

    printf '%-12s %-40s %s\n' "$km_status" "$(basename "$source")" "$(_km_context_from_file "$source")"
  done
}

_km_download_candidates() {
  local file base
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

  printf '%-14s %-35s %s\n' 'STATUS' 'ARQUIVO' 'CONTEXTO'
  printf '%s\n' '--------------------------------------------------------------------------------'

  while IFS= read -r file <&3; do
    [ -n "$file" ] || continue
    found=1
    classification="$(_km_classify_file "$file")"
    km_status="${classification%%|*}"
    existing="${classification#*|}"
    ctx="$(_km_context_from_file "$file")"
    printf '%-14s %-35s %s\n' "$km_status" "$(basename "$file")" "$ctx"

    if [ "$mode" = 'import' ] && [ "$km_status" != 'DUPLICATE' ] && [ "$km_status" != 'INVALID' ]; then
      printf 'Importar/atualizar este arquivo? [s/N]: '
      IFS= read -r answer
      case "$answer" in s|S|sim|SIM|y|Y|yes|YES) _km_import_file "$file" ;; esac
      printf '\n'
    fi
  done 3< <(_km_download_candidates)
}

_km_check_collisions() {
  local tmp source json collisions
  tmp="$(mktemp -t km-collisions)" || return 1

  _km_source_files | while IFS= read -r source; do
    [ -n "$source" ] || continue
    json="$(_km_kubeconfig_json "$source")" || continue
    printf '%s' "$json" | jq -r '.contexts[]?.name' | while IFS= read -r n; do printf 'context\t%s\t%s\n' "$n" "$source"; done
    printf '%s' "$json" | jq -r '.clusters[]?.name' | while IFS= read -r n; do printf 'cluster\t%s\t%s\n' "$n" "$source"; done
    printf '%s' "$json" | jq -r '.users[]?.name'    | while IFS= read -r n; do printf 'user\t%s\t%s\n' "$n" "$source"; done
  done > "$tmp"

  collisions="$(awk -F '\t' '
    {
      key=$1 "\t" $2
      count[key]++
      files[key]=files[key] "\n      - " $3
    }
    END {
      for (key in count) {
        if (count[key] > 1) {
          split(key, parts, "\t")
          printf "%s duplicado: %s%s\n", parts[1], parts[2], files[key]
        }
      }
    }
  ' "$tmp")"
  rm -f "$tmp"

  if [ -n "$collisions" ]; then
    printf '%sColisões encontradas entre kubeconfigs:%s\n\n%s\n' "$KM_RED" "$KM_RESET" "$collisions"
    return 1
  fi
  return 0
}

_km_sync() {
  local files kubeconfig_list temp backup old_context context_count source identity hash
  files="$(_km_source_files)"
  if [ -z "$files" ]; then
    printf '%sNenhum kubeconfig encontrado em %s%s\n' "$KM_YELLOW" "$KM_CONFIGS_DIR" "$KM_RESET"
    return 1
  fi

  printf 'Validando colisões...\n'
  _km_check_collisions || {
    printf '\nSync cancelado. Na V1 o plugin não sobrescreve nomes duplicados silenciosamente.\n'
    return 1
  }

  old_context="$(kubectl config current-context --kubeconfig="$KM_MAIN_CONFIG" 2>/dev/null || true)"
  backup="$(_km_backup_main_config)" || return 1
  [ -n "$backup" ] && printf 'Backup: %s\n' "$backup"

  kubeconfig_list="$(printf '%s\n' "$files" | paste -sd ':' -)"
  temp="$(mktemp -t km-config)" || return 1

  if ! KUBECONFIG="$kubeconfig_list" kubectl config view --flatten --raw > "$temp"; then
    rm -f "$temp"
    printf '%sFalha ao gerar kubeconfig consolidado.%s\n' "$KM_RED" "$KM_RESET"
    return 1
  fi

  context_count="$(kubectl config view --kubeconfig="$temp" -o json 2>/dev/null | jq '.contexts | length')"
  if [ -z "$context_count" ] || [ "$context_count" -eq 0 ]; then
    rm -f "$temp"
    printf '%sConfig gerado não possui contexts. Abortado.%s\n' "$KM_RED" "$KM_RESET"
    return 1
  fi

  chmod 600 "$temp"
  mv "$temp" "$KM_MAIN_CONFIG"
  chmod 600 "$KM_MAIN_CONFIG" 2>/dev/null || true

  if [ -n "$old_context" ] && kubectl config get-contexts --kubeconfig="$KM_MAIN_CONFIG" -o name 2>/dev/null | grep -Fxq "$old_context"; then
    kubectl config use-context --kubeconfig="$KM_MAIN_CONFIG" "$old_context" >/dev/null 2>&1 || true
  fi

  _km_source_files | while IFS= read -r source; do
    [ -n "$source" ] || continue
    identity="$(_km_identity_from_file "$source" 2>/dev/null)" || continue
    hash="$(_km_file_hash "$source")"
    _km_state_set "$identity" "$hash" "$source"
  done

  printf '%sSync concluído.%s Contexts no config principal: %s\n' "$KM_GREEN" "$KM_RESET" "$context_count"
  [ -n "$old_context" ] && printf 'Contexto anterior preservado quando disponível: %s\n' "$old_context"
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

  if [ "$rc" -eq 0 ] && printf '%s\n' "$lower" | grep -q 'yes'; then
    printf 'ONLINE|auth ok\n'
  elif printf '%s\n' "$lower" | grep -Eq '(^|[[:space:]])no($|[[:space:]])|forbidden'; then
    printf 'LIMITED|autenticado, mas sem permissão para essa verificação\n'
  elif printf '%s\n' "$lower" | grep -Eq 'unauthorized|must be logged in|token.*expired|expired.*token|invalid.*token'; then
    printf 'AUTH|credencial expirada ou inválida\n'
  elif printf '%s\n' "$lower" | grep -Eq 'x509|certificate.*expired|certificate signed by unknown'; then
    printf 'TLS|erro de certificado/TLS\n'
  elif printf '%s\n' "$lower" | grep -Eq 'timeout|timed out|connection refused|no route to host|dial tcp|i/o timeout|context deadline exceeded|network is unreachable'; then
    printf 'OFFLINE|API server indisponível ou sem rota\n'
  else
    printf 'ERROR|%s\n' "$(printf '%s' "$output" | head -n1)"
  fi
}

_km_status() {
  local ctx result km_status detail
  if [ ! -f "$KM_MAIN_CONFIG" ]; then
    printf '%s~/.kube/config ainda não existe. Rode km sync.%s\n' "$KM_YELLOW" "$KM_RESET"
    return 1
  fi

  printf '%-10s %-40s %s\n' 'STATUS' 'CONTEXTO' 'DETALHE'
  printf '%s\n' '------------------------------------------------------------------------------------------'
  kubectl config get-contexts --kubeconfig="$KM_MAIN_CONFIG" -o name 2>/dev/null | while IFS= read -r ctx; do
    [ -n "$ctx" ] || continue
    result="$(_km_validate_context_machine "$ctx")"
    km_status="${result%%|*}"
    detail="${result#*|}"
    printf '%-10s %-40s %s\n' "$km_status" "$ctx" "$detail"
  done
}

_km_select_context() {
  local contexts choice

  contexts="$(kubectl config get-contexts \
    --kubeconfig="$KM_MAIN_CONFIG" \
    -o name 2>/dev/null)"

  [ -n "$contexts" ] || return 1

  if command -v fzf >/dev/null 2>&1; then
    printf '%s\n' "$contexts" | fzf \
      --prompt='Kubernetes context > ' \
      --height='~40%' \
      --layout=reverse \
      --border \
      --no-multi \
      --cycle \
      --header='↑/↓ navega • Enter seleciona • Esc cancela'

    return $?
  fi

  printf '%s\n' "$contexts" |
    awk '{printf " %2d) %s\n", NR, $0}' >&2

  printf 'Escolha: ' >&2
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
  [ -n "$ctx" ] || ctx="$(_km_select_context)" || return 1

  if ! kubectl config get-contexts --kubeconfig="$KM_MAIN_CONFIG" -o name | grep -Fxq "$ctx"; then
    printf '%sContexto não encontrado:%s %s\n' "$KM_RED" "$KM_RESET" "$ctx"
    return 1
  fi

  server="$(_km_context_server "$ctx")"
  printf '\nContexto: %s\nServer:   %s\n\n' "$ctx" "$server"
  printf 'Tornar este o current-context? [s/N]: '
  IFS= read -r answer
  case "$answer" in
    s|S|sim|SIM|y|Y|yes|YES) kubectl config use-context --kubeconfig="$KM_MAIN_CONFIG" "$ctx" ;;
    *) printf 'Cancelado.\n' ;;
  esac
}

_km_validate() {
  local ctx="$1" result km_status detail
  if [ -z "$ctx" ]; then
    _km_status
    return $?
  fi

  result="$(_km_validate_context_machine "$ctx")"
  km_status="${result%%|*}"
  detail="${result#*|}"
  printf 'Contexto: %s\nStatus:   %s\nDetalhe:  %s\nServer:   %s\n' "$ctx" "$km_status" "$detail" "$(_km_context_server "$ctx")"

  if [ "$km_status" = 'ONLINE' ] || [ "$km_status" = 'LIMITED' ]; then
    printf '\ncluster-info:\n'
    kubectl --kubeconfig="$KM_MAIN_CONFIG" --context="$ctx" --request-timeout=5s cluster-info 2>&1
  fi
}

_km_is_prod_context() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | grep -Eq '(^|[-_.])(prod|prd|production)([-_.]|$)'
}

_km_k9s() {
  local ctx="$1" result km_status detail server answer mode
  command -v k9s >/dev/null 2>&1 || {
    printf '%sk9s não está instalado.%s\n' "$KM_RED" "$KM_RESET"
    return 1
  }

  [ -n "$ctx" ] || ctx="$(_km_select_context)" || return 1
  result="$(_km_validate_context_machine "$ctx")"
  km_status="${result%%|*}"
  detail="${result#*|}"
  server="$(_km_context_server "$ctx")"

  printf '\n%sContexto selecionado%s\n' "$KM_BOLD" "$KM_RESET"
  printf 'Context: %s\nServer:  %s\nStatus:  %s - %s\n\n' "$ctx" "$server" "$km_status" "$detail"

  case "$km_status" in AUTH|TLS|OFFLINE|ERROR)
    printf '%sO K9s não será aberto enquanto a conexão estiver inválida.%s\n' "$KM_RED" "$KM_RESET"
    return 1
  esac

  if _km_is_prod_context "$ctx"; then
    printf '%sAMBIENTE IDENTIFICADO COMO PRODUÇÃO%s\n' "$KM_YELLOW" "$KM_RESET"
    printf ' [1] Abrir K9s READ-ONLY (recomendado)\n'
    printf ' [2] Abrir K9s normal\n'
    printf ' [0] Cancelar\nEscolha [1]: '
    IFS= read -r mode
    [ -n "$mode" ] || mode=1
    case "$mode" in
      1) k9s --kubeconfig "$KM_MAIN_CONFIG" --context "$ctx" --readonly ;;
      2)
        printf 'Confirme novamente o contexto [%s]. Digite SIM para continuar: ' "$ctx"
        IFS= read -r answer
        [ "$answer" = 'SIM' ] && k9s --kubeconfig "$KM_MAIN_CONFIG" --context "$ctx" || printf 'Cancelado.\n'
        ;;
      *) printf 'Cancelado.\n' ;;
    esac
  else
    printf 'Abrir K9s neste contexto? [s/N]: '
    IFS= read -r answer
    case "$answer" in s|S|sim|SIM|y|Y|yes|YES) k9s --kubeconfig "$KM_MAIN_CONFIG" --context "$ctx" ;; *) printf 'Cancelado.\n' ;; esac
  fi
}

_km_backups() {
  ls -lt "$KM_BACKUPS_DIR" 2>/dev/null || true
}

_km_restore() {
  local files selected choice current_backup
  files="$(find "$KM_BACKUPS_DIR" -type f -name 'config-*.yaml' -print | sort -r)"
  [ -n "$files" ] || {
    printf 'Nenhum backup de config encontrado.\n'
    return 1
  }

  if command -v fzf >/dev/null 2>&1; then
    selected="$(printf '%s\n' "$files" | fzf --prompt='Backup > ')" || return 1
  else
    printf '%s\n' "$files" | awk '{printf " %2d) %s\n", NR, $0}'
    printf 'Escolha: '
    IFS= read -r choice
    selected="$(printf '%s\n' "$files" | sed -n "${choice}p")"
  fi

  [ -n "$selected" ] || return 1
  current_backup="$(_km_backup_main_config)" || return 1
  [ -n "$current_backup" ] && printf 'Backup do estado atual: %s\n' "$current_backup"
  cp "$selected" "$KM_MAIN_CONFIG" || return 1
  chmod 600 "$KM_MAIN_CONFIG" 2>/dev/null || true
  printf '%sRestaurado:%s %s\n' "$KM_GREEN" "$KM_RESET" "$selected"
}

_km_help() {
  local topic="$1"
  case "$topic" in
    sync)
      cat <<'HELP'
km sync

Reconstrói ~/.kube/config usando todos os kubeconfigs em:
  ~/.kube/configs-plugin-km/

Antes de substituir o config principal:
  - valida colisões de context/cluster/user
  - cria backup em backups-plugin-km
  - faz merge + flatten
  - tenta preservar o current-context anterior
HELP
      ;;
    import)
      cat <<'HELP'
km import <arquivo>

Importa um kubeconfig para configs-plugin-km.

Regras:
  - mesma identidade + mesma hash: DUPLICATE, não importa
  - mesma identidade + hash diferente: UPDATE, oferece substituir
  - mesmo API server + identidade diferente: pergunta se substitui ou mantém separado
  - cluster novo: cria um novo arquivo usando o nome do contexto
HELP
      ;;
    downloads)
      cat <<'HELP'
km downloads
km downloads import

Procura kubeconfigs válidos em ~/Downloads e classifica:
  NEW          cluster/contexto ainda não importado
  DUPLICATE    arquivo idêntico a um já importado
  UPDATE       mesmo cluster/contexto, mas credencial/conteúdo mudou
  SAME_SERVER  mesmo API server, porém contexto/namespace diferente

Use "km downloads import" para perguntar arquivo por arquivo se deseja importar.
HELP
      ;;
    k9s)
      cat <<'HELP'
km k9s [context]

Valida e exibe explicitamente o contexto antes de abrir o K9s.
Contextos com nome prod/prd/production oferecem READ-ONLY como padrão.
HELP
      ;;
    *)
      cat <<'HELP'
Kubernetes Config Manager (km)

Uso:
  km                         menu interativo
  km help [comando]          ajuda geral ou específica
  km sources                 lista kubeconfigs em configs-plugin-km
  km scan                    alias de sources
  km downloads               verifica kubeconfigs em ~/Downloads
  km downloads import        importa/atualiza Downloads interativamente
  km import <arquivo>        importa um kubeconfig específico
  km sync                    reconstrói ~/.kube/config
  km contexts                lista contexts do config principal
  km current                 mostra current-context
  km use [context]           seleciona e confirma um current-context
  km status                  valida todos os contexts
  km validate [context]      valida um ou todos os contexts
  km k9s [context]           valida/confirma e abre K9s
  km backups                 lista backups
  km restore                 restaura backup interativamente

Diretórios:
  ~/.kube/configs-plugin-km/   fontes dos kubeconfigs
  ~/.kube/backups-plugin-km/   backups do plugin
  ~/.kube/state-plugin-km/     hashes/metadados de importação
  ~/.kube/config               config consolidado usado pelo kubectl/K9s

Ajuda específica:
  km help import
  km help downloads
  km help sync
  km help k9s
HELP
      ;;
  esac
}

_km_pause() {
  printf '\nPressione ENTER para continuar...'
  IFS= read -r _km_dummy
}

_km_menu_numeric() {
  local option file
  while true; do
    clear
    printf '%sKubernetes Config Manager%s\n\n' "$KM_BOLD" "$KM_RESET"
    printf 'Current context: %s\n' "$(kubectl config current-context --kubeconfig="$KM_MAIN_CONFIG" 2>/dev/null || printf '-')"
    printf 'Sources:         %s\n\n' "$KM_CONFIGS_DIR"
    cat <<'MENU'
  1) Status/validar todos os clusters
  2) Ver kubeconfigs em Downloads
  3) Importar kubeconfig específico
  4) Sincronizar configs -> ~/.kube/config
  5) Listar contexts
  6) Trocar current-context
  7) Validar um contexto
  8) Abrir K9s
  9) Listar fontes
 10) Backups
 11) Restaurar backup
  h) Help
  0) Sair
MENU
    printf '\nEscolha: '
    IFS= read -r option

    case "$option" in
      1) _km_status; _km_pause ;;
      2)
        _km_downloads
        printf '\nDeseja entrar no modo de importação dos Downloads? [s/N]: '
        IFS= read -r option
        case "$option" in s|S|sim|SIM|y|Y|yes|YES) _km_downloads import ;; esac
        _km_pause
        ;;
      3)
        printf 'Caminho do kubeconfig: '
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
      h|H|help) _km_help; _km_pause ;;
      0|q|Q) return 0 ;;
      *) printf 'Opção inválida.\n'; sleep 1 ;;
    esac
  done
}

_km_menu() {
  local selected action file answer context

  # Sem fzf, mantém compatibilidade com o menu numérico.
  if ! command -v fzf >/dev/null 2>&1; then
    _km_menu_numeric
    return $?
  fi

  while true; do
    clear
    printf '%sKubernetes Config Manager%s\n\n' "$KM_BOLD" "$KM_RESET"
    printf 'Current context: %s\n' "$(kubectl config current-context --kubeconfig="$KM_MAIN_CONFIG" 2>/dev/null || printf '-')"
    printf 'Sources:         %s\n\n' "$KM_CONFIGS_DIR"

    selected="$(cat <<'MENU' | fzf \
      --prompt='Ação > ' \
      --height='~70%' \
      --layout=reverse \
      --border \
      --no-multi \
      --cycle \
      --header='↑/↓ navega • Enter seleciona • Esc cancela'
01  Status/validar todos os clusters
02  Ver kubeconfigs em Downloads
03  Importar kubeconfig específico
04  Sincronizar configs -> ~/.kube/config
05  Listar contexts
06  Trocar current-context
07  Validar um contexto
08  Abrir K9s
09  Listar fontes
10  Backups
11  Restaurar backup
H   Help
0   Sair
MENU
    )" || return 0

    action="${selected%% *}"

    case "$action" in
      01) _km_status; _km_pause ;;
      02)
        _km_downloads
        printf '\nDeseja entrar no modo de importação dos Downloads? [s/N]: '
        IFS= read -r answer
        case "$answer" in s|S|sim|SIM|y|Y|yes|YES) _km_downloads import ;; esac
        _km_pause
        ;;
      03)
        printf 'Caminho do kubeconfig: '
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
      H|h) _km_help; _km_pause ;;
      0) return 0 ;;
    esac
  done
}

kube-manager() {
  _km_ensure_dirs
  _km_require || return 1

  local command="${1:-menu}"
  [ "$#" -gt 0 ] && shift

  case "$command" in
    menu) _km_menu ;;
    help|-h|--help) _km_help "$1" ;;
    sources|scan) _km_sources ;;
    downloads) _km_downloads "$1" ;;
    import)
      [ -n "$1" ] || { printf 'Uso: km import <arquivo>\n'; return 1; }
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
    *)
      printf 'Comando desconhecido: %s\n\n' "$command"
      _km_help
      return 1
      ;;
  esac
}
