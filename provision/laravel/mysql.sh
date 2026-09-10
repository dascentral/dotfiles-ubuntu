#!/usr/bin/env bash
set -euo pipefail

section "MySQL 8.4 LTS"
if command -v mysql >/dev/null 2>&1; then
  ok "MySQL already installed: $(mysql --version)"
else
  if [[ -z "${MYSQL_ROOT_PASSWORD:-}" ]]; then
    MYSQL_ROOT_PASSWORD="$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-28)"
  fi

  umask 077
  printf '%s\n' "$MYSQL_ROOT_PASSWORD" > "$MYSQL_PASS_FILE"
  ok "MySQL root password written to $MYSQL_PASS_FILE"

  MYSQL_APT_DEB="mysql-apt-config_${MYSQL_APT_CONFIG_VERSION}_all.deb"
  curl -fsSL "https://repo.mysql.com/${MYSQL_APT_DEB}" -o "/tmp/${MYSQL_APT_DEB}"

  echo "mysql-apt-config mysql-apt-config/select-server select mysql-8.4-lts" | sudo debconf-set-selections
  echo "mysql-apt-config mysql-apt-config/select-tools select Enabled" | sudo debconf-set-selections
  echo "mysql-apt-config mysql-apt-config/select-product select Ok" | sudo debconf-set-selections
  sudo -E dpkg -i "/tmp/${MYSQL_APT_DEB}"
  rm -f "/tmp/${MYSQL_APT_DEB}"

  sudo apt-get update -qq

  echo "mysql-community-server mysql-community-server/root-pass password ${MYSQL_ROOT_PASSWORD}" | sudo debconf-set-selections
  echo "mysql-community-server mysql-community-server/re-root-pass password ${MYSQL_ROOT_PASSWORD}" | sudo debconf-set-selections
  echo "mysql-server mysql-server/default-auth-override select Use Strong Password Encryption (RECOMMENDED)" | sudo debconf-set-selections

  sudo -E apt-get install -y -qq mysql-server
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
