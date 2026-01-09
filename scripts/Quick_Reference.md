# Hadoop & Hive Cluster - Quick Reference Card

Print this for quick access to common commands and cluster information.

---

## 🚀 Quick Start (One-Liner)

```bash
./scripts/start-cluster.sh && sleep 5 && ./scripts/validate-cluster.sh
```

---

## 📊 Dashboard URLs

```
HDFS NameNode:         http://localhost:9870
HDFS DataNode1:        http://localhost:9864
HDFS DataNode2:        http://localhost:9865
YARN ResourceManager:  http://localhost:8088
YARN NodeManager:      http://localhost:8042
Job History Server:    http://localhost:8188
```

---

## 🔧 Essential Scripts

```bash
# Start cluster (takes ~2 minutes)
./scripts/start-cluster.sh

# Check health (takes ~30 seconds)
./scripts/validate-cluster.sh

# Diagnose problems
./scripts/diagnose.sh
./scripts/diagnose.sh namenode

# Stop cluster
./scripts/stop-cluster.sh
./scripts/stop-cluster.sh --full    # Full cleanup
./scripts/stop-cluster.sh --force   # Force stop
```

---

## 📁 Container Names

```
zookeeper                 # ZooKeeper coordination
hadoop-namenode           # HDFS NameNode
hadoop-datanode1          # HDFS DataNode 1
hadoop-datanode2          # HDFS DataNode 2
hadoop-resourcemanager    # YARN ResourceManager
hadoop-nodemanager1       # YARN NodeManager
hadoop-historyserver      # Job History Server
hadoop-cli                # Hadoop CLI tools
hive-metastore-db         # PostgreSQL (Hive metadata)
hive-metastore            # Hive Metastore Service
hive-server               # HiveServer2
hive-cli                  # Hive CLI
```

---

## 🔍 Common Diagnostics

```bash
# Check which containers are running
docker compose ps

# Check specific service logs
docker compose logs -f namenode

# Diagnose specific service
./scripts/diagnose.sh namenode

# Full system diagnosis
./scripts/diagnose.sh

# Check HDFS health
docker exec hadoop-cli hdfs dfsadmin -report

# List HDFS files
docker exec hadoop-cli hdfs dfs -ls /

# Check YARN status
docker exec hadoop-cli yarn cluster report

# List YARN applications
docker exec hadoop-cli yarn application -list
```

---

## 🧪 Test Commands

### Test HDFS:
```bash
# Open interactive shell
docker exec -it hadoop-cli bash

# Inside container:
hdfs dfs -mkdir /test
echo "Hello Hadoop" > /tmp/test.txt
hdfs dfs -put /tmp/test.txt /test/
hdfs dfs -cat /test/test.txt
hdfs dfsadmin -report
exit
```

### Test YARN (MapReduce):
```bash
docker exec -it hadoop-cli bash

# Inside container:
hadoop jar /opt/hadoop-3.2.1/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.2.1.jar \
  wordcount /test/test.txt /output/wordcount

hdfs dfs -cat /output/wordcount/part-r-00000
exit
```

### Test Hive (SQL):
```bash
docker exec -it hive-cli bash

# Inside container:
beeline -u "jdbc:hive2://hive-server:10000/" -n hive -p ""

# Inside Beeline:
CREATE DATABASE test_db;
USE test_db;
CREATE TABLE test (id INT, name STRING);
INSERT INTO test VALUES (1, 'Hadoop');
SELECT * FROM test;
SHOW DATABASES;
!exit
exit
```

---

## 📈 Performance Monitoring

```bash
# Watch container resource usage in real-time
docker stats --no-stream

# Check disk space
df -h

# Check data directory size
du -sh ./data

# View system memory
free -h

# Monitor with docker
docker system df
```

---

## 🛠️ Troubleshooting Flowchart

```
Cluster not starting?
├─ Run: ./scripts/validate-cluster.sh
├─ Check: docker compose ps
└─ Logs: docker compose logs -f SERVICE

HDFS issues (0 datanodes)?
├─ Run: ./scripts/diagnose.sh hdfs
├─ Check: docker exec hadoop-cli hdfs dfsadmin -report
└─ Fix: docker compose restart datanode1 datanode2

YARN issues (0 nodemanagers)?
├─ Run: ./scripts/diagnose.sh yarn
├─ Check: docker exec hadoop-cli yarn cluster report
└─ Fix: docker compose restart nodemanager1

Hive not working?
├─ Run: ./scripts/diagnose.sh hive
├─ Check: docker compose logs hive-server
└─ Fix: docker compose restart hive-metastore hive-server

Port conflicts?
├─ Find: lsof -i :9870  (or any port number)
├─ Kill: kill -9 PID
└─ Or change ports in docker-compose.yaml
```

