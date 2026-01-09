# Hadoop & Hive Cluster Scripts Guide

Complete collection of bash scripts for managing your Hadoop and Hive cluster deployed via Docker Compose.

---

## 📋 Available Scripts

### 1. **start-cluster.sh** - Start the entire cluster
Start all services in the correct dependency order with automatic wait times between steps.

```bash
./scripts/start-cluster.sh
```

**What it does:**
- ✓ Creates data directories if missing
- ✓ Starts services in proper order: ZooKeeper → HDFS → YARN → Hive
- ✓ Waits appropriate time between service starts
- ✓ Shows progress with visual indicators
- ✓ Displays final dashboard URLs

**Output:**
```
All services have been started successfully!

Access the cluster dashboards:
  NameNode UI:              http://localhost:9870
  ResourceManager UI:       http://localhost:8088
  DataNode1 UI:             http://localhost:9864
  DataNode2 UI:             http://localhost:9865
  NodeManager UI:           http://localhost:8042
  JobHistory UI:            http://localhost:8188
```

**Runtime:** ~2 minutes

---

### 2. **stop-cluster.sh** - Stop the cluster safely

Stop all services gracefully with optional cleanup options.

```bash
# Gracefully stop (keep all data)
./scripts/stop-cluster.sh

# Force stop containers (immediate, may lose in-flight operations)
./scripts/stop-cluster.sh --force

# Full cleanup (remove everything including data)
./scripts/stop-cluster.sh --full
```

**Options:**

| Option | Description |
|--------|-------------|
| `--force` | Kill containers immediately without graceful shutdown |
| `--full` | Remove all containers AND delete all data volumes |
| `--help` | Show help message |

**Examples:**

```bash
# Normal shutdown - containers stopped, data preserved
./scripts/stop-cluster.sh

# Quick stop - force immediate stop
./scripts/stop-cluster.sh --force

# Complete cleanup - start fresh next time
./scripts/stop-cluster.sh --full
```

**What it does:**
- ✓ Gracefully stops all containers
- ✓ Optionally removes containers
- ✓ Optionally deletes all data
- ✓ Prompts for confirmation before destructive operations
- ✓ Shows final cluster status

**Runtime:** ~30 seconds

---

### 3. **validate-cluster.sh** - Comprehensive health check

Perform 9-phase validation of your cluster including container status, network connectivity, HDFS health, YARN status, Hive functionality, and more.

```bash
./scripts/validate-cluster.sh
```

**What it does:**
- ✓ **Phase 1:** Checks all 12 containers are running
- ✓ **Phase 2:** Tests network connectivity to all services
- ✓ **Phase 3:** Verifies HDFS health (NameNode, DataNodes, capacity)
- ✓ **Phase 4:** Validates YARN cluster status (ResourceManager, NodeManagers)
- ✓ **Phase 5:** Tests Hive stack (MetaStore, HiveServer2, Beeline)
- ✓ **Phase 6:** Checks ZooKeeper status
- ✓ **Phase 7:** Verifies all web UI endpoints are accessible
- ✓ **Phase 8:** Checks disk space and resource usage
- ✓ **Phase 9:** Shows container resource consumption

**Output Example:**
```
✓ PASS: Container 'zookeeper' is running
✓ PASS: NameNode is reachable on port 8020
✓ PASS: Found 2 live DataNodes (expected: 2)
✓ PASS: HDFS file system is accessible
✓ PASS: Found 1 active NodeManager(s)
✓ PASS: PostgreSQL metastore database is accessible
✓ PASS: Beeline JDBC connection to HiveServer2 is working
⚠ WARN: Could not confirm ZooKeeper status

═══════════════════════════════════════════════
VALIDATION SUMMARY
═══════════════════════════════════════════════
Tests Passed:  32
Tests Failed:  0
Tests Warning: 2

✓ CLUSTER HEALTH: EXCELLENT
All critical services are running and healthy.
```

**Health Status Levels:**
- 🟢 **EXCELLENT** - All tests passed, cluster is healthy
- 🟡 **DEGRADED** - Some tests warning, core functions work
- 🔴 **CRITICAL** - Multiple failures, cluster not operational

**Runtime:** ~30 seconds

---

### 4. **diagnose.sh** - Detailed troubleshooting

Get detailed diagnostic information about specific services or the entire cluster.

