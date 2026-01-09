#!/bin/bash

################################################################################
# Hadoop & Hive Cluster Health Validation Script
# Purpose: Verify all services are running and healthy
# Usage: ./validate-cluster.sh
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Configuration
NAMENODE_URL="http://localhost:9870"
DATANODE1_URL="http://localhost:9864"
DATANODE2_URL="http://localhost:9865"
RESOURCEMANAGER_URL="http://localhost:8088"
NODEMANAGER_URL="http://localhost:8042"
JOBHISTORY_URL="http://localhost:8188"
HIVE_METASTORE_URL="localhost:9083"
HIVESERVER2_URL="localhost:10000"
ZOOKEEPER_URL="localhost:2181"
POSTGRES_URL="localhost:5432"

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((PASSED++))
}

print_failure() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    ((FAILED++))
}

print_warning() {
    echo -e "${YELLOW}⚠ WARN${NC}: $1"
    ((WARNINGS++))
}

print_info() {
    echo -e "${BLUE}ℹ INFO${NC}: $1"
}

print_test() {
    echo -e "${BLUE}→${NC} Testing: $1"
}

################################################################################
# Docker Container Checks
################################################################################

check_containers() {
    print_header "PHASE 1: Docker Container Status"

    local services=("zookeeper" "hadoop-namenode" "hadoop-datanode1" "hadoop-datanode2" \
                    "hadoop-resourcemanager" "hadoop-nodemanager1" "hadoop-historyserver" \
                    "hadoop-cli" "hive-metastore-db" "hive-metastore" "hive-server" "hive-cli")

    for service in "${services[@]}"; do
        print_test "Checking if $service is running"
        
        if docker compose ps "$service" 2>/dev/null | grep -q "Up"; then
            print_success "Container '$service' is running"
        else
            print_failure "Container '$service' is NOT running or not found"
        fi
    done
}

################################################################################
# Network Connectivity Checks
################################################################################

check_network_connectivity() {
    print_header "PHASE 2: Network Connectivity"

    # Test NameNode connectivity
    print_test "Testing connectivity to NameNode (namenode:8020)"
    if docker exec hadoop-cli timeout 3 bash -c 'echo > /dev/tcp/namenode/8020' 2>/dev/null; then
        print_success "NameNode is reachable on port 8020"
    else
        print_failure "Cannot reach NameNode on port 8020"
    fi

    # Test DataNode1 connectivity
    print_test "Testing connectivity to DataNode1 (datanode1:9866)"
    if docker exec hadoop-cli timeout 3 bash -c 'echo > /dev/tcp/datanode1/9866' 2>/dev/null; then
        print_success "DataNode1 is reachable on port 9866"
    else
        print_warning "Cannot reach DataNode1 on port 9866 (may be normal if no connections)"
    fi

    # Test DataNode2 connectivity
    print_test "Testing connectivity to DataNode2 (datanode2:9866)"
    if docker exec hadoop-cli timeout 3 bash -c 'echo > /dev/tcp/datanode2/9866' 2>/dev/null; then
        print_success "DataNode2 is reachable on port 9866"
    else
        print_warning "Cannot reach DataNode2 on port 9866 (may be normal if no connections)"
    fi

    # Test ResourceManager connectivity
    print_test "Testing connectivity to ResourceManager (resourcemanager:8032)"
    if docker exec hadoop-cli timeout 3 bash -c 'echo > /dev/tcp/resourcemanager/8032' 2>/dev/null; then
        print_success "ResourceManager is reachable on port 8032"
    else
        print_failure "Cannot reach ResourceManager on port 8032"
    fi

    # Test ZooKeeper connectivity
    print_test "Testing connectivity to ZooKeeper (zookeeper:2181)"
    if docker exec hadoop-cli timeout 3 bash -c 'echo > /dev/tcp/zookeeper/2181' 2>/dev/null; then
        print_success "ZooKeeper is reachable on port 2181"
    else
        print_failure "Cannot reach ZooKeeper on port 2181"
    fi

    # Test Hive Metastore connectivity
    print_test "Testing connectivity to Hive Metastore (hive-metastore:9083)"
    if docker exec hadoop-cli timeout 3 bash -c 'echo > /dev/tcp/hive-metastore/9083' 2>/dev/null; then
        print_success "Hive Metastore is reachable on port 9083"
    else
        print_failure "Cannot reach Hive Metastore on port 9083"
    fi

    # Test HiveServer2 connectivity
    print_test "Testing connectivity to HiveServer2 (hive-server:10000)"
    if docker exec hadoop-cli timeout 3 bash -c 'echo > /dev/tcp/hive-server/10000' 2>/dev/null; then
        print_success "HiveServer2 is reachable on port 10000"
    else
        print_failure "Cannot reach HiveServer2 on port 10000"
    fi

    # Test PostgreSQL connectivity
    print_test "Testing connectivity to PostgreSQL (hive-metastore-db:5432)"
    if docker exec hadoop-cli timeout 3 bash -c 'echo > /dev/tcp/hive-metastore-db/5432' 2>/dev/null; then
        print_success "PostgreSQL is reachable on port 5432"
    else
        print_failure "Cannot reach PostgreSQL on port 5432"
    fi
}

