#!/bin/bash
set -eu

# Docker writes 127.0.0.1 <hostname> into /etc/hosts. Hadoop must resolve
# cluster names to the lab subnet, otherwise DataNodes register as localhost.
tmp=$(mktemp)
awk '
  $1=="127.0.0.1" { print "127.0.0.1 localhost"; next }
  $2=="namenode" || $2=="datanode1" || $2=="datanode2" { next }
  { print }
' /etc/hosts > "$tmp"
cat >> "$tmp" <<'EOF'
192.168.56.11 namenode
192.168.56.12 datanode1
192.168.56.13 datanode2
EOF
cat "$tmp" > /etc/hosts
rm -f "$tmp"

# nss-myhostname would answer the machine's own hostname with ::1.
sed -i 's/[[:space:]]myhostname//' /etc/nsswitch.conf
ssh-keygen -A >/dev/null 2>&1 || true
mkdir -p /var/run/sshd
/usr/sbin/sshd

# PID 1 must reap exited daemons, otherwise stop-*.sh leaves jps zombies.
trap 'exit 0' TERM INT
while true; do
  if ! wait -n 2>/dev/null; then
    sleep 1
  fi
done