```bash
# Full diagnosis of all services
./scripts/diagnose.sh

# Diagnose specific service
./scripts/diagnose.sh namenode
./scripts/diagnose.sh hive-server
./scripts/diagnose.sh zookeeper

# System-wide diagnostics
./scripts/diagnose.sh system

# Component diagnostics
./scripts/diagnose.sh hdfs
./scripts/diagnose.sh yarn
./scripts/diagnose.sh hive
```

**Available Services:**
```
zookeeper              - ZooKeeper coordination
namenode               - HDFS NameNode
datanode1, datanode2   - HDFS DataNodes
resourcemanager        - YARN ResourceManager
nodemanager1           - YARN NodeManager
historyserver          - Job History Server
hive-metastore-db      - PostgreSQL metastore
hive-metastore         - Hive Metastore Service
hive-server            - HiveServer2
```

**What it shows:**

For each service:
- Container status and ID
- Resource usage (CPU, memory)
- Recent errors in logs (if any)
- Last 20 log lines
- Connectivity status
- Configuration details

**Example Output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Diagnostics for: namenode
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ℹ Checking container status...
✓ Container is running
✓ Container ID: abc123def456
ℹ Resource usage:
  abc123... 245.3MiB / 8.0GiB 3.05% CPU

ℹ Checking logs for errors...
✓ No errors found in recent logs

[... detailed logs ...]
```

**Runtime:** 15-60 seconds depending on service

---

## 🚀 Quick Start Workflow

### First Time Setup:

```bash
# 1. Start the cluster
./scripts/start-cluster.sh

# 2. Wait for output, should see:
#    🎉 CLUSTER IS READY!

# 3. Validate everything is working
./scripts/validate-cluster.sh

# 4. Should see:
#    ✓ CLUSTER HEALTH: EXCELLENT

# 5. Access dashboards in your browser
open http://localhost:9870        # NameNode
open http://localhost:8088        # ResourceManager
```

### Daily Operations:

```bash
# Check cluster health
./scripts/validate-cluster.sh

# If issues, diagnose
./scripts/diagnose.sh namenode    # for specific service
./scripts/diagnose.sh              # for full diagnosis

# Stop at end of day
./scripts/stop-cluster.sh
```

### Complete Reset:

```bash
# Remove everything and start fresh
./scripts/stop-cluster.sh --full

# Start clean
./scripts/start-cluster.sh
```

---

## 📊 Script Dependencies & Sequence

```
Manual Start Sequence              Auto Start Sequence
(Step by step in docs)             (start-cluster.sh)

1. docker compose up -d zookeeper     │
   sleep 5                             │
                                       │  Automatic wait times
2. docker compose up -d namenode    ←→ Built in to script
   sleep 10                            │
                                       │
3. docker compose up -d datanode*      │
   sleep 10                            │
                                       ↓
4. ... continue with other         Done! ✓
   services
```

---

## 🔍 Validation Details

### What validate-cluster.sh checks:

**Container Status:**
- zookeeper, namenode, datanode1, datanode2
- resourcemanager, nodemanager1, historyserver
- hadoop-cli, hive-metastore-db, hive-metastore
- hive-server, hive-cli

**Network Connectivity:**
- NameNode (8020)
- DataNodes (9866)
- ResourceManager (8032)
- ZooKeeper (2181)
- Hive Metastore (9083)
- HiveServer2 (10000)
- PostgreSQL (5432)

**HDFS Health:**
- Live DataNode count (should be 2)
- Storage capacity and usage
- HDFS filesystem accessibility
- Safe mode status

**YARN Health:**
- Active NodeManager count (should be 1)
- Resource availability
- Queue status
- Application listing

**Hive Health:**
- PostgreSQL connectivity
- Hive Metastore Service status
- HiveServer2 running status
- Beeline JDBC connectivity
- Hive database operations

**System Health:**
- Disk space usage
- Container resource consumption
- ZooKeeper coordination

---

## 🐛 Troubleshooting with Scripts

### Scenario 1: Service won't start

```bash
# 1. Run full validation
./scripts/validate-cluster.sh

# 2. Diagnose failing service
./scripts/diagnose.sh namenode    # replace with actual service

# 3. Check logs
docker compose logs namenode

# 4. If reformat needed:
docker exec hadoop-namenode hdfs namenode -format -force
docker compose restart namenode
```

### Scenario 2: HDFS shows 0 DataNodes

```bash
# 1. Validate cluster
./scripts/validate-cluster.sh

# 2. Diagnose datanode issues
./scripts/diagnose.sh datanode1
./scripts/diagnose.sh datanode2

