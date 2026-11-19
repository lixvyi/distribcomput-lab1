#!/bin/bash
set -e
source ~/.bash_profile
outdir=/var/lab-logs/shots
mkdir -p "$outdir"

{
  echo '[hadoop@namenode ~]$ for host in namenode datanode1 datanode2; do ssh -o BatchMode=yes "$host" "hostname && whoami"; done'
  for host in namenode datanode1 datanode2; do
    ssh -n -o BatchMode=yes "$host" 'hostname && whoami'
  done
} > "$outdir/02-ssh.txt" 2>&1

{
  echo '[hadoop@namenode ~]$ jps'
  jps
  echo '[hadoop@namenode ~]$ ssh datanode1 jps'
  ssh -n datanode1 jps
  echo '[hadoop@namenode ~]$ ssh datanode2 jps'
  ssh -n datanode2 jps
} > "$outdir/03-jps.txt" 2>&1

{
  echo '[hadoop@namenode ~]$ hdfs dfsadmin -report'
  hdfs dfsadmin -report
} > "$outdir/04-hdfs-report.txt" 2>&1

{
  echo '[hadoop@namenode ~]$ yarn node -list -all'
  yarn node -list -all
} > "$outdir/05-yarn-nodes.txt" 2>&1

{
  echo '[hadoop@namenode ~]$ hdfs dfs -ls /user/hadoop/input'
  hdfs dfs -ls /user/hadoop/input
  echo '[hadoop@namenode ~]$ hdfs dfs -cat /user/hadoop/input/words.txt'
  hdfs dfs -cat /user/hadoop/input/words.txt
  echo '[hadoop@namenode ~]$ hdfs dfs -cat /user/hadoop/output-wordcount/part-r-00000'
  hdfs dfs -cat /user/hadoop/output-wordcount/part-r-00000
} > "$outdir/06-hdfs-files.txt" 2>&1

for host in namenode datanode1 datanode2; do
  ssh -n "$host" "hostname; echo; uname -m; echo; cat /etc/os-release; echo; ip -4 addr; echo; java -version; echo; /opt/hadoop/current/bin/hadoop version" > "$outdir/01-env-$host.txt" 2>&1
done
echo COLLECT_OK
