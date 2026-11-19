#!/bin/bash
# Sections 8.1-8.3, then start the cluster again without formatting.
set -eo pipefail
sudo -iu hadoop bash <<'EOS'
set -e
source ~/.bash_profile
echo "===== wait safemode ====="
hdfs dfsadmin -safemode wait
echo "===== 8.1 hdfs ====="
hdfs dfs -mkdir -p /user/hadoop/input
printf 'hadoop yarn hdfs\nhadoop mapreduce hadoop\n' > ~/words.txt
hdfs dfs -put -f ~/words.txt /user/hadoop/input/
hdfs dfs -ls /user/hadoop/input
hdfs dfs -cat /user/hadoop/input/words.txt
hdfs dfs -get -f /user/hadoop/input/words.txt ~/words_copy.txt
diff ~/words.txt ~/words_copy.txt && echo "DIFF_OK"
echo "===== 8.2 wordcount ====="
hdfs dfs -rm -r -f /user/hadoop/output-wordcount
hadoop jar "$HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.5.0.jar" \
  wordcount /user/hadoop/input /user/hadoop/output-wordcount
echo "===== wordcount output ====="
hdfs dfs -cat /user/hadoop/output-wordcount/part-r-00000
echo "===== yarn apps ====="
yarn application -list -appStates ALL
EOS

echo "===== 8.3 stop ====="
sudo -iu hadoop bash <<'EOS'
set -e
source ~/.bash_profile
mapred --daemon stop historyserver
stop-yarn.sh
stop-dfs.sh
EOS

sleep 5
echo "===== restart without format ====="
sudo -iu hadoop bash <<'EOS'
set -e
source ~/.bash_profile
start-dfs.sh
start-yarn.sh
mapred --daemon start historyserver
sleep 8
hdfs dfsadmin -safemode wait
echo "----- report after restart -----"
hdfs dfsadmin -report
echo "----- yarn after restart -----"
yarn node -list -all
echo "----- wordcount still on hdfs -----"
hdfs dfs -cat /user/hadoop/output-wordcount/part-r-00000
echo "----- jps -----"
jps
ssh datanode1 jps
ssh datanode2 jps
EOS
echo "VERIFY_DONE"
