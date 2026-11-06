# Gerado por install-proxy.sh em {{GENERATED_AT}} (perfil: {{PROFILE}})
# NAO edite valores com comentario na mesma linha: o Zabbix rejeita.

############# GLOBAL #############
# 0 = ativo (proxy conecta no server) | 1 = passivo
ProxyMode=0
# Zabbix 8 server. Para nos de um cluster HA, separe com ";"
Server={{SERVER}}
# Nome EXATO do proxy no frontend (case-sensitive)
Hostname={{HOSTNAME}}
ListenPort=10051

LogFile=/var/log/zabbix/zabbix_proxy.log
LogFileSize=100
PidFile=/run/zabbix/zabbix_proxy.pid
SocketDir=/run/zabbix
LogRemoteCommands=0

############# BANCO (SQLite) #############
DBName=/var/lib/zabbix/zabbix_proxy.db

############# BUFFER #############
ProxyOfflineBuffer=48
ProxyBufferMode=hybrid
ProxyMemoryBufferSize={{PROXY_MEMORY_BUFFER_SIZE}}
ProxyMemoryBufferAge=3600
ProxyConfigFrequency=30
DataSenderFrequency=1

############# PROCESSOS #############
StartPollers={{START_POLLERS}}
StartPollersUnreachable={{START_POLLERS_UNREACHABLE}}
StartAgentPollers={{START_AGENT_POLLERS}}
StartSNMPPollers={{START_SNMP_POLLERS}}
StartHTTPAgentPollers={{START_HTTP_AGENT_POLLERS}}
MaxConcurrentChecksPerPoller=1000
StartPreprocessors={{START_PREPROCESSORS}}
StartTrappers={{START_TRAPPERS}}
StartPingers={{START_PINGERS}}
StartDiscoverers={{START_DISCOVERERS}}
StartHTTPPollers={{START_HTTP_POLLERS}}
# Oracle-OLVM aparece nos hosts; habilite (ex.: 1) apenas se usar ODBC
#StartODBCPollers=1
StartJavaPollers=0
StartIPMIPollers=0

# SNMP Trapper
StartSNMPTrapper=1
SNMPTrapperFile=/var/log/snmptrap/snmptrap.log

############# VMWARE #############
# Esse proxy nao monitora vCenter: desligado
StartVMwareCollectors=0

############# CACHES / DB #############
CacheSize={{CACHE_SIZE}}
HistoryCacheSize={{HISTORY_CACHE_SIZE}}
HistoryIndexCacheSize={{HISTORY_INDEX_CACHE_SIZE}}
StartDBSyncers={{START_DB_SYNCERS}}

############# TEMPOS / ESTATISTICAS #############
Timeout=10
LogSlowQueries=3000
StatsAllowedIP=127.0.0.1

############# ICMP (fping) #############
FpingLocation=/usr/bin/fping
{{FPING6_LINE}}

############# CRIPTOGRAFIA (PSK) #############
TLSConnect=psk
TLSAccept=unencrypted,psk
TLSPSKIdentity={{PSK_IDENTITY}}
TLSPSKFile=/etc/zabbix/zabbix_proxy.psk

############# INCLUDES #############
#Include=/etc/zabbix/zabbix_proxy.d/*.conf
