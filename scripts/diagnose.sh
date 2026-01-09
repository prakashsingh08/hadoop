#!/bin/bash

################################################################################
# Hadoop & Hive Cluster Diagnostics Script
# Purpose: Quick diagnosis and troubleshooting of cluster issues
# Usage: ./diagnose.sh [SERVICE]
# Examples:
#   ./diagnose.sh           # Full diagnosis
#   ./diagnose.sh namenode  # Diagnose specific service
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

TARGET_SERVICE="${1:-all}"

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "\n${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}\n"
}

print_section() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_failure() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

show_usage() {
    echo -e "${BLUE}Usage: $0 [SERVICE]${NC}"
    echo ""
    echo "Available services:"
    echo "  zookeeper              - ZooKeeper coordination"
    echo "  namenode               - HDFS NameNode"
    echo "  datanode1, datanode2   - HDFS DataNodes"
    echo "  resourcemanager        - YARN ResourceManager"
    echo "  nodemanager1           - YARN NodeManager"
    echo "  historyserver          - Job History Server"
    echo "  hive-metastore-db      - PostgreSQL metastore"
    echo "  hive-metastore         - Hive Metastore Service"
    echo "  hive-server            - HiveServer2"
    echo "  all                    - Full diagnosis (default)"
    echo ""
}

################################################################################
# Container Diagnostics
################################################################################

diagnose_container() {
    local service=$1
    local container_name=$2
    local port=$3

    print_section "Diagnostics for: $service"

    # Check if container exists
    print_info "Checking container status..."
    if docker compose ps "$service" 2>/dev/null | grep -q "Up"; then
        print_success "Container is running"
    elif docker compose ps "$service" 2>/dev/null | grep -q "Exited"; then
        print_failure "Container has exited"
        echo ""
        print_info "Recent logs:"
        docker compose logs --tail=30 "$service"
        return 1
    else
        print_failure "Container not found"
        return 1
    fi

    # Get container ID
    local container_id=$(docker compose ps -q "$service" 2>/dev/null || echo "")
    
    if [ -z "$container_id" ]; then
        print_failure "Could not get container ID"
        return 1
    fi

    print_success "Container ID: $container_id"

    # Check resource usage
    print_info "Resource usage:"
    docker stats --no-stream "$container_id" 2>/dev/null | tail -1

    # Check logs for errors
    print_info "Checking logs for errors..."
    local error_count=$(docker compose logs "$service" 2>/dev/null | grep -i "error\|exception\|fail" | wc -l)
    
    if [ "$error_count" -gt 0 ]; then
        print_warning "Found $error_count error(s)/exception(s) in logs"
        echo ""
        print_info "Recent errors:"
        docker compose logs "$service" 2>/dev/null | grep -i "error\|exception\|fail" | tail -5
    else
        print_success "No errors found in recent logs"
    fi

    # Show last few log lines
    print_info "Last 20 log lines:"
    echo ""
    docker compose logs --tail=20 "$service" 2>/dev/null || echo "Could not retrieve logs"

    return 0
}

################################################################################
# System Diagnostics
################################################################################

diagnose_system() {
    print_section "System Information"

    # Docker version
    print_info "Docker version:"
    docker --version

    # Docker Compose version
    print_info "Docker Compose version:"
    docker compose --version

    # Docker daemon status
    print_info "Docker daemon status:"
    if docker ps &>/dev/null; then
        print_success "Docker daemon is running"
    else
        print_failure "Cannot connect to Docker daemon"
        return 1
    fi

    # System resources
    print_section "System Resources"

    print_info "Available disk space:"
    df -h . | tail -1 | awk '{printf "  Total: %s, Used: %s, Available: %s\n", $2, $3, $4}'

    print_info "Available memory:"
    if command -v free &> /dev/null; then
        free -h | grep Mem | awk '{printf "  Total: %s, Used: %s, Available: %s\n", $2, $3, $7}'
    else
        vm_stat | grep "Pages free" | awk '{print "  " $NF}'
    fi

    print_info "Docker disk usage:"
    docker system df | tail -n +2

    # Network
    print_section "Network Diagnostics"

    print_info "Docker networks:"
    docker network ls | grep hadoop || print_warning "hadoop network not found"

    print_info "Testing port availability:"
    local ports=(2181 8020 9870 9864 9865 8088 8042 8188 9083 10000 5432)
    for port in "${ports[@]}"; do
        if nc -z localhost "$port" 2>/dev/null; then
            print_success "Port $port is open"
        else
            print_warning "Port $port is closed"
        fi
    done
}

