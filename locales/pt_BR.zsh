# Portuguese (Brazil) translations for kube-manager.

typeset -gA KM_I18N_PT_BR=(
  error_prefix "ERRO"
  warning_prefix "ATENÇÃO"
  missing_dependency "dependência ausente: %s"
  file_not_found "Arquivo não encontrado: %s"
  invalid_kubeconfig "Arquivo não parece ser um kubeconfig válido: %s"
  duplicate_identical "já importado e conteúdo idêntico."
  registered_source "Origem cadastrada: %s"
  update_changed "mesmo cluster/contexto, conteúdo diferente."
  current_file "Atual: %s"
  new_file "Novo:  %s"
  replace_existing_question "Substituir o kubeconfig existente? [s/N]: "
  cancelled "Cancelado."
  updated "Atualizado: %s"
  same_server_warning "já existe um kubeconfig apontando para o mesmo API server:"
  existing_file "Existente: %s"
  new_file_aligned "Novo:      %s"
  same_server_explanation "Pode ser uma credencial renovada OU outro contexto/namespace no mesmo cluster."
  replace_existing_option "[1] Substituir o existente"
  import_separate_option "[2] Importar como contexto separado"
  cancel_option "[0] Cancelar"
  choose_prompt "Escolha: "
  choose_default_prompt "Escolha [1]: "
  imported "Importado: %s"
  header_status "STATUS"
  header_file "ARQUIVO"
  header_context "CONTEXTO"
  header_detail "DETALHE"
  import_update_question "Importar/atualizar este arquivo? [s/N]: "
  duplicate_word "duplicado"
  collisions_found "Colisões encontradas entre kubeconfigs:"
  no_kubeconfigs "Nenhum kubeconfig encontrado em %s"
  validating_collisions "Validando colisões..."
  sync_cancelled_collisions "Sync cancelado. Na V1 o plugin não sobrescreve nomes duplicados silenciosamente."
  backup_label "Backup: %s"
  consolidate_failed "Falha ao gerar kubeconfig consolidado."
  generated_no_contexts "Config gerado não possui contexts. Abortado."
  sync_complete "Sync concluído. Contexts no config principal: %s"
  previous_context_preserved "Contexto anterior preservado quando disponível: %s"
  auth_ok "auth ok"
  limited_detail "autenticado, mas sem permissão para essa verificação"
  auth_detail "credencial expirada ou inválida"
  tls_detail "erro de certificado/TLS"
  offline_detail "API server indisponível ou sem rota"
  config_missing "~/.kube/config ainda não existe. Rode km sync."
  select_context_prompt "Kubernetes context > "
  nav_hint "↑/↓ navega • Enter seleciona • Esc cancela"
  context_not_found "Contexto não encontrado: %s"
  context_label "Contexto"
  server_label "Server"
  status_label "Status"
  detail_label "Detalhe"
  set_current_question "Tornar este o current-context? [s/N]: "
  cluster_info_label "cluster-info:"
  k9s_not_installed "k9s não está instalado."
  selected_context "Contexto selecionado"
  k9s_invalid_connection "O K9s não será aberto enquanto a conexão estiver inválida."
  production_detected "AMBIENTE IDENTIFICADO COMO PRODUÇÃO"
  k9s_readonly_option "[1] Abrir K9s READ-ONLY (recomendado)"
  k9s_normal_option "[2] Abrir K9s normal"
  confirm_prod_context "Confirme novamente o contexto [%s]. Digite SIM para continuar: "
  confirm_prod_word "SIM"
  open_k9s_question "Abrir K9s neste contexto? [s/N]: "
  no_backups "Nenhum backup de config encontrado."
  backup_prompt "Backup > "
  current_backup "Backup do estado atual: %s"
  restored "Restaurado: %s"
  pause "Pressione ENTER para continuar..."
  current_context "Contexto atual"
  sources "Fontes"
  action_prompt "Ação > "
  menu_status "Status/validar todos os clusters"
  menu_downloads "Ver kubeconfigs em Downloads"
  menu_import "Importar kubeconfig específico"
  menu_sync "Sincronizar configs -> ~/.kube/config"
  menu_contexts "Listar contextos"
  menu_use "Trocar current-context"
  menu_validate "Validar um contexto"
  menu_k9s "Abrir K9s"
  menu_sources "Listar fontes"
  menu_backups "Backups"
  menu_restore "Restaurar backup"
  menu_language "Idioma"
  menu_help "Ajuda"
  menu_exit "Sair"
  downloads_import_question "Deseja entrar no modo de importação dos Downloads? [s/N]: "
  kubeconfig_path "Caminho do kubeconfig: "
  invalid_option "Opção inválida."
  import_usage "Uso: km import <arquivo>"
  unknown_command "Comando desconhecido: %s"
  language_title "Selecione o idioma"
  language_prompt "Idioma > "
  language_changed "Idioma alterado para %s."
  invalid_language "Idioma inválido: %s. Use pt_BR ou en_US."
)

_km_help_pt_BR() {
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
    lang|language)
      cat <<'HELP'
km lang
km lang pt_BR
km lang en_US

Seleciona o idioma da interface e do help.
A preferência é salva em:
  ~/.kube/state-plugin-km/settings.conf
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
  km lang [pt_BR|en_US]      seleciona o idioma

Diretórios:
  ~/.kube/configs-plugin-km/   fontes dos kubeconfigs
  ~/.kube/backups-plugin-km/   backups do plugin
  ~/.kube/state-plugin-km/     hashes, metadados e preferências
  ~/.kube/config               config consolidado usado pelo kubectl/K9s

Ajuda específica:
  km help import
  km help downloads
  km help sync
  km help k9s
  km help lang
HELP
      ;;
  esac
}
