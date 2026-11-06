#!/usr/bin/env bash
# Instalador idempotente do Zabbix Proxy 8.0 (SQLite) para Debian 13.
#
# Uso:
#   curl -fsSL <RAW_BASE>/proxy/install-proxy.sh | bash -s -- --hostname zbx8prx2 --server 172.16.10.11
#
# Opcoes:
#   --hostname NOME      Hostname do proxy (igual ao frontend, case-sensitive). Obrigatorio.
#   --server ENDERECO    Zabbix server (HA: "ip1;ip2"). Padrao: 172.16.10.11
#   --identity ID        TLSPSKIdentity. Padrao: o hostname
#   --profile P          small (padrao) | large (~1000 hosts / 600 NVPS)
#   --rotate-psk         Gera uma PSK nova mesmo se ja existir (exige atualizar o frontend)
#   --raw-base URL       Base raw do repositorio para baixar o template
#   --dry-run            So imprime o zabbix_proxy.conf gerado; nao instala nada
#   -h | --help          Ajuda
set -euo pipefail

ZBX_VERSION="8.0"
RAW_BASE="${RAW_BASE:-https://raw.githubusercontent.com/efbecker/zabbix/main}"
TEMPLATE_PATH="proxy/templates/zabbix_proxy.conf.tpl"

CONF_FILE="/etc/zabbix/zabbix_proxy.conf"
PSK_FILE="/etc/zabbix/zabbix_proxy.psk"
DATA_DIR="/var/lib/zabbix"
SNMPTRAP_DIR="/var/log/snmptrap"

HOSTNAME_ARG=""
SERVER="172.16.10.11"
IDENTITY=""
PROFILE="small"
ROTATE_PSK=0
DRY_RUN=0

log()  { printf '\033[1;34m[zbx-proxy]\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33m[zbx-proxy] AVISO:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[zbx-proxy] ERRO:\033[0m %s\n' "$*" >&2; exit 1; }

usage() { sed -n '2,17p' "${BASH_SOURCE[0]:-/dev/null}" 2>/dev/null | sed 's/^# \{0,1\}//' || true; exit 0; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hostname)   HOSTNAME_ARG="${2:-}"; shift 2 ;;
    --server)     SERVER="${2:-}"; shift 2 ;;
    --identity)   IDENTITY="${2:-}"; shift 2 ;;
    --profile)    PROFILE="${2:-}"; shift 2 ;;
    --rotate-psk) ROTATE_PSK=1; shift ;;
    --raw-base)   RAW_BASE="${2:-}"; shift 2 ;;
    --dry-run)    DRY_RUN=1; shift ;;
    -h|--help)    usage ;;
    *) die "opcao desconhecida: $1 (use --help)" ;;
  esac
done

# ---------- validacao ----------
[[ -n "$HOSTNAME_ARG" ]] || die "--hostname e obrigatorio"
[[ "$HOSTNAME_ARG" =~ ^[A-Za-z0-9._-]+$ ]] || die "hostname invalido: use apenas letras, numeros, . _ -"
[[ -n "$SERVER" && "$SERVER" =~ ^[A-Za-z0-9.:\;,_-]+$ ]] || die "--server invalido: $SERVER"
IDENTITY="${IDENTITY:-$HOSTNAME_ARG}"
[[ "$IDENTITY" =~ ^[A-Za-z0-9._-]+$ ]] || die "identity invalida: $IDENTITY"

# ---------- perfis ----------
case "$PROFILE" in
  small)
    PROXY_MEMORY_BUFFER_SIZE=64M
    START_POLLERS=5;  START_POLLERS_UNREACHABLE=2; START_AGENT_POLLERS=1
    START_SNMP_POLLERS=1; START_HTTP_AGENT_POLLERS=1
    START_PREPROCESSORS=4; START_TRAPPERS=5; START_PINGERS=3
    START_DISCOVERERS=2; START_HTTP_POLLERS=2
    CACHE_SIZE=256M; HISTORY_CACHE_SIZE=64M; HISTORY_INDEX_CACHE_SIZE=16M
    START_DB_SYNCERS=2
    ;;
  large)
    PROXY_MEMORY_BUFFER_SIZE=256M
    START_POLLERS=20; START_POLLERS_UNREACHABLE=5; START_AGENT_POLLERS=3
    START_SNMP_POLLERS=3; START_HTTP_AGENT_POLLERS=3
    START_PREPROCESSORS=8; START_TRAPPERS=10; START_PINGERS=10
    START_DISCOVERERS=5; START_HTTP_POLLERS=5
    CACHE_SIZE=512M; HISTORY_CACHE_SIZE=256M; HISTORY_INDEX_CACHE_SIZE=64M
    START_DB_SYNCERS=4
    ;;
  *) die "--profile deve ser small ou large" ;;