################################################################################
# Cluster Status
################################################################################

show_cluster_status() {
    print_section "Overall Cluster Status"

    echo "Container Status:"
    echo ""
    docker compose ps || echo "No containers found"

    echo ""
    echo "Container Resource Usage:"
    echo ""
    docker stats --no-stream 2>/dev/null || echo "Could not retrieve stats"
}

################################################################################
# HDFS Diagnostics
################################################################################

diagnose_hdfs() {
    print_section "HDFS Diagnostics"

    if ! docker compose ps namenode 2>/dev/null | grep -q "Up"; then
        print_failure "NameNode is not running"
        return 1
    fi

    print_info "Testing HDFS connectivity..."
    if docker exec hadoop-cli hdfs dfsadmin -report &>/dev/null; then
        print_success "NameNode is responding"
    else
        print_failure "Cannot connect to NameNode"
        return 1
    fi

    print_info "HDFS health report:"
    echo ""
    docker exec hadoop-cli hdfs dfsadmin -report | head -40

    print_info "HDFS safe mode status:"
    docker exec hadoop-cli hdfs dfsadmin -safemode get

    print_info "Testing file system operations..."
    if docker exec hadoop-cli hdfs dfs -ls / &>/dev/null; then
        print_success "HDFS file system is accessible"
    else
        print_failure "Cannot access HDFS file system"
    fi
}

################################################################################
# YARN Diagnostics
################################################################################

diagnose_yarn() {
    print_section "YARN Diagnostics"

    if ! docker compose ps resourcemanager 2>/dev/null | grep -q "Up"; then
        print_failure "ResourceManager is not running"
        return 1
    fi

    print_info "YARN cluster report:"
    echo ""
    docker exec hadoop-cli yarn cluster report | head -20

    print_info "Testing application list..."
    if docker exec hadoop-cli yarn application -list &>/dev/null; then
        print_success "YARN is responding"
    else
        print_failure "Cannot get YARN application list"
    fi
}

################################################################################
# Hive Diagnostics
################################################################################

diagnose_hive() {
    print_section "Hive Diagnostics"

    # Check PostgreSQL
    print_info "Checking PostgreSQL metastore database..."
    if ! docker compose ps hive-metastore-db 2>/dev/null | grep -q "Up"; then
        print_failure "PostgreSQL container is not running"
        return 1
    fi

    if docker exec hive-metastore-db psql -U hive -d metastore -c "SELECT 1;" &>/dev/null; then
        print_success "PostgreSQL is accessible"
    else
        print_failure "Cannot connect to PostgreSQL"
        return 1
    fi

    # Check Hive Metastore Service
    print_info "Checking Hive Metastore Service..."
    if ! docker compose ps hive-metastore 2>/dev/null | grep -q "Up"; then
        print_failure "Hive Metastore Service is not running"
        return 1
    fi

    if docker compose logs hive-metastore 2>/dev/null | grep -q "Initialized HMSHandler"; then
        print_success "Hive Metastore Service is initialized"
    else
        print_warning "Hive Metastore Service may not be fully initialized"
    fi

    # Check HiveServer2
    print_info "Checking HiveServer2..."
    if ! docker compose ps hive-server 2>/dev/null | grep -q "Up"; then
        print_failure "HiveServer2 is not running"
        return 1
    fi

    print_info "Testing Beeline connection..."
    if timeout 5 docker exec hive-cli beeline -u "jdbc:hive2://hive-server:10000/" -n hive -p "" -e "SELECT 1;" &>/dev/null; then
        print_success "Beeline can connect to HiveServer2"
    else
        print_warning "Beeline cannot connect to HiveServer2 (may still be initializing)"
    fi

    # Check Hive database
    print_info "Checking Hive databases..."
    if docker exec hadoop-cli hive -e "SHOW DATABASES;" &>/dev/null; then
        print_success "Hive database listing works"
        echo ""
        docker exec hadoop-cli hive -e "SHOW DATABASES;"
    else
        print_warning "Cannot list Hive databases"
    fi
}

