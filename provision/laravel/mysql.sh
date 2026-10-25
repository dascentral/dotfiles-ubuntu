#!/usr/bin/env bash
set -euo pipefail

section "MySQL 8.4 LTS"
if command -v mysql >/dev/null 2>&1; then
  ok "MySQL already installed: $(mysql --version)"
  if [[ ! -f "$MYSQL_PASS_FILE" ]]; then
    warn "No ${MYSQL_PASS_FILE}. If root still uses auth_socket, set its password manually."
  fi
else
  if [[ -z "${MYSQL_ROOT_PASSWORD:-}" ]]; then
    MYSQL_ROOT_PASSWORD="$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-28)"
  fi

  sudo -E apt-get install -y -qq mysql-server

  # Ubuntu's package leaves root on auth_socket; switch it to the generated password.
  SQL_PASSWORD="${MYSQL_ROOT_PASSWORD//\\/\\\\}"
  SQL_PASSWORD="${SQL_PASSWORD//\'/\'\'}"
  sudo mysql <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY '${SQL_PASSWORD}';
SQL

  # Written only after the ALTER succeeds, so the file never holds a
  # password that was not applied.
  (umask 077 && printf '%s\n' "$MYSQL_ROOT_PASSWORD" > "$MYSQL_PASS_FILE")
  ok "MySQL root password set and written to $MYSQL_PASS_FILE"

  sudo systemctl enable --now mysql >/dev/null
  ok "MySQL $(mysql --version | awk '{print $3}') running"
fi

section "MySQL tuning"
TOTAL_MEM_MB=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo)
if   (( TOTAL_MEM_MB >= 7168 )); then BUFFER_POOL_MB=$((TOTAL_MEM_MB * 40 / 100))
elif (( TOTAL_MEM_MB >= 3584 )); then BUFFER_POOL_MB=$((TOTAL_MEM_MB * 35 / 100))
elif (( TOTAL_MEM_MB >= 1792 )); then BUFFER_POOL_MB=512
else                                   BUFFER_POOL_MB=256
fi
sudo tee /etc/mysql/conf.d/99-tuning.cnf >/dev/null <<EOF
# Provisioned tuning. Detected ${TOTAL_MEM_MB}MB total RAM.
[mysqld]
innodb_buffer_pool_size = ${BUFFER_POOL_MB}M
EOF
sudo systemctl restart mysql
ok "innodb_buffer_pool_size set to ${BUFFER_POOL_MB}M (host has ${TOTAL_MEM_MB}MB RAM)"