esac

# ---------- template ----------
get_template() {
  local here=""
  if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  fi
  if [[ -n "$here" && -f "$here/templates/zabbix_proxy.conf.tpl" ]]; then
    cat "$here/templates/zabbix_proxy.conf.tpl"
  else
    command -v curl >/dev/null 2>&1 || die "curl nao encontrado"
    curl -fsSL "${RAW_BASE%/}/${TEMPLATE_PATH}" || die "falha ao baixar template de ${RAW_BASE%/}/${TEMPLATE_PATH}"
  fi
}

render() {
  local fping6_line
  if [[ -x /usr/bin/fping6 ]]; then
    fping6_line="Fping6Location=/usr/bin/fping6"
  else
    # fping >= 4 trata IPv4 e IPv6 no mesmo binario; sem fping6 deixamos comentado
    fping6_line="#Fping6Location=/usr/bin/fping6"
  fi
  get_template | sed \
    -e "s|{{GENERATED_AT}}|$(date -u +%Y-%m-%dT%H:%M:%SZ)|g" \
    -e "s|{{PROFILE}}|${PROFILE}|g" \
    -e "s|{{SERVER}}|${SERVER}|g" \
    -e "s|{{HOSTNAME}}|${HOSTNAME_ARG}|g" \
    -e "s|{{PSK_IDENTITY}}|${IDENTITY}|g" \
    -e "s|{{FPING6_LINE}}|${fping6_line}|g" \
    -e "s|{{PROXY_MEMORY_BUFFER_SIZE}}|${PROXY_MEMORY_BUFFER_SIZE}|g" \
    -e "s|{{START_POLLERS}}|${START_POLLERS}|g" \
    -e "s|{{START_POLLERS_UNREACHABLE}}|${START_POLLERS_UNREACHABLE}|g" \
    -e "s|{{START_AGENT_POLLERS}}|${START_AGENT_POLLERS}|g" \
    -e "s|{{START_SNMP_POLLERS}}|${START_SNMP_POLLERS}|g" \
    -e "s|{{START_HTTP_AGENT_POLLERS}}|${START_HTTP_AGENT_POLLERS}|g" \
    -e "s|{{START_PREPROCESSORS}}|${START_PREPROCESSORS}|g" \
    -e "s|{{START_TRAPPERS}}|${START_TRAPPERS}|g" \
    -e "s|{{START_PINGERS}}|${START_PINGERS}|g" \
    -e "s|{{START_DISCOVERERS}}|${START_DISCOVERERS}|g" \
    -e "s|{{START_HTTP_POLLERS}}|${START_HTTP_POLLERS}|g" \
    -e "s|{{CACHE_SIZE}}|${CACHE_SIZE}|g" \
    -e "s|{{HISTORY_CACHE_SIZE}}|${HISTORY_CACHE_SIZE}|g" \
    -e "s|{{HISTORY_INDEX_CACHE_SIZE}}|${HISTORY_INDEX_CACHE_SIZE}|g" \
    -e "s|{{START_DB_SYNCERS}}|${START_DB_SYNCERS}|g"
}

check_rendered() {
  local f="$1"
  if grep -q '{{' "$f"; then
    die "placeholders nao substituidos no conf: $(grep -o '{{[A-Z0-9_]*}}' "$f" | sort -u | tr '\n' ' ')"
  fi
  # Zabbix nao aceita comentario na mesma linha do valor (ex.: StartODBCPollers=1  # ...)
  if grep -nE '^[[:space:]]*[A-Za-z0-9]+=.*#' "$f" >/dev/null; then
    die "comentario inline encontrado no conf: $(grep -nE '^[[:space:]]*[A-Za-z0-9]+=.*#' "$f" | head -1)"
  fi
}

if [[ "$DRY_RUN" -eq 1 ]]; then
  tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
  render > "$tmp"; check_rendered "$tmp"; cat "$tmp"
  exit 0
fi

# ---------- pre-requisitos ----------
[[ "$(id -u)" -eq 0 ]] || die "rode como root (sudo -i ou | sudo bash -s -- ...)"
# shellcheck disable=SC1091
. /etc/os-release
[[ "${ID:-}" == "debian" && "${VERSION_ID:-}" == "13" ]] || die "suportado apenas Debian 13 (detectado: ${PRETTY_NAME:-desconhecido})"

