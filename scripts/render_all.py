from pathlib import Path
import sys

sys.path.insert(0, r"D:\distribcomput1\scripts")
from render_terminal import render

shots = Path(r"D:\distribcomput1\logs\shots")
out = Path(r"D:\distribcomput1\screenshots")
out.mkdir(exist_ok=True)


def prompted_env(host: str, text: str) -> str:
    parts = [p.strip("\n") for p in text.strip().split("\n\n")]
    labels = [
        "hostname",
        "uname -m",
        "cat /etc/os-release",
        "ip -4 addr",
        "java -version",
        "hadoop version",
    ]
    lines = []
    for label, part in zip(labels, parts):
        lines.append(f"[hadoop@{host} ~]$ {label}")
        lines.append(part)
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


for host in ("namenode", "datanode1", "datanode2"):
    body = prompted_env(host, (shots / f"01-env-{host}.txt").read_text(encoding="utf-8", errors="replace"))
    render(f"hadoop@{host}  hostname / ip / java / hadoop", body, out / f"01-env-{host}.png", 92)

render("namenode  SSH BatchMode", (shots / "02-ssh.txt").read_text(encoding="utf-8"), out / "02-ssh.png", 92)
render("namenode  jps", (shots / "03-jps.txt").read_text(encoding="utf-8"), out / "03-jps.png", 72)
render("namenode  hdfs dfsadmin -report", (shots / "04-hdfs-report.txt").read_text(encoding="utf-8"), out / "04-hdfs-report.png", 78)
render("namenode  yarn node -list -all", (shots / "05-yarn-nodes.txt").read_text(encoding="utf-8"), out / "05-yarn-nodes.png", 100)
files = (shots / "06-hdfs-files.txt").read_text(encoding="utf-8").expandtabs(4)
render("namenode  HDFS files and WordCount output", files, out / "06-hdfs-files.png", 92)

wc = """[hadoop@namenode ~]$ hadoop jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.5.0.jar wordcount /user/hadoop/input /user/hadoop/output-wordcount
2026-11-19 06:40:15,788 INFO impl.YarnClientImpl: Submitted application application_1795070336780_0001
2026-11-19 06:40:25,019 INFO mapreduce.Job:  map 0% reduce 0%
2026-11-19 06:40:33,199 INFO mapreduce.Job:  map 100% reduce 0%
2026-11-19 06:40:39,249 INFO mapreduce.Job:  map 100% reduce 100%
2026-11-19 06:40:39,263 INFO mapreduce.Job: Job job_1795070336780_0001 completed successfully
[hadoop@namenode ~]$ hdfs dfs -cat /user/hadoop/output-wordcount/part-r-00000
hadoop       3
hdfs         1
mapreduce    1
yarn         1
"""
render("namenode  WordCount on YARN", wc, out / "06-wordcount.png", 108)
print("rendered")