# 3. Check network connectivity
docker exec hadoop-cli ping namenode
docker exec hadoop-cli ping datanode1

# 4. Restart DataNodes
docker compose restart datanode1 datanode2

# 5. Wait and validate again
sleep 20
./scripts/validate-cluster.sh
```

### Scenario 3: Hive not working

```bash
# 1. Diagnose Hive stack
./scripts/diagnose.sh hive

# 2. Check each component
./scripts/diagnose.sh hive-metastore-db
./scripts/diagnose.sh hive-metastore
./scripts/diagnose.sh hive-server

# 3. View detailed logs
docker compose logs -f hive-server

# 4. Restart Hive services
docker compose restart hive-metastore hive-server

# 5. Validate again
./scripts/validate-cluster.sh
```

---

## 📝 Common Commands Reference

### Cluster Management:

```bash
# Start cluster automatically
./scripts/start-cluster.sh

# Validate cluster health
./scripts/validate-cluster.sh

# Diagnose issues
./scripts/diagnose.sh
./scripts/diagnose.sh namenode

# Stop cluster gracefully
./scripts/stop-cluster.sh

# Force stop
./scripts/stop-cluster.sh --force

# Full cleanup
./scripts/stop-cluster.sh --full

# View status
docker compose ps

# View logs
docker compose logs -f serviceame

# Restart service
docker compose restart serviceame
```

### Testing HDFS:

```bash
# Access Hadoop CLI
docker exec -it hadoop-cli bash

# Inside container:
hdfs dfs -ls /
hdfs dfs -mkdir /test
hdfs dfs -put /tmp/file.txt /test/
hdfs dfsadmin -report
```

### Testing Hive:

```bash
# Access Hive CLI
docker exec -it hive-cli bash

# Connect to HiveServer2
beeline -u "jdbc:hive2://hive-server:10000/" -n hive -p ""

# Inside Beeline:
SHOW DATABASES;
CREATE TABLE test (id INT);
SELECT * FROM test;
```

---

## ✅ Checklist: Everything Working

Use this checklist with the validation script:

- [ ] Run `./scripts/validate-cluster.sh`
- [ ] All 12 containers show "Up"
- [ ] Validation shows "EXCELLENT" health
- [ ] NameNode UI shows 2 Live DataNodes
- [ ] ResourceManager UI shows 1 active NodeManager
- [ ] Can list HDFS files: `docker exec hadoop-cli hdfs dfs -ls /`
- [ ] Can connect to Hive: `docker exec hive-cli beeline -u "jdbc:hive2://hive-server:10000/"`
- [ ] No errors in validation output

If all checks pass, your cluster is ready for production use! ✓

---

## 📚 Learning Path

1. **Start:** `./scripts/start-cluster.sh`
2. **Validate:** `./scripts/validate-cluster.sh`
3. **Explore:** Access web UIs at localhost:9870, localhost:8088, etc.
4. **Test HDFS:** `docker exec -it hadoop-cli bash` → `hdfs dfs -ls /`
5. **Test Hive:** `docker exec -it hive-cli bash` → Beeline
6. **Troubleshoot:** `./scripts/diagnose.sh [service]`
7. **Stop:** `./scripts/stop-cluster.sh`

---

## 🎯 Script Features Summary

| Script | Purpose | Time | Options |
|--------|---------|------|---------|
| **start-cluster.sh** | Start all services | ~2 min | None |
| **stop-cluster.sh** | Stop services | ~30 sec | --force, --full |
| **validate-cluster.sh** | Health check | ~30 sec | None |
| **diagnose.sh** | Troubleshooting | ~15-60 sec | [SERVICE] |

---

## 💡 Tips & Best Practices

1. **Always validate after startup:**
   ```bash
   ./scripts/start-cluster.sh && ./scripts/validate-cluster.sh
   ```

2. **Graceful shutdown:**
   ```bash
   ./scripts/stop-cluster.sh    # NOT --force unless necessary
   ```

3. **Regular health checks:**
   ```bash
   ./scripts/validate-cluster.sh  # Run daily/weekly
   ```

4. **Specific service issues:**
   ```bash
   ./scripts/diagnose.sh namenode  # Get detailed info
   ```

5. **Check logs for details:**
   ```bash
   docker compose logs -f servicename | head -100
   ```

---

**Scripts Version:** 1.0  
**Last Updated:** January 2026  
**Cluster Version:** Hadoop 3.2.1 + Hive 2.3.2