export DEBIAN_FRONTEND=noninteractive

# ---------- repositorio Zabbix ----------
if dpkg-query -W -f='${Status} ${Version}\n' zabbix-release 2>/dev/null | grep -q "install ok installed .*${ZBX_VERSION}"; then
  log "repositorio zabbix-release ${ZBX_VERSION} ja instalado"
else
  log "instalando repositorio zabbix-release ${ZBX_VERSION} (debian13)"
  apt-get update -qq
  apt-get install -y -qq curl ca-certificates openssl >/dev/null
  deb="$(mktemp --suffix=.deb)"
  curl -fsSL -o "$deb" "https://repo.zabbix.com/zabbix/${ZBX_VERSION}/release/debian/pool/main/z/zabbix-release/zabbix-release_latest_${ZBX_VERSION}+debian13_all.deb"
  dpkg -i "$deb" >/dev/null
  rm -f "$deb"
fi

# ---------- pacotes ----------
log "instalando zabbix-proxy-sqlite3 e fping"
apt-get update -qq
apt-get install -y -qq zabbix-proxy-sqlite3 fping openssl >/dev/null

# ---------- diretorios ----------
install -d -o zabbix -g zabbix -m 750 "$DATA_DIR"
install -d -m 755 "$SNMPTRAP_DIR"
[[ -f "$SNMPTRAP_DIR/snmptrap.log" ]] || install -m 644 /dev/null "$SNMPTRAP_DIR/snmptrap.log"

# ---------- PSK ----------
PSK_CREATED=0
if [[ -s "$PSK_FILE" && "$ROTATE_PSK" -eq 0 ]]; then
  log "PSK existente mantida em $PSK_FILE"
else
  [[ -s "$PSK_FILE" ]] && cp -a "$PSK_FILE" "${PSK_FILE}.bak.$(date +%Y%m%d%H%M%S)"
  log "gerando PSK nova em $PSK_FILE"
  ( umask 077; openssl rand -hex 32 > "$PSK_FILE" )
  PSK_CREATED=1
fi
chown zabbix:zabbix "$PSK_FILE"
chmod 640 "$PSK_FILE"

# ---------- zabbix_proxy.conf ----------
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
render > "$tmp"
check_rendered "$tmp"

if [[ -f "$CONF_FILE" ]] && cmp -s <(grep -v '^# Gerado por' "$tmp") <(grep -v '^# Gerado por' "$CONF_FILE"); then
  log "zabbix_proxy.conf sem mudancas"
else
  if [[ -f "$CONF_FILE" ]]; then
    bak="${CONF_FILE}.bak.$(date +%Y%m%d%H%M%S)"
    cp -a "$CONF_FILE" "$bak"
    log "backup do conf anterior: $bak"
  fi
  install -o root -g zabbix -m 640 "$tmp" "$CONF_FILE"
  log "zabbix_proxy.conf gerado (perfil $PROFILE)"
fi

# ---------- servico ----------
log "habilitando e reiniciando zabbix-proxy"
systemctl enable zabbix-proxy >/dev/null 2>&1
systemctl restart zabbix-proxy
sleep 3
if ! systemctl is-active --quiet zabbix-proxy; then
  journalctl -u zabbix-proxy -n 30 --no-pager >&2 || true
  tail -n 30 /var/log/zabbix/zabbix_proxy.log >&2 || true
  die "zabbix-proxy nao subiu; veja o log acima"
fi

# ---------- resumo ----------
cat <<EOF

=====================================================================
 Zabbix Proxy ${ZBX_VERSION} instalado e ativo (perfil: ${PROFILE})
---------------------------------------------------------------------
 Cadastre no frontend: Administracao -> Proxies -> Criar proxy
   Nome do proxy ....... ${HOSTNAME_ARG}
   Modo do proxy ....... Ativo
   Criptografia:
     Conexoes do proxy . PSK
     Identidade PSK .... ${IDENTITY}
     PSK ............... $(cat "$PSK_FILE")
---------------------------------------------------------------------
 Server: ${SERVER}   Log: /var/log/zabbix/zabbix_proxy.log
EOF
if [[ "$PSK_CREATED" -eq 0 ]]; then
  echo " (PSK reaproveitada; nao precisa alterar o frontend se ja estava cadastrado)"
fi
if [[ "$PROFILE" == "large" ]]; then
  echo " Perfil large em SQLite: acompanhe a fila; acima de ~600 NVPS considere PostgreSQL."
fi
echo "====================================================================="