################################################################################
# HDFS Health Checks
################################################################################

check_hdfs_health() {
    print_header "PHASE 3: HDFS Health Status"

    # Get HDFS report
    print_test "Checking HDFS health report"
    local hdfs_report=$(docker exec hadoop-cli hdfs dfsadmin -report 2>&1)

    # Check for live datanodes
    print_test "Checking for live DataNodes"
    if echo "$hdfs_report" | grep -q "Live datanode(s)"; then
        local live_datanodes=$(echo "$hdfs_report" | grep "Live datanode(s)" | awk -F: '{print $2}' | tr -d ' ')
        if [[ "$live_datanodes" -ge 2 ]]; then
            print_success "Found $live_datanodes live DataNodes (expected: 2)"
        elif [[ "$live_datanodes" -ge 1 ]]; then
            print_warning "Found $live_datanodes live DataNode(s) (expected: 2)"
        else
            print_failure "No live DataNodes found"
        fi
    else
        print_warning "Could not determine live DataNode count"
    fi

    # Check HDFS capacity
    print_test "Checking HDFS storage capacity"
    if echo "$hdfs_report" | grep -q "Configured Capacity"; then
        local capacity=$(echo "$hdfs_report" | grep "Configured Capacity" | awk '{print $NF}')
        print_success "HDFS configured capacity: $capacity"
    else
        print_warning "Could not determine HDFS capacity"
    fi

    # Check HDFS usage
    print_test "Checking HDFS usage"
    if echo "$hdfs_report" | grep -q "DFS Used"; then
        local used=$(echo "$hdfs_report" | grep "DFS Used" | awk '{print $NF}')
        print_success "HDFS current usage: $used"
    else
        print_warning "Could not determine HDFS usage"
    fi

    # Test HDFS operations
    print_test "Testing HDFS file listing"
    if docker exec hadoop-cli hdfs dfs -ls / 2>&1 | grep -q "total"; then
        print_success "HDFS file system is accessible"
    else
        print_failure "Cannot access HDFS file system"
    fi

    # Check safe mode
    print_test "Checking HDFS safe mode status"
    local safemode=$(docker exec hadoop-cli hdfs dfsadmin -safemode get 2>&1)
    if echo "$safemode" | grep -q "off"; then
        print_success "HDFS is not in safe mode (ready for writes)"
    elif echo "$safemode" | grep -q "on"; then
        print_warning "HDFS is in safe mode (read-only mode)"
    else
        print_warning "Could not determine safe mode status: $safemode"
    fi
}

################################################################################
# YARN Health Checks
################################################################################

