#!/bin/bash
# Run as root on namenode. Follows the lab manual sections 4.4 through 8.2.
set -eo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

echo "===== 4.1 identity ====="
cat /etc/os-release
uname -m
ip -4 addr
ip route
getent hosts namenode datanode1 datanode2
ping -c 2 namenode
ping -c 2 datanode1
ping -c 2 datanode2

echo "===== 4.2 java ====="
java -version
readlink -f "$(command -v java)"

install -d -o hadoop -g hadoop /opt/hadoop /data/hadoop/tmp /data/hadoop/dfs/name /data/hadoop/dfs/data
for host in datanode1 datanode2; do
  ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new "root@${host}" \
    "install -d -o hadoop -g hadoop /opt/hadoop /data/hadoop/tmp /data/hadoop/dfs/name /data/hadoop/dfs/data"
done

echo "===== 4.4 SSH keys for hadoop ====="
sudo -iu hadoop bash <<'EOS'
set -e
mkdir -p ~/.ssh
chmod 700 ~/.ssh
if [ ! -f ~/.ssh/id_ed25519 ]; then
  ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519
fi
# Equivalent result of ssh-copy-id from namenode to the three cluster users.
# ssh-copy-id itself prompts for the hadoop password; the pubkey is installed directly.
cat > ~/.ssh/authorized_keys <<EOF
$(cat ~/.ssh/id_ed25519.pub)
EOF
chmod 600 ~/.ssh/authorized_keys
EOS

PUB=$(cat /home/hadoop/.ssh/id_ed25519.pub)
for host in datanode1 datanode2; do
  ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new "root@${host}" "bash -s" <<EOS
set -e
install -d -o hadoop -g hadoop -m 700 /home/hadoop/.ssh
grep -qxF '${PUB}' /home/hadoop/.ssh/authorized_keys 2>/dev/null || echo '${PUB}' >> /home/hadoop/.ssh/authorized_keys
chown hadoop:hadoop /home/hadoop/.ssh/authorized_keys
chmod 600 /home/hadoop/.ssh/authorized_keys
EOS
done

sudo -iu hadoop bash <<'EOS'
set -e
for host in namenode datanode1 datanode2; do
  ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$host" 'hostname && whoami'
done
EOS

echo "===== 5.1 Hadoop package ====="
cd /tmp
if [ -f /opt/cache/hadoop-3.5.0.tar.gz ]; then
  cp -f /opt/cache/hadoop-3.5.0.tar.gz /tmp/hadoop-3.5.0.tar.gz
  cp -f /opt/cache/hadoop-3.5.0.tar.gz.sha512 /tmp/hadoop-3.5.0.tar.gz.sha512
else
  wget -O /tmp/hadoop-3.5.0.tar.gz https://downloads.apache.org/hadoop/common/hadoop-3.5.0/hadoop-3.5.0.tar.gz
  wget -O /tmp/hadoop-3.5.0.tar.gz.sha512 https://downloads.apache.org/hadoop/common/hadoop-3.5.0/hadoop-3.5.0.tar.gz.sha512
fi
echo "----- sha512sum -----"
sha512sum /tmp/hadoop-3.5.0.tar.gz
echo "----- official .sha512 -----"
cat /tmp/hadoop-3.5.0.tar.gz.sha512
# Compare the digest only. The official file is a BSD-style line, not a raw hash.
want=$(awk '{print $NF}' /tmp/hadoop-3.5.0.tar.gz.sha512 | tr 'A-F' 'a-f')
got=$(sha512sum /tmp/hadoop-3.5.0.tar.gz | awk '{print $1}')
if [ "$want" != "$got" ]; then
  echo "SHA-512 mismatch" >&2
  exit 1
fi
echo "SHA-512 OK"

rm -rf /opt/hadoop/hadoop-3.5.0
tar -xzf /tmp/hadoop-3.5.0.tar.gz -C /opt/hadoop
ln -sfn /opt/hadoop/hadoop-3.5.0 /opt/hadoop/current
chown -R hadoop:hadoop /opt/hadoop
ls /opt/hadoop/current/bin/hadoop

echo "===== 5.2 environment ====="
sudo -iu hadoop bash <<'EOS'
set -e
touch ~/.bash_profile
sed -i '/# BEGIN HADOOP LAB/,/# END HADOOP LAB/d' ~/.bash_profile
cat >> ~/.bash_profile <<'EOF'
# BEGIN HADOOP LAB
export JAVA_HOME=$(dirname "$(dirname "$(readlink -f /usr/bin/java)")")
export HADOOP_HOME=/opt/hadoop/current
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
export PATH=$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH
# END HADOOP LAB
EOF
source ~/.bash_profile
echo "JAVA_HOME=$JAVA_HOME"
java -version
"$HADOOP_HOME/bin/hadoop" version
sed -i '/# BEGIN HADOOP LAB/,/# END HADOOP LAB/d' "$HADOOP_HOME/etc/hadoop/hadoop-env.sh"
{
  echo '# BEGIN HADOOP LAB'
  printf 'export JAVA_HOME=%s\n' "$JAVA_HOME"
  echo 'export HADOOP_OPTS="${HADOOP_OPTS:-} -Djava.net.preferIPv4Stack=true"'
  echo '# END HADOOP LAB'
} >> "$HADOOP_HOME/etc/hadoop/hadoop-env.sh"
EOS

