#!/bin/bash
set -e
sudo -iu hadoop bash -s <<'EOS'
set -e
source ~/.bash_profile
start-dfs.sh
start-yarn.sh
mapred --daemon start historyserver
sleep 8
echo '--- jps nn ---'
jps
echo '--- jps dn1 ---'
ssh datanode1 jps
echo '--- jps dn2 ---'
ssh datanode2 jps
hdfs dfsadmin -safemode wait
echo '--- report head ---'
hdfs dfsadmin -report
echo '--- yarn ---'
yarn node -list -all
echo '--- wc ---'
hdfs dfs -cat /user/hadoop/output-wordcount/part-r-00000
EOS
echo START_OK
