# Lab 1: Complete Hadoop & Hive Cluster Setup Guide

**A beginner-friendly step-by-step guide to set up and run a production-ready Hadoop cluster with Hive SQL engine using Docker Compose.**

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Directory Structure](#directory-structure)
3. [Startup Instructions](#startup-instructions)
4. [Validation & Testing](#validation--testing)
5. [Web Dashboards](#web-dashboards)
6. [Common Commands](#common-commands)
7. [Troubleshooting](#troubleshooting)
8. [Shutdown & Cleanup](#shutdown--cleanup)

---

## Prerequisites

✅ **System Requirements:**
- Docker Desktop installed and running
- Docker Compose v1.29+
- 6+ GB RAM allocated to Docker (recommended 8GB)
- 20+ GB free disk space
- macOS, Linux, or Windows (with WSL2)

✅ **Check Docker Installation:**

```bash
docker --version
docker compose --version
docker run hello-world
```

---

## Directory Structure

### **Create Required Directories:**

Navigate to your project folder:

```bash
cd /Users/prakashtech/Documents/hdfs_poc/hadoop-hive-docker/
```

Create all required data directories:

```bash
mkdir -p ./data/hdfs/{namenode,datanode1,datanode2,historyserver}
mkdir -p ./data/metastore-postgres
mkdir -p ./workdir
```

Verify the structure:

```bash
tree -L 3 data/
# or
ls -la data/
```

**Expected Output:**

```
data/
├── hdfs/
│   ├── namenode/                    ← NameNode metadata storage
│   ├── datanode1/                   ← DataNode 1 blocks
│   ├── datanode2/                   ← DataNode 2 blocks
│   └── historyserver/               ← Job history logs
└── metastore-postgres/              ← Hive metadata database
```

---

## Startup Instructions

### ⚠️ **IMPORTANT NOTES:**

- **Follow steps IN ORDER** - services have dependencies
- **Wait the specified time** between steps - containers need time to initialize
- **Check logs** if a service fails to start
- **Run from project directory** - `cd /Users/prakashtech/Documents/hdfs_poc/hadoop-hive-docker/`

---

## 🚀 Phase 1: Coordination Service

### **Step 1: Start ZooKeeper** ⏱️ (Wait 5 seconds)

ZooKeeper provides distributed coordination for the cluster.

```bash
docker compose up -d zookeeper
sleep 5
```

**Verify ZooKeeper is running:**

```bash
docker compose ps zookeeper
```

Expected output: `zookeeper | Up X seconds`

**Check ZooKeeper logs:**

```bash
docker compose logs zookeeper | tail -15
```

Look for: `"ZooKeeperServer is now running"`

**Test ZooKeeper:**

```bash
docker exec zookeeper zkServer.sh status
# Should output: Mode: standalone
```

---

## 🚀 Phase 2: HDFS - Storage Layer

HDFS (Hadoop Distributed File System) is the storage layer of Hadoop. The NameNode manages the file system, and DataNodes store the actual data blocks.

### **Step 2: Start HDFS NameNode** ⏱️ (Wait 10 seconds)

The NameNode is the master of HDFS. It manages the file system namespace and maintains the file system tree and metadata for all files/directories.

```bash
docker compose up -d namenode
sleep 10
```

**Verify NameNode is running:**

```bash
docker compose ps namenode
```

Expected output: `hadoop-namenode | Up X seconds`

**Check NameNode initialization:**

```bash
docker compose logs namenode | tail -20
```

Look for:
- `"Block Pool ID"` 
- `"Startup progress"`
- `"started NameNode"`

**Access NameNode Web UI:**

Open in browser: **http://localhost:9870**

You should see the HDFS dashboard. It will show:
- Cluster summary
- Storage capacity
- **Live Datanodes: 0** (will update after DataNodes start)

---

### **Step 3: Start HDFS DataNodes** ⏱️ (Wait 10 seconds)

DataNodes are slave nodes that store the actual data blocks and perform block creation, deletion, and replication upon instruction from the NameNode.

```bash
docker compose up -d datanode1 datanode2
sleep 10
```

**Verify both DataNodes are running:**

```bash
docker compose ps datanode1 datanode2
```

Expected output: Both show `Up X seconds`

**Check DataNode logs:**

```bash
docker compose logs datanode1 | tail -10
docker compose logs datanode2 | tail -10
```

Look for:
- `"Block report of"`
- `"Registering "`
- `"Register DataNode"`

**Verify DataNodes connected to NameNode:**

```bash
docker exec hadoop-cli hdfs dfsadmin -report
```

Expected output:
```
Configured Capacity: ...
Present Capacity: ...
DFS Remaining: ...
DFS Used: ...

Live datanode report
...
```

**Access NameNode UI again:**

Refresh: **http://localhost:9870**

Now you should see:
- **Live Datanodes: 2** in the summary
- Both datanodes listed under "Datanodes"
- Status: "In Service"

**Access DataNode UIs:**

- **DataNode 1:** http://localhost:9864
- **DataNode 2:** http://localhost:9865

Both should show block storage information.

---

## 🚀 Phase 3: YARN - Compute Layer

YARN (Yet Another Resource Negotiator) is the resource management and job scheduling layer of Hadoop.

### **Step 4: Start YARN ResourceManager** ⏱️ (Wait 5 seconds)

The ResourceManager is the master of YARN. It manages the allocation of system resources to applications.

```bash
docker compose up -d resourcemanager
sleep 5
```

**Verify ResourceManager is running:**

```bash
docker compose ps resourcemanager
```

Expected output: `hadoop-resourcemanager | Up X seconds`

**Access ResourceManager Web UI:**

Open in browser: **http://localhost:8088**

You should see:
- Cluster metrics
- **Running Applications: 0** (initially)
- **NodeManagers: 0** (will update after NodeManager starts)

---

### **Step 5: Start YARN NodeManager** ⏱️ (Wait 5 seconds)

NodeManagers are agents on each worker node responsible for launching and managing containers on that node.

```bash
docker compose up -d nodemanager1
sleep 5
```

**Verify NodeManager is running:**

```bash
docker compose ps nodemanager1
```

Expected output: `hadoop-nodemanager1 | Up X seconds`

**Access ResourceManager UI again:**

Refresh: **http://localhost:8088**

Now you should see:
- **NodeManagers: 1** in Cluster Metrics
- Status: "Running"

**Access NodeManager UI:**

Open in browser: **http://localhost:8042**

You should see:
- Node Health Status
- Container metrics
- Resource usage

---

### **Step 6: Start JobHistory Server** ⏱️ (Wait 5 seconds)

JobHistory Server provides a web interface to view logs of completed applications.

```bash
docker compose up -d historyserver
sleep 5
```

**Verify HistoryServer is running:**

```bash
docker compose ps historyserver
```

Expected output: `hadoop-historyserver | Up X seconds`

**Access JobHistory UI:**

Open in browser: **http://localhost:8188**

This will be empty now but will populate after you run MapReduce jobs.

---

## 🚀 Phase 4: Interactive CLI Tools

### **Step 7: Start Hadoop CLI** 

Hadoop CLI container provides command-line tools to interact with HDFS and YARN.

```bash
docker compose up -d hadoop-cli
```

**Verify Hadoop CLI is running:**

```bash
docker compose ps hadoop-cli
```

Expected output: `hadoop-cli | Up X seconds`

---

## 🚀 Phase 5: Hive SQL Engine

Hive provides SQL interface on top of Hadoop, allowing queries to be written in HQL (Hive Query Language).

### **Step 8: Start Hive Metastore Database** ⏱️ (Wait 10 seconds)

PostgreSQL database stores Hive table metadata, schema information, and partitions.

```bash
docker compose up -d hive-metastore-db
sleep 10
```

**Verify PostgreSQL is running:**

```bash
docker compose ps hive-metastore-db
```

Expected output: `hive-metastore-db | Up X seconds`

**Test PostgreSQL connection:**

```bash
docker exec hive-metastore-db psql -U hive -d metastore -c "SELECT version();"
```

Expected output: Shows PostgreSQL version

---

### **Step 9: Start Hive Metastore Service** ⏱️ (Wait 15 seconds)

Hive Metastore Service manages all metadata for Hive tables, partitions, and databases.

```bash
docker compose up -d hive-metastore
sleep 15
```

**Verify Hive Metastore is running:**

```bash
docker compose ps hive-metastore
```

Expected output: `hive-metastore | Up X seconds`

**Check Hive Metastore initialization:**

```bash
docker compose logs hive-metastore | tail -30
```

Look for:
- `"Initialized HMSHandler"`
- `"Hive metastore"`
- `"Started HMSHandler"`

---

### **Step 10: Start HiveServer2** ⏱️ (Wait 10 seconds)

HiveServer2 provides JDBC/ODBC connectivity and Beeline CLI access to Hive.

```bash
docker compose up -d hive-server
sleep 10
```

**Verify HiveServer2 is running:**

```bash
docker compose ps hive-server
```

Expected output: `hive-server | Up X seconds`

**Check HiveServer2 logs:**

```bash
docker compose logs hive-server | tail -30
```

Look for:
- `"HiveServer2 has started on port 10000"`
- `"Started HiveServer2"`
- `"Operation log root directory"`

---

### **Step 11: Start Hive CLI**

Hive CLI container provides interactive command-line interface for Hive queries.

```bash
docker compose up -d hive-cli
sleep 5
```

**Verify Hive CLI is running:**

```bash
docker compose ps hive-cli
```

Expected output: `hive-cli | Up X seconds`

---

## ✅ Complete Cluster Validation

### **Check All Containers Are Running:**

```bash
docker compose ps
```

**Expected output (all services must be "Up"):**

```
NAME                    STATUS
zookeeper               Up X minutes
hadoop-namenode         Up X minutes
hadoop-datanode1        Up X minutes
hadoop-datanode2        Up X minutes
hadoop-resourcemanager  Up X minutes
hadoop-nodemanager1     Up X minutes
hadoop-historyserver    Up X minutes
hadoop-cli              Up X minutes
hive-metastore-db       Up X minutes
hive-metastore          Up X minutes
hive-server             Up X minutes
hive-cli                Up X minutes
```

**If any service is not "Up", check its logs:**

```bash
docker compose logs SERVICE_NAME | tail -50
```

---

## 🌐 Web Dashboards

Access these URLs in your browser to verify cluster health:

### **HDFS Dashboards:**

| Service | URL | What to Check |
|---------|-----|---------------|
| **NameNode** | http://localhost:9870 | "Live Datanodes: 2" in summary, both datanodes "In Service" |
| **DataNode 1** | http://localhost:9864 | Block storage info, capacity usage |
| **DataNode 2** | http://localhost:9865 | Block storage info, capacity usage |

### **YARN Dashboards:**

| Service | URL | What to Check |
|---------|-----|---------------|
| **ResourceManager** | http://localhost:8088 | "NodeManagers: 1", "Running Applications" |
| **NodeManager** | http://localhost:8042 | Node Health, Container metrics |
| **JobHistory** | http://localhost:8188 | Job tracking (empty until jobs submitted) |

### **Hive Services:**

| Service | URL/Port | Purpose |
|---------|----------|---------|
| **Hive Metastore** | localhost:9083 | Thrift service (no UI, backend only) |
| **HiveServer2** | localhost:10000 | JDBC/ODBC endpoint (no UI, backend only) |
| **ZooKeeper** | localhost:2181 | Coordination service (no UI) |
| **PostgreSQL** | localhost:5432 | Metadata database |

---

## 🧪 Validation & Testing

### **Test 1: HDFS File Operations**

Open Hadoop CLI and test HDFS:

```bash
docker exec -it hadoop-cli bash
```

Inside the container, run these commands:

```bash
# 1. Check HDFS health report
hdfs dfsadmin -report

# 2. Create test directories
hdfs dfs -mkdir -p /user/test /data/input

# 3. Create a sample file locally
cat > /tmp/sample.txt << 'EOF'
Line 1: Hello Hadoop
Line 2: This is a test file
Line 3: Testing HDFS file upload
EOF

# 4. Upload file to HDFS
hdfs dfs -put /tmp/sample.txt /user/test/

# 5. List HDFS files
hdfs dfs -ls /user/test/

# 6. View file content
hdfs dfs -cat /user/test/sample.txt

# 7. Check file replication
hdfs dfs -stat "replication: %r, size: %b, name: %n" /user/test/sample.txt

# 8. Check disk usage
hdfs dfs -du -h /user/test/

# 9. Make a directory
hdfs dfs -mkdir /user/test/subdir

# 10. Copy file
hdfs dfs -cp /user/test/sample.txt /user/test/subdir/

# 11. List recursive
hdfs dfs -ls -R /user/test/

# 12. Delete file
hdfs dfs -rm /user/test/subdir/sample.txt

# 13. Exit
exit
```

**Expected Results:**
- All commands execute without errors
- Files appear in HDFS
- File content is readable
- Replication factor = 1

---

### **Test 2: HDFS Block Verification**

```bash
docker exec -it hadoop-cli bash
```

Inside the container:

```bash
# Check block information
hdfs blocks -blockId BLOCK_ID

# View block locations
hdfs dfs -getBlockLocations /user/test/sample.txt

# Check data block status
hdfs dfs -test -e /user/test/sample.txt && echo "File exists"

exit
```

---

### **Test 3: YARN Job Submission (Word Count)**

```bash
docker exec -it hadoop-cli bash
```

Inside the container, run a MapReduce job:

```bash
# Create sample data
echo "hadoop hive spark hadoop yarn mapreduce" > /tmp/words.txt
echo "hdfs namenode datanode zookeeper" >> /tmp/words.txt

# Upload to HDFS
hdfs dfs -put /tmp/words.txt /data/input/

# Run word count job
hadoop jar /opt/hadoop-3.2.1/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.2.1.jar \
  wordcount /data/input/words.txt /data/output/wordcount

# View results
hdfs dfs -cat /data/output/wordcount/part-r-00000

# Check job logs
hdfs dfs -ls -R /data/

exit
```

**Expected Results:**
- Job completes successfully
- Output shows word frequencies
- Word count data appears in HDFS

**Verify on JobHistory UI:**
- Open http://localhost:8188
- Should show the completed word count job

---

### **Test 4: Hive SQL Queries**

#### **Method A: Using Beeline (JDBC)**

```bash
docker exec -it hive-cli bash
```

Inside the container:

```bash
# Connect to HiveServer2
beeline -u "jdbc:hive2://hive-server:10000/" -n hive -p ""
```

Once in Beeline, run these SQL commands:

```sql
-- Show Hive version
SELECT 'Hive is working!' as status;

-- Show existing databases
SHOW DATABASES;

-- Create a new database
CREATE DATABASE IF NOT EXISTS demo_db;

-- Use the database
USE demo_db;

-- Create a table
CREATE TABLE employees (
    emp_id INT,
    emp_name STRING,
    department STRING,
    salary DOUBLE
);

-- Insert sample data
INSERT INTO employees VALUES 
    (1, 'Alice', 'Engineering', 95000),
    (2, 'Bob', 'Marketing', 75000),
    (3, 'Charlie', 'Engineering', 85000),
    (4, 'Diana', 'Sales', 70000);

-- Simple SELECT
SELECT * FROM employees;

-- Filtered SELECT
SELECT emp_name, salary FROM employees WHERE department = 'Engineering';

-- Aggregation
SELECT department, COUNT(*) as emp_count, AVG(salary) as avg_salary 
FROM employees 
GROUP BY department;

-- Sorted results
SELECT emp_name, salary FROM employees ORDER BY salary DESC;

-- Join with subquery
SELECT a.emp_name, a.salary FROM 
  (SELECT * FROM employees WHERE salary > 75000) a;

-- Show table schema
DESCRIBE employees;

-- Show table properties
SHOW TBLPROPERTIES employees;

-- Show all tables
SHOW TABLES;

-- Exit Beeline
!exit
```

Exit the container:

```bash
exit
```

---

#### **Method B: Using Hive CLI (Direct)**

```bash
docker exec -it hadoop-cli bash
```

Inside the container:

```bash
# Run HQL directly
hive -e "SELECT 'Hive CLI is working!' as message;"

# Create and run a Hive script
cat > /tmp/hive_script.sql << 'SCRIPT'
CREATE DATABASE IF NOT EXISTS test_db;
USE test_db;

CREATE TABLE IF NOT EXISTS products (
    product_id INT,
    product_name STRING,
    category STRING,
    price DOUBLE
);

INSERT INTO products VALUES
    (1, 'Laptop', 'Electronics', 999.99),
    (2, 'Mouse', 'Electronics', 29.99),
    (3, 'Desk', 'Furniture', 299.99);

SELECT * FROM products;
SELECT category, AVG(price) as avg_price FROM products GROUP BY category;
SCRIPT

# Run the script
hive -f /tmp/hive_script.sql

exit
```

---

### **Test 5: Check Hive Metadata in PostgreSQL**

```bash
docker exec -it hive-metastore-db bash
```

Inside the container:

```bash
# Connect to PostgreSQL
psql -U hive -d metastore

# View Hive tables metadata
SELECT * FROM tbls;

# View Hive databases
SELECT * FROM dbs;

# View table columns
SELECT * FROM columns_v2;

# Count tables
SELECT COUNT(*) as total_tables FROM tbls;

# Exit PostgreSQL
\q
exit
```

---

## 📊 Cluster Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                 HADOOP & HIVE CLUSTER ARCHITECTURE                │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  COORDINATION LAYER                                             │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ ZooKeeper (2181)                                        │   │
│  │ └─ Distributed coordination & service discovery         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          │                                       │
│  STORAGE LAYER (HDFS)                                           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ NameNode (9870, 8020)          Datanode1 (9864)        │   │
│  │ ├─ Manages filesystem      ├─ Stores blocks            │   │
│  │ ├─ Maintains filelist      ├─ Reports health           │   │
│  │ └─ Manages replication     └─ Replicates blocks        │   │
│  │                                                          │   │
│  │ Datanode2 (9865)                                        │   │
│  │ ├─ Stores blocks                                        │   │
│  │ ├─ Reports health                                       │   │
│  │ └─ Replicates blocks                                    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          │                                       │
│  COMPUTE LAYER (YARN)                                           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ ResourceManager (8088)                                  │   │
│  │ ├─ Allocates cluster resources                          │   │
│  │ ├─ Schedules applications                              │   │
│  │ └─ Manages NodeManagers                                │   │
│  │                                                          │   │
│  │ NodeManager (8042)          HistoryServer (8188)       │   │
│  │ ├─ Runs containers         ├─ Tracks job logs         │   │
│  │ ├─ Manages tasks           ├─ Provides metrics        │   │
│  │ └─ Reports metrics         └─ Job history UI          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          │                                       │
│  QUERY LAYER (HIVE)                                             │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ HiveServer2 (10000)         Hive Metastore (9083)      │   │
│  │ ├─ JDBC/ODBC interface     ├─ Manages table metadata  │   │
│  │ ├─ SQL query execution     ├─ Partition information   │   │
│  │ └─ Beeline access          └─ Column statistics       │   │
│  │                                                          │   │
│  │ PostgreSQL (5432)                                       │   │
│  │ └─ Stores Hive metadata (databases, tables, columns)  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          │                                       │
│  CLIENT LAYER                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Hadoop CLI          │ Hive CLI       │ Beeline         │   │
│  │ ├─ hdfs commands   │ ├─ HQL queries │ ├─ JDBC client  │   │
│  │ ├─ yarn commands   │ └─ Hive shell  │ └─ JDBC over HS2│   │
│  │ └─ hadoop commands │                │                 │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## 📊 Service Dependencies

```
                    ┌─────────────┐
                    │ ZooKeeper   │
                    └──────┬──────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
    ┌───▼───┐        ┌─────▼─────┐      ┌────▼─────┐
    │ HDFS  │        │   YARN    │      │ Hive     │
    ├───────┤        ├───────────┤      ├──────────┤
    │Name   │        │ Resource  │      │Metastore │
    │Node   │        │ Manager   │      │DB        │
    └───┬───┘        └─────┬─────┘      └────┬─────┘
        │                  │                  │
    ┌───▼───┐        ┌─────▼─────┐      ┌────▼──────┐
    │Data   │        │ Node      │      │Hive       │
    │Nodes  │        │ Manager   │      │Metastore  │
    └─┬─────┘        └────┬──────┘      └──┬─────────┘
      │                   │                │
      └───┬───────────────┼────────────────┘
          │               │
          ▼               ▼
    ┌──────────────────────────────┐
    │  HiveServer2 (10000)         │
    │  ├─ Beeline CLI             │
    │  ├─ JDBC connections        │
    │  └─ SQL queries             │
    └──────────────────────────────┘
              │
              ▼
    ┌──────────────────────────────┐
    │ Client Tools                 │
    │ ├─ hadoop-cli (bash)        │
    │ ├─ hive-cli (bash)          │
    │ └─ beeline (JDBC)           │
    └──────────────────────────────┘
```

---

## 🔧 Common Commands

### **Container Management:**

```bash
# View all running containers
docker compose ps

# View specific service status
docker compose ps namenode

# View detailed logs
docker compose logs namenode

# View last 50 lines of logs
docker compose logs --tail=50 namenode

# Follow logs in real-time
docker compose logs -f namenode

# View logs for all services
docker compose logs -f

# Stop all containers (keep data)
docker compose stop

# Start stopped containers
docker compose start

# Restart specific service
docker compose restart namenode

# Stop and remove containers (keep data volumes)
docker compose down

# View resource usage
docker stats
```

---

### **HDFS Commands (in hadoop-cli container):**

```bash
docker exec -it hadoop-cli bash
```

**Inside the container:**

```bash
# Get HDFS health report
hdfs dfsadmin -report

# List contents of a directory
hdfs dfs -ls /
hdfs dfs -ls -R /user

# Create directory
hdfs dfs -mkdir /user/mydir

# Upload file from local to HDFS
hdfs dfs -put /local/file.txt /user/mydir/

# Download file from HDFS to local
hdfs dfs -get /user/mydir/file.txt /local/

# View file content
hdfs dfs -cat /user/mydir/file.txt

# Copy within HDFS
hdfs dfs -cp /user/mydir/file.txt /user/backup/

# Move within HDFS
hdfs dfs -mv /user/mydir/file.txt /user/other/

# Delete file
hdfs dfs -rm /user/mydir/file.txt

# Delete directory
hdfs dfs -rm -r /user/mydir

# Check file information
hdfs dfs -stat "replication: %r, size: %b, name: %n" /user/mydir/file.txt

# Get disk usage
hdfs dfs -du -h /user/

# Append to file
hdfs dfs -appendToFile /local/data.txt /user/mydir/data.txt

# Count files and directories
hdfs dfs -count /user/

# Get block locations
hdfs dfs -getBlockLocations /user/mydir/file.txt

# Set replication factor
hdfs dfs -setrep -w 2 /user/mydir/file.txt

exit
```

---

### **YARN Commands (in hadoop-cli container):**

```bash
docker exec -it hadoop-cli bash
```

**Inside the container:**

```bash
# Show cluster information
yarn cluster report

# List all applications
yarn application -list

# List running applications
yarn application -list -appStates RUNNING

# List finished applications
yarn application -list -appStates FINISHED

# Get application details
yarn application -status <application_id>

# Kill application
yarn application -kill <application_id>

# Show resource usage by queue
yarn queue -status default

# View logs for an application
yarn logs -applicationId <app_id>

# Get resource manager information
yarn resourcemanager -admin -refreshQueues

exit
```

---

### **Hive Commands (in hive-cli container):**

```bash
# Method 1: Using Beeline (recommended)
docker exec -it hive-cli bash
beeline -u "jdbc:hive2://hive-server:10000/" -n hive -p ""
```

**In Beeline:**

```sql
-- Show all databases
SHOW DATABASES;

-- Create database
CREATE DATABASE IF NOT EXISTS my_db;

-- Use database
USE my_db;

-- Show all tables
SHOW TABLES;

-- Create table
CREATE TABLE employees (id INT, name STRING, salary DOUBLE);

-- Insert data
INSERT INTO employees VALUES (1, 'John', 95000);

-- Query data
SELECT * FROM employees;

-- Describe table
DESCRIBE employees;

-- Alter table
ALTER TABLE employees ADD COLUMNS (department STRING);

-- Drop table
DROP TABLE employees;

-- Drop database
DROP DATABASE my_db;

-- Show table statistics
SHOW TBLPROPERTIES employees;

-- Explain query plan
EXPLAIN SELECT * FROM employees WHERE salary > 80000;

-- Exit
!exit
```

---

```bash
# Method 2: Using Hive CLI (direct)
docker exec -it hadoop-cli bash
hive -e "SELECT 'Hive is ready!' as status;"
exit
```

---

### **MapReduce Job Submission:**

```bash
docker exec -it hadoop-cli bash
```

**Inside the container:**

```bash
# Run word count example
hadoop jar /opt/hadoop-3.2.1/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.2.1.jar \
  wordcount /input/path /output/path

# Run pi estimation
hadoop jar /opt/hadoop-3.2.1/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.2.1.jar \
  pi 10 100

# List available examples
ls /opt/hadoop-3.2.1/share/hadoop/mapreduce/*examples*.jar

exit
```

---

## ❌ Troubleshooting

### **Issue 1: Containers not starting**

**Symptoms:** Services show `Exited` status

**Solution:**

```bash
# Check logs for errors
docker compose logs SERVICE_NAME

# Check disk space
df -h

# Check Docker resources
docker info

# Try rebuilding
docker compose down -v
rm -rf ./data/*
docker compose up -d zookeeper
```

---

### **Issue 2: NameNode won't start**

**Symptoms:** NameNode container exits immediately

**Solution:**

```bash
# Check NameNode logs
docker compose logs namenode

# If format error, reformat the namenode
docker exec hadoop-namenode hdfs namenode -format -force

# Restart NameNode
docker compose restart namenode
```

---

### **Issue 3: DataNodes not registering with NameNode**

**Symptoms:** NameNode UI shows 0 DataNodes

**Solution:**

```bash
# Check DataNode logs
docker compose logs datanode1
docker compose logs datanode2

# Verify network connectivity
docker exec hadoop-cli ping namenode
docker exec hadoop-cli ping datanode1
docker exec hadoop-cli ping datanode2

# Check Docker network
docker network inspect hadoop

# Restart DataNodes
docker compose restart datanode1 datanode2
```

---

### **Issue 4: HDFS shows read-only mode**

**Symptoms:** "Write failed: java.io.IOException: File could only be replicated to 0 nodes instead of 1"

**Solution:**

```bash
# Leave safe mode
docker exec hadoop-cli hdfs dfsadmin -safemode leave

# Check safe mode status
docker exec hadoop-cli hdfs dfsadmin -safemode get
```

---

### **Issue 5: Hive Metastore not connecting**

**Symptoms:** HiveServer2 or Hive CLI fails to connect

**Solution:**

```bash
# Check Hive Metastore logs
docker compose logs hive-metastore

# Check PostgreSQL status
docker compose ps hive-metastore-db

# Test PostgreSQL connection
docker exec hive-metastore-db psql -U hive -d metastore -c "SELECT 1;"

# Restart Hive services in order
docker compose restart hive-metastore-db
sleep 10
docker compose restart hive-metastore
sleep 10
docker compose restart hive-server
```

---

### **Issue 6: Port conflicts**

**Symptoms:** "port is already allocated"

**Solution:**

```bash
# Find process using port
lsof -i :9870

# Kill the process
kill -9 PID

# Or change port in docker-compose.yaml
# Change "9870:9870" to "9871:9870"

# Restart containers
docker compose down
docker compose up -d
```

---

### **Issue 7: Out of disk space**

**Symptoms:** HDFS or services fail

**Solution:**

```bash
# Check disk usage
df -h

# Clean up Docker images and volumes
docker system prune -a --volumes

# Remove specific volume
docker volume rm $(docker volume ls -q)

# Check data directory size
du -sh ./data/*

# Clean old data
rm -rf ./data/*
```

---

### **Issue 8: Slow performance**

**Symptoms:** Operations take too long

**Solution:**

```bash
# Increase Docker resources (Desktop app settings)
# - Memory: 8GB recommended
# - CPU: 4+ cores

# Check resource usage
docker stats

# Check system resources
free -h
top -l 1

# Optimize containers
docker compose down -v
rm -rf ./data/*
docker compose up -d
```

---

## 🛑 Shutdown & Cleanup

### **Stop all containers (keep data and volumes):**

```bash
docker compose stop
```

Containers are stopped but data persists. Restart with:

```bash
docker compose start
```

---

### **Remove containers (keep data in volumes):**

```bash
docker compose down
```

Containers are removed but `./data/` directory remains. Restart with:

```bash
docker compose up -d zookeeper
sleep 5
docker compose up -d namenode
# ... continue with other services
```

---

### **Full cleanup (delete all data and containers):**

```bash
# Stop and remove all containers
docker compose down -v

# Remove all data
rm -rf ./data/*

# Optional: Remove Docker images (if you want to free more space)
docker rmi bde2020/hadoop-namenode:2.0.0-hadoop3.2.1-java8
docker rmi bde2020/hadoop-datanode:2.0.0-hadoop3.2.1-java8
docker rmi bde2020/hadoop-resourcemanager:2.0.0-hadoop3.2.1-java8
docker rmi bde2020/hadoop-nodemanager:2.0.0-hadoop3.2.1-java8
docker rmi bde2020/hadoop-historyserver:2.0.0-hadoop3.2.1-java8
docker rmi bde2020/hadoop-base:2.0.0-hadoop3.2.1-java8
docker rmi bde2020/hive:2.3.2-postgresql-metastore
docker rmi zookeeper:3.9
docker rmi postgres:13-alpine

# Verify cleanup
docker compose ps  # Should be empty
ls -la data/       # Should have empty directories
```

---

### **Selective cleanup:**

```bash
# Remove only Hive containers (keep HDFS)
docker compose stop hive-server hive-cli hive-metastore hive-metastore-db
docker compose rm -f hive-server hive-cli hive-metastore hive-metastore-db
rm -rf ./data/metastore-postgres

# Restart HDFS
docker compose start namenode datanode1 datanode2
```

---

## 📚 Learning Resources

### **Hadoop Documentation:**
- NameNode Admin Guide: https://hadoop.apache.org/docs/current/hadoop-project-dist/hadoop-hdfs/HdfsAdmin.html
- YARN Architecture: https://hadoop.apache.org/docs/current/hadoop-yarn/hadoop-yarn-site/YARN.html
- MapReduce Tutorial: https://hadoop.apache.org/docs/current/hadoop-mapreduce-client/hadoop-mapreduce-client-core/MapReduceTutorial.html

### **Hive Documentation:**
- Hive Language Manual: https://cwiki.apache.org/confluence/display/Hive/LanguageManual
- Beeline Command Line Shell: https://cwiki.apache.org/confluence/display/Hive/HiveServer2+Clients#HiveServer2Clients-Beeline–CommandLineShell

### **Practice Exercises:**

1. **HDFS:** Upload files, test replication, monitor capacity
2. **YARN:** Submit jobs, view logs, monitor resource usage
3. **Hive:** Create databases, tables, run SQL queries
4. **Integration:** Load data via HDFS, query via Hive

---

## ✅ Checklist: Cluster is Ready When...

- [ ] All 12 containers show "Up" status
- [ ] NameNode UI shows 2 Live DataNodes
- [ ] ResourceManager UI shows 1 NodeManager
- [ ] HDFS commands work (`hdfs dfs -ls /`)
- [ ] YARN commands work (`yarn cluster report`)
- [ ] Hive Beeline connects (`beeline -u "jdbc:hive2://hive-server:10000/"`)
- [ ] Hive tables can be created and queried
- [ ] MapReduce jobs can be submitted and complete
- [ ] JobHistory Server shows completed jobs
- [ ] No errors in any container logs

---

## 🎉 You're All Set!

Your Hadoop & Hive cluster is now ready for:
- ✅ HDFS file operations
- ✅ MapReduce job execution
- ✅ YARN resource management
- ✅ Hive SQL queries
- ✅ Data processing and analytics

**Happy learning! 🚀**

---

**Document Version:** 1.0  
**Last Updated:** January 2026  
**Cluster Configuration:** Single-node Hadoop 3.2.1 with Hive 2.3.2