################################################################################
# ZooKeeper Diagnostics
################################################################################

diagnose_zookeeper() {
    print_section "ZooKeeper Diagnostics"

    if ! docker compose ps zookeeper 2>/dev/null | grep -q "Up"; then
        print_failure "ZooKeeper is not running"
        return 1
    fi

    print_info "ZooKeeper server status:"
    if docker exec zookeeper zkServer.sh status &>/dev/null; then
        docker exec zookeeper zkServer.sh status
    else
        print_warning "Could not get ZooKeeper status"
    fi

    print_info "Testing ZooKeeper connectivity..."
    if docker exec hadoop-cli timeout 3 bash -c 'echo ruok | nc zookeeper 2181' 2>&1 | grep -q "imok"; then
        print_success "ZooKeeper is responding to client requests"
    else
        print_warning "ZooKeeper may not be responding"
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    clear
    
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║   HADOOP & HIVE CLUSTER DIAGNOSTICS                           ║"
    echo "║   Version: 1.0                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        print_failure "Docker is not installed"
        exit 1
    fi

    if [ "$TARGET_SERVICE" = "help" ] || [ "$TARGET_SERVICE" = "-h" ] || [ "$TARGET_SERVICE" = "--help" ]; then
        show_usage
        exit 0
    fi

    # Run diagnostics based on target
    case "$TARGET_SERVICE" in
        all)
            diagnose_system
            show_cluster_status
            diagnose_zookeeper
            diagnose_hdfs
            diagnose_yarn
            diagnose_hive
            ;;
        zookeeper)
            diagnose_container "zookeeper" "zookeeper" "2181"
            diagnose_zookeeper
            ;;
        namenode)
            diagnose_container "namenode" "hadoop-namenode" "9870"
            diagnose_hdfs
            ;;
        datanode1)
            diagnose_container "datanode1" "hadoop-datanode1" "9864"
            ;;
        datanode2)
            diagnose_container "datanode2" "hadoop-datanode2" "9865"
            ;;
        resourcemanager)
            diagnose_container "resourcemanager" "hadoop-resourcemanager" "8088"
            diagnose_yarn
            ;;
        nodemanager1)
            diagnose_container "nodemanager1" "hadoop-nodemanager1" "8042"
            ;;
        historyserver)
            diagnose_container "historyserver" "hadoop-historyserver" "8188"
            ;;
        hive-metastore-db)
            diagnose_container "hive-metastore-db" "hive-metastore-db" "5432"
            ;;
        hive-metastore)
            diagnose_container "hive-metastore" "hive-metastore" "9083"
            ;;
        hive-server)
            diagnose_container "hive-server" "hive-server" "10000"
            diagnose_hive
            ;;
        system)
            diagnose_system
            ;;
        hdfs)
            diagnose_hdfs
            ;;
        yarn)
            diagnose_yarn
            ;;
        hive)
            diagnose_hive
            ;;
        *)
            print_failure "Unknown service: $TARGET_SERVICE"
            echo ""
            show_usage
            exit 1
            ;;
    esac

    echo ""
    print_section "Diagnostics Complete"
    echo "For more detailed information, check container logs:"
    echo "  docker compose logs -f SERVICE_NAME"
    echo ""
}

main