check_yarn_health() {
    print_header "PHASE 4: YARN Health Status"

    # Get YARN cluster report
    print_test "Checking YARN cluster status"
    local yarn_report=$(docker exec hadoop-cli yarn cluster report 2>&1)

    # Check for NodeManagers
    print_test "Checking for active NodeManagers"
    if echo "$yarn_report" | grep -q "active NodeManagers"; then
        local nodemanagers=$(echo "$yarn_report" | grep "active NodeManagers" | awk '{print $1}')
        if [[ "$nodemanagers" -ge 1 ]]; then
            print_success "Found $nodemanagers active NodeManager(s)"
        else
            print_failure "No active NodeManagers found"
        fi
    else
        print_warning "Could not determine NodeManager count"
    fi

    # Check resource availability
    print_test "Checking YARN resource availability"
    if echo "$yarn_report" | grep -q "Memory"; then
        print_success "YARN memory resources are available"
    else
        print_warning "Could not determine YARN memory resources"
    fi

    # Check queue status
    print_test "Checking YARN queue status"
    local queue_status=$(docker exec hadoop-cli yarn queue -status default 2>&1)
    if echo "$queue_status" | grep -q "default"; then
        print_success "YARN default queue is accessible"
    else
        print_warning "Could not verify YARN default queue"
    fi

    # Check application list
    print_test "Checking YARN applications"
    if docker exec hadoop-cli yarn application -list 2>&1 | grep -q "Application-id"; then
        print_success "Can retrieve YARN application list"
    else
        print_warning "Could not retrieve YARN application list"
    fi
}

################################################################################
# Hive Health Checks
################################################################################

check_hive_health() {
    print_header "PHASE 5: Hive SQL Engine Status"

    # Check PostgreSQL connection
    print_test "Testing PostgreSQL metastore database"
    if docker exec hive-metastore-db psql -U hive -d metastore -c "SELECT 1;" 2>&1 | grep -q "1 row"; then
        print_success "PostgreSQL metastore database is accessible"
    else
        print_failure "Cannot connect to PostgreSQL metastore database"
    fi

    # Check Hive Metastore Service
    print_test "Checking Hive Metastore Service logs"
    local metastore_logs=$(docker compose logs hive-metastore 2>&1 | tail -20)
    if echo "$metastore_logs" | grep -q "Initialized HMSHandler\|started HMSHandler"; then
        print_success "Hive Metastore Service is initialized"
    else
        print_warning "Could not confirm Hive Metastore Service initialization"
    fi

    # Check HiveServer2
    print_test "Checking HiveServer2 logs"
    local hiveserver2_logs=$(docker compose logs hive-server 2>&1 | tail -20)
    if echo "$hiveserver2_logs" | grep -q "HiveServer2 has started\|Started HiveServer2"; then
        print_success "HiveServer2 is running"
    else
        print_warning "Could not confirm HiveServer2 status"
    fi

    # Test Hive connection via Beeline
    print_test "Testing Hive Beeline JDBC connection"
    if docker exec hive-cli timeout 10 beeline -u "jdbc:hive2://hive-server:10000/" -n hive -p "" -e "SELECT 'Hive Ready' as status;" 2>&1 | grep -q "Hive Ready"; then
        print_success "Beeline JDBC connection to HiveServer2 is working"
    else
        print_warning "Could not verify Beeline JDBC connection (service may still be initializing)"
    fi

    # Check Hive database listing
    print_test "Testing Hive database operations"
    if docker exec hadoop-cli hive -e "SHOW DATABASES;" 2>&1 | grep -q "default"; then
        print_success "Can retrieve Hive databases"
    else
        print_warning "Could not verify Hive database operations"
    fi
}

################################################################################
# ZooKeeper Health Checks
################################################################################

check_zookeeper_health() {
    print_header "PHASE 6: ZooKeeper Status"

    # Check ZooKeeper status
    print_test "Checking ZooKeeper server status"
    if docker exec zookeeper zkServer.sh status 2>&1 | grep -q "Mode:"; then
        local mode=$(docker exec zookeeper zkServer.sh status 2>&1 | grep "Mode:" | awk '{print $NF}')
        print_success "ZooKeeper is running in $mode mode"
    else
        print_failure "Cannot determine ZooKeeper status"
    fi

    # Check ZooKeeper client port
    print_test "Testing ZooKeeper client port connectivity"
    if docker exec hadoop-cli timeout 3 bash -c 'echo ruok | nc zookeeper 2181' 2>&1 | grep -q "imok"; then
        print_success "ZooKeeper client port (2181) is responding"
    else
        print_warning "ZooKeeper client port is not responding (may be normal)"
    fi
}

################################################################################
# Web UI Availability Checks
################################################################################