echo "===== 5.3 site xml ====="
sudo -iu hadoop bash <<'EOS'
set -e
source ~/.bash_profile
cat > "$HADOOP_HOME/etc/hadoop/core-site.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
<property><name>fs.defaultFS</name><value>hdfs://namenode:8020</value></property>
<property><name>hadoop.tmp.dir</name><value>/data/hadoop/tmp</value></property>
</configuration>
EOF
cat > "$HADOOP_HOME/etc/hadoop/hdfs-site.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
<property><name>dfs.replication</name><value>2</value></property>
<property><name>dfs.namenode.name.dir</name><value>file:///data/hadoop/dfs/name</value></property>
<property><name>dfs.datanode.data.dir</name><value>file:///data/hadoop/dfs/data</value></property>
<property><name>dfs.namenode.http-address</name><value>namenode:9870</value></property>
</configuration>
EOF
cat > "$HADOOP_HOME/etc/hadoop/mapred-site.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
<property><name>mapreduce.framework.name</name><value>yarn</value></property>
<property><name>mapreduce.application.classpath</name>
<value>$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/*:$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/lib/*</value></property>
<property><name>mapreduce.map.memory.mb</name><value>512</value></property>
<property><name>mapreduce.reduce.memory.mb</name><value>512</value></property>
<property><name>mapreduce.map.java.opts</name><value>-Xmx384m</value></property>
<property><name>mapreduce.reduce.java.opts</name><value>-Xmx384m</value></property>
<property><name>yarn.app.mapreduce.am.resource.mb</name><value>512</value></property>
<property><name>yarn.app.mapreduce.am.command-opts</name><value>-Xmx384m</value></property>
</configuration>
EOF
cat > "$HADOOP_HOME/etc/hadoop/yarn-site.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
<property><name>yarn.resourcemanager.hostname</name><value>namenode</value></property>
<property><name>yarn.nodemanager.aux-services</name><value>mapreduce_shuffle</value></property>
<property><name>yarn.nodemanager.env-whitelist</name>
<value>JAVA_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_CONF_DIR,CLASSPATH_PREPEND_DISTCACHE,HADOOP_YARN_HOME,HADOOP_HOME,PATH,LANG,TZ,HADOOP_MAPRED_HOME</value></property>
<property><name>yarn.nodemanager.resource.memory-mb</name><value>2048</value></property>
<property><name>yarn.scheduler.minimum-allocation-mb</name><value>256</value></property>
<property><name>yarn.scheduler.maximum-allocation-mb</name><value>2048</value></property>
<property><name>yarn.nodemanager.resource.cpu-vcores</name><value>2</value></property>
</configuration>
EOF
cat > "$HADOOP_HOME/etc/hadoop/workers" <<'EOF'
datanode1
datanode2
EOF
EOS

echo "===== 5.4 sync to workers ====="
sudo -iu hadoop bash <<'EOS'
set -e
source ~/.bash_profile
for host in datanode1 datanode2; do
  rsync -az /opt/hadoop/hadoop-3.5.0/ "$host":/opt/hadoop/hadoop-3.5.0/
  ssh "$host" "ln -sfn /opt/hadoop/hadoop-3.5.0 /opt/hadoop/current"
  scp ~/.bash_profile "$host":~/.bash_profile
done
for host in namenode datanode1 datanode2; do
  ssh "$host" '/usr/bin/java -version; /opt/hadoop/current/bin/hadoop version | head -n 1'
done
EOS

echo "===== 7.1 format namenode (once) ====="
sudo -iu hadoop bash <<'EOS'
set -e
source ~/.bash_profile
if [ -f /data/hadoop/dfs/name/current/VERSION ]; then
  echo "NameNode already formatted; skip"
else
  hdfs namenode -format
fi
EOS

echo "===== 7.2 start ====="
sudo -iu hadoop bash <<'EOS'
set -e
source ~/.bash_profile
start-dfs.sh
start-yarn.sh
mapred --daemon start historyserver
sleep 8
echo "----- jps namenode -----"
jps
echo "----- jps datanode1 -----"
ssh datanode1 jps
echo "----- jps datanode2 -----"
ssh datanode2 jps
echo "----- dfsadmin -----"
hdfs dfsadmin -report
echo "----- yarn nodes -----"
yarn node -list -all
EOS

echo "SETUP_DONE"
