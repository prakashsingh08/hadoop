# 🔧 Manual Debugging Guide - NameNode Connection Issues

## Current Problem
```
✗ Cannot connect to NameNode
```

This means the NameNode container is running, but services can't reach it on port 8020.

---

## Step 1: Verify NameNode Container is Running

```bash
# Check if NameNode container exists and is running
docker compose ps namenode

# Expected output:
# NAME                 IMAGE                                           STATUS
# hadoop-namenode      bde2020/hadoop-namenode:2.0.0-...              Up 2 minutes

# If NOT running, check why:
docker compose logs namenode | tail -50
```

---

## Step 2: Check NameNode Startup Logs

```bash
# Get detailed startup logs
docker compose logs namenode

# Look for these SUCCESS patterns:
# - "Block Pool ID = "
# - "registered with NameNode"
# - "safe mode OFF"
# - "NameNode up at" or "Name Node started"

# Look for these ERROR patterns:
docker compose logs namenode | grep -i "error\|exception\|failed"

# If you see errors, check:
docker compose logs namenode | grep -E "ERROR|FATAL|Exception"
```

---

## Step 3: Check if NameNode is Listening on Port 8020

```bash
# Check which ports NameNode is actually listening on
docker exec hadoop-namenode netstat -tuln | grep LISTEN

# Should show something like:
# tcp6       0      0 :::8020                 :::*                    LISTEN
# tcp6       0      0 :::9870                 :::*                    LISTEN

# If port 8020 is NOT showing, NameNode didn't start properly
```

---

## Step 4: Test NameNode Connectivity from CLI Container

```bash
# Verify hadoop-cli is running
docker compose ps hadoop-cli

# Try to reach NameNode from CLI container
docker exec hadoop-cli bash -c 'echo > /dev/tcp/namenode/8020'

# If this works:
# - No output = SUCCESS ✓

# If this fails (hangs or times out):
# - NameNode is not listening on port 8020
# - Need to check NameNode logs (Step 2)
```

---

## Step 5: Check Docker Network

```bash
# Verify hadoop network exists
docker network ls | grep hadoop

# Should show:
# hadoop          bridge

# If missing, create it:
docker network create hadoop

# Verify containers are on the network
docker network inspect hadoop | grep -A 5 "Containers"

# Should list all containers including:
# - hadoop-namenode
# - hadoop-cli
# - etc.
```

---

## Step 6: Test NameNode RPC Protocol

```bash
# Try to get NameNode version (basic connectivity test)
docker exec hadoop-cli hadoop version

# Should show Hadoop version info

# Try to contact NameNode directly
docker exec hadoop-cli hdfs dfsadmin -report

# If this shows output: NameNode is working
# If this times out: NameNode is not responding
```

---

## Step 7: Check NameNode Java Process

```bash
# Check if Java process is running inside NameNode
docker exec hadoop-namenode jps

# Should show:
# 1 NameNode
# ... other processes

# If no NameNode process, it crashed during startup
docker exec hadoop-namenode ps aux | grep java
```

---

## Step 8: Check NameNode Configuration

```bash
# View actual NameNode configuration
docker exec hadoop-namenode cat /etc/hadoop/conf/core-site.xml | grep -A 2 "fs.defaultFS"

# Should show:
# <value>hdfs://namenode:8020</value>

# Check hdfs-site.xml
docker exec hadoop-namenode cat /etc/hadoop/conf/hdfs-site.xml | grep -A 2 "dfs.replication"
```

---

## Step 9: Check NameNode Data Directory

```bash
# Check if data directory exists and has correct permissions
docker exec hadoop-namenode ls -la /hadoop/dfs/

# Check if namenode subdirectory exists
docker exec hadoop-namenode ls -la /hadoop/dfs/namenode/

# If directory is empty or missing, NameNode may not have initialized
docker exec hadoop-namenode du -sh /hadoop/dfs/namenode/
```

---

## Step 10: Manual NameNode Restart

```bash
# Stop NameNode gracefully
docker compose stop namenode

# Wait 5 seconds
sleep 5

# Check logs to see what happened
docker compose logs namenode | tail -30

# Remove the container but keep data
docker compose rm namenode

# Restart it
docker compose up -d namenode

# Wait 20 seconds
sleep 20

# Check startup logs
docker compose logs namenode | tail -50

# Test connectivity
docker exec hadoop-cli hdfs dfsadmin -report
```

---

## Step 11: Check for Port Conflicts

```bash
# Check if port 8020 is used by something else
lsof -i :8020

# If something else is using it:
# Option 1: Kill it
kill -9 <PID>

# Option 2: Change NameNode port in docker-compose.yaml
# Change: "8020:8020" to "8021:8020"
# Then restart
```

---

## Step 12: Full Diagnostic Test Sequence

Run these commands in order and note the output:

```bash
echo "=== 1. Check containers ==="
docker compose ps namenode hadoop-cli

echo -e "\n=== 2. Check NameNode listening ports ==="
docker exec hadoop-namenode netstat -tuln | grep -E "8020|9870"

echo -e "\n=== 3. Check NameNode Java process ==="
docker exec hadoop-namenode jps

echo -e "\n=== 4. Test TCP connectivity ==="
docker exec hadoop-cli timeout 3 bash -c 'echo > /dev/tcp/namenode/8020' && echo "✓ Port 8020 is open" || echo "✗ Port 8020 is closed"

echo -e "\n=== 5. Test HDFS report ==="
docker exec hadoop-cli hdfs dfsadmin -report 2>&1 | head -20

echo -e "\n=== 6. Check network ==="
docker network inspect hadoop | grep "hadoop-namenode" -A 2

echo -e "\n=== 7. Check NameNode logs (last 30 lines) ==="
docker compose logs namenode | tail -30
```