---

## 🔐 Service Dependencies

```
ZooKeeper (required for all)
       ↓
HDFS (NameNode first, then DataNodes)
       ↓
YARN (ResourceManager, then NodeManager)
       ↓
Hive (PostgreSQL → MetaStore → HiveServer2)
```

**Start order is critical!** Always use:
```bash
./scripts/start-cluster.sh
```

---

## 🧹 Cleanup Commands

```bash
# Stop cluster, keep data
./scripts/stop-cluster.sh

# Stop and remove containers (keep data)
docker compose down

# Full cleanup (delete everything)
./scripts/stop-cluster.sh --full

# Manual cleanup
docker compose down -v
rm -rf ./data/*
```

---

## 📋 Health Check Checklist

Quick validation (run after startup):

```bash
./scripts/validate-cluster.sh
```

Manual checks:
- [ ] `docker compose ps` shows 12 containers "Up"
- [ ] NameNode UI: 2 Live DataNodes
- [ ] ResourceManager UI: 1 active NodeManager
- [ ] `hdfs dfs -ls /` works
- [ ] `yarn cluster report` shows resources
- [ ] `beeline -u "jdbc:hive2://hive-server:10000/"` connects

---

## 🎯 Port Reference

| Service | Port | Container | URL |
|---------|------|-----------|-----|
| ZooKeeper | 2181 | zookeeper | - |
| NameNode RPC | 8020 | hadoop-namenode | - |
| NameNode UI | 9870 | hadoop-namenode | http://localhost:9870 |
| DataNode1 UI | 9864 | hadoop-datanode1 | http://localhost:9864 |
| DataNode2 UI | 9865 | hadoop-datanode2 | http://localhost:9865 |
| RM IPC | 8032 | hadoop-resourcemanager | - |
| RM UI | 8088 | hadoop-resourcemanager | http://localhost:8088 |
| NM UI | 8042 | hadoop-nodemanager1 | http://localhost:8042 |
| History Server | 8188 | hadoop-historyserver | http://localhost:8188 |
| Hive Metastore | 9083 | hive-metastore | - |
| HiveServer2 | 10000 | hive-server | - |
| PostgreSQL | 5432 | hive-metastore-db | - |

---

## 🔄 Common Workflows

### First-Time Setup:
```bash
./scripts/start-cluster.sh
./scripts/validate-cluster.sh
open http://localhost:9870
```

### Daily Check:
```bash
./scripts/validate-cluster.sh
```

### Issue Investigation:
```bash
./scripts/diagnose.sh namenode    # or other service
docker compose logs -f SERVICENAME
```

### Clean Shutdown:
```bash
./scripts/stop-cluster.sh
```

### Fresh Start:
```bash
./scripts/stop-cluster.sh --full
./scripts/start-cluster.sh
```

---

## 💡 Pro Tips

1. **Always validate after startup:**
   ```bash
   ./scripts/start-cluster.sh && ./scripts/validate-cluster.sh
   ```

2. **Monitor logs in background:**
   ```bash
   docker compose logs -f > cluster.log &
   ```

3. **Quick port check:**
   ```bash
   lsof -i :9870    # Check if port is in use
   ```

4. **See all container IPs:**
   ```bash
   docker inspect hadoop-namenode | grep IPAddress
   ```

5. **Execute commands without interactive shell:**
   ```bash
   docker exec hadoop-cli hdfs dfs -ls /
   docker exec hadoop-cli yarn application -list
   ```

---

## 📞 Getting Help

```bash
# View script help
./scripts/start-cluster.sh --help
./scripts/diagnose.sh --help
./scripts/stop-cluster.sh --help

# View all logs
docker compose logs

# Check specific service logs
docker compose logs SERVICE_NAME

# Follow logs in real-time
docker compose logs -f SERVICE_NAME

# View last N lines
docker compose logs --tail=50 SERVICE_NAME

# Search in logs
docker compose logs SERVICE_NAME | grep "ERROR"
```

---

**Quick Reference Version:** 1.0  
**Last Updated:** January 2026  
**For:** Hadoop 3.2.1 + Hive 2.3.2 Cluster