check_web_uis() {
    print_header "PHASE 7: Web UI Availability"

    local web_services=(
        "NameNode:$NAMENODE_URL"
        "DataNode1:$DATANODE1_URL"
        "DataNode2:$DATANODE2_URL"
        "ResourceManager:$RESOURCEMANAGER_URL"
        "NodeManager:$NODEMANAGER_URL"
        "JobHistory:$JOBHISTORY_URL"
    )

    for service in "${web_services[@]}"; do
        IFS=':' read -r name url <<< "$service"
        print_test "Checking $name UI at $url"
        
        if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200"; then
            print_success "$name UI is accessible"
        else
            local http_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
            print_warning "$name UI returned HTTP $http_code (service may be initializing)"
        fi
    done
}

################################################################################
# Disk Space Checks
################################################################################

check_disk_space() {
    print_header "PHASE 8: Disk Space"

    print_test "Checking Docker disk space"
    local docker_df=$(docker system df | grep -E "RECLAIMABLE|TYPE")
    echo "$docker_df"

    print_test "Checking data directory size"
    if [ -d "./data" ]; then
        local data_size=$(du -sh ./data 2>/dev/null | awk '{print $1}')
        print_success "Data directory size: $data_size"
    else
        print_warning "Data directory not found"
    fi

    print_test "Checking system disk space"
    local disk_usage=$(df -h . | tail -1 | awk '{print $5}')
    local disk_available=$(df -h . | tail -1 | awk '{print $4}')
    
    if [[ "${disk_usage%\%}" -lt 80 ]]; then
        print_success "System disk usage: $disk_usage (Available: $disk_available)"
    elif [[ "${disk_usage%\%}" -lt 95 ]]; then
        print_warning "System disk usage: $disk_usage (Available: $disk_available)"
    else
        print_failure "System disk usage: $disk_usage (Available: $disk_available) - LOW DISK SPACE!"
    fi
}

################################################################################
# Resource Usage Checks
################################################################################

check_resource_usage() {
    print_header "PHASE 9: Container Resource Usage"

    print_test "Getting Docker container resource stats"
    echo ""
    docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}\t{{.CPUPerc}}" 2>/dev/null | head -15 || print_warning "Cannot retrieve Docker stats"
    echo ""
}

################################################################################
# Summary Report
################################################################################

print_summary() {
    print_header "VALIDATION SUMMARY"

    echo -e "Tests Passed:  ${GREEN}$PASSED${NC}"
    echo -e "Tests Failed:  ${RED}$FAILED${NC}"
    echo -e "Tests Warning: ${YELLOW}$WARNINGS${NC}"
    echo ""

    if [ $FAILED -eq 0 ]; then
        echo -e "${GREEN}✓ CLUSTER HEALTH: EXCELLENT${NC}"
        echo "All critical services are running and healthy."
        echo ""
        echo "Access the cluster dashboards:"
        echo "  - NameNode:       $NAMENODE_URL"
        echo "  - ResourceManager: $RESOURCEMANAGER_URL"
        echo "  - JobHistory:     $JOBHISTORY_URL"
        return 0
    elif [ $FAILED -le 3 ]; then
        echo -e "${YELLOW}⚠ CLUSTER HEALTH: DEGRADED${NC}"
        echo "Some services are not responding but core functionality may work."
        echo "Check the failures above and review container logs."
        return 1
    else
        echo -e "${RED}✗ CLUSTER HEALTH: CRITICAL${NC}"
        echo "Multiple services are not running. Start the cluster and try again."
        echo ""
        echo "Start the cluster with:"
        echo "  docker compose up -d zookeeper"
        echo "  sleep 5"
        echo "  docker compose up -d namenode"
        echo "  sleep 10"
        echo "  docker compose up -d datanode1 datanode2"
        echo "  # ... continue with other services"
        return 1
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    clear
    
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║   HADOOP & HIVE CLUSTER HEALTH VALIDATION                     ║"
    echo "║   Version: 1.0                                                ║"
    echo "║   Date: $(date '+%Y-%m-%d %H:%M:%S')                              ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # Check if Docker Compose is available
    if ! command -v docker &> /dev/null || ! command -v docker compose &> /dev/null; then
        print_failure "Docker or Docker Compose is not installed"
        exit 1
    fi

    # Run all checks
    check_containers
    check_network_connectivity
    check_hdfs_health
    check_yarn_health
    check_hive_health
    check_zookeeper_health
    check_web_uis
    check_disk_space
    check_resource_usage
    
    # Print summary
    print_summary
}

# Execute main function
main