---

## Step 13: Common Issues & Quick Fixes

### Issue: "Connection timed out"

```bash
# Problem: NameNode is not listening on port 8020

# Fix 1: Wait longer for NameNode to initialize
docker compose stop namenode
docker compose rm namenode
docker compose up -d namenode
sleep 45  # Wait 45 seconds instead of 20
docker exec hadoop-cli hdfs dfsadmin -report

# Fix 2: Check if port is in use
lsof -i :8020
# If something else is using it, kill it or change ports

# Fix 3: Check NameNode logs for errors
docker compose logs namenode | grep -i "error\|exception"
```

### Issue: "Cannot open connection to NameNode"

```bash
# Problem: NameNode started but not fully initialized

# Solution: Check safe mode
docker exec hadoop-cli hdfs dfsadmin -safemode get

# If in safe mode:
# Option 1: Wait for it to exit safe mode (can take 30+ seconds)
# Option 2: Force exit safe mode (not recommended for production)
docker exec hadoop-cli hdfs dfsadmin -safemode leave
```

### Issue: "Block Pool ID not initialized"

```bash
# Problem: NameNode data directory corrupted

# Solution: Reformat NameNode (WARNING: DELETES DATA)
docker compose stop namenode
docker exec hadoop-namenode hdfs namenode -format -force
docker compose start namenode
sleep 20
docker compose logs namenode | grep "Block Pool"
```

---

## Step 14: Collect Debug Information

If manual steps don't work, run this to collect diagnostic info:

```bash
#!/bin/bash

echo "╔════════════════════════════════════════════╗"
echo "║     NAMENODE DEBUG INFORMATION             ║"
echo "╚════════════════════════════════════════════╝"

echo ""
echo "=== Container Status ==="
docker compose ps namenode hadoop-cli

echo ""
echo "=== NameNode Listening Ports ==="
docker exec hadoop-namenode netstat -tuln 2>/dev/null | grep -E "8020|9870" || echo "netstat not available"

echo ""
echo "=== NameNode Java Process ==="
docker exec hadoop-namenode jps

echo ""
echo "=== TCP Connectivity Test ==="
docker exec hadoop-cli timeout 3 bash -c 'echo > /dev/tcp/namenode/8020' 2>&1 && echo "✓ Connected" || echo "✗ Not connected"

echo ""
echo "=== Network Config ==="
docker network inspect hadoop | grep -E "Name|Containers" -A 10

echo ""
echo "=== NameNode Configuration ==="
docker exec hadoop-namenode cat /etc/hadoop/conf/core-site.xml 2>/dev/null | grep -A 2 "fs.defaultFS" || echo "Config not found"

echo ""
echo "=== NameNode Data Directory ==="
docker exec hadoop-namenode ls -la /hadoop/dfs/namenode/ 2>/dev/null || echo "Directory not found"

echo ""
echo "=== NameNode Logs (Last 100 lines) ==="
docker compose logs namenode 2>/dev/null | tail -100

echo ""
echo "=== HDFS Report ==="
docker exec hadoop-cli hdfs dfsadmin -report 2>&1

echo ""
echo "Done. Save this output for troubleshooting."

```

Save as `debug-namenode.sh`:

```bash
chmod +x debug-namenode.sh
./debug-namenode.sh > namenode-debug.txt 2>&1
cat namenode-debug.txt
```

---

## Step 15: Last Resort - Complete Reset

If nothing works, try a complete reset:

```bash
# STOP EVERYTHING
docker compose down -v

# CLEAN UP
rm -rf ./data/*
docker system prune -a --volumes -f

# WAIT
sleep 30

# CREATE FRESH DATA DIRS
mkdir -p data/hdfs/{namenode,datanode1,datanode2,historyserver}
mkdir -p data/metastore-postgres
chmod -R 755 ./data

# RESTART DOCKER DESKTOP (important!)
# Quit Docker → Wait 30 seconds → Reopen Docker

# START FRESH
docker compose up -d zookeeper
sleep 45

docker compose up -d namenode
sleep 30

# TEST
docker exec hadoop-cli hdfs dfsadmin -report
```

---

## Debugging Checklist

- [ ] NameNode container is running (`docker compose ps namenode` shows "Up")
- [ ] Port 8020 is open (`docker exec hadoop-namenode netstat | grep 8020`)
- [ ] Java process exists (`docker exec hadoop-namenode jps | grep NameNode`)
- [ ] Data directory exists (`docker exec hadoop-namenode ls /hadoop/dfs/namenode/`)
- [ ] Network is correct (`docker network inspect hadoop | grep namenode`)
- [ ] No port conflicts (`lsof -i :8020` shows nothing or only Docker)
- [ ] Logs show no errors (`docker compose logs namenode | grep -i error`)
- [ ] Can reach from CLI (`docker exec hadoop-cli timeout 3 bash -c 'echo > /dev/tcp/namenode/8020'`)
- [ ] HDFS report works (`docker exec hadoop-cli hdfs dfsadmin -report`)
- [ ] Safe mode is off (`docker exec hadoop-cli hdfs dfsadmin -safemode get`)

---

## Next Steps

Once NameNode is working:

1. Run validation: `./scripts/validate-cluster.sh`
2. Start remaining services: `./scripts/start-cluster.sh`
3. Check dashboards: http://localhost:9870

**Share the output from `debug-namenode.sh` if you need further help!**
