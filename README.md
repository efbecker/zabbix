# zabbix

## Zabbix Proxy 8.0 (SQLite) em Debian 13

```bash
curl -fsSL https://raw.githubusercontent.com/efbecker/zabbix/main/proxy/install-proxy.sh \
  | bash -s -- --hostname zbx8prx2 --server 172.16.10.11
```

Opções: `--identity ID` (padrão = hostname), `--profile small|large`, `--rotate-psk`,
`--raw-base URL`, `--dry-run` (só imprime o conf gerado).

O script é idempotente: pode rodar de novo para reaplicar o template. A PSK em
`/etc/zabbix/zabbix_proxy.psk` só é recriada com `--rotate-psk`, e o conf anterior
ganha backup `.bak.<data>` quando muda.

No fim ele imprime nome, identidade e PSK para cadastrar em
**Administração → Proxies** (modo Ativo, "Conexões do proxy" = PSK).

Regra do template: nunca coloque comentário na mesma linha de um valor
(`StartODBCPollers=1  # ...` quebra o Zabbix). O script recusa o conf se achar isso.
