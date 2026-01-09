#!/bin/bash

################################################################################
# Hadoop & Hive Cluster Startup Script
# Purpose: Start all services in the correct order with proper wait times
# Usage: ./start-cluster.sh
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "\n${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}\n"
}

print_step() {
    echo -e "${GREEN}→${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

wait_for_service() {
    local service=$1
    local wait_time=$2
    
    print_info "Waiting $wait_time seconds for $service to initialize..."
    for ((i=wait_time; i>0; i--)); do
        printf "\r${YELLOW}⏳${NC} $i seconds remaining... "
        sleep 1
    done
    echo -e "\r${GREEN}✓${NC} Ready to proceed"
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! docker ps &> /dev/null; then
        print_error "Docker daemon is not running"
        exit 1
    fi
    
    print_success "Docker is available"
}

check_docker_compose() {
    if ! command -v docker &> /dev/null || ! command -v docker compose &> /dev/null; then
        print_error "Docker Compose is not installed or not in PATH"
        exit 1
    fi
    
    print_success "Docker Compose is available"
}

create_data_directories() {
    print_step "Creating data directories"
    
    mkdir -p ./data/hdfs/{namenode,datanode1,datanode2,historyserver}
    mkdir -p ./data/metastore-postgres
    mkdir -p ./workdir
    
    print_success "Data directories created"
}

################################################################################
# Main Startup Sequence
################################################################################

main() {
    clear
    
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║   HADOOP & HIVE CLUSTER STARTUP SCRIPT                        ║"
    echo "║   Version: 1.0                                                ║"
    echo "║   Starting all services in dependency order...               ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # Pre-flight checks
    print_header "PHASE 0: Pre-flight Checks"
    
    check_docker
    check_docker_compose
    create_data_directories

    # Phase 1: Core Infrastructure
    print_header "PHASE 1: Coordination Service (ZooKeeper)"
    
    print_step "Starting ZooKeeper..."
    docker compose up -d zookeeper
    wait_for_service "ZooKeeper" 5
    print_success "ZooKeeper started"

    # Phase 2: HDFS
    print_header "PHASE 2: HDFS Storage Layer"
    
    print_step "Starting NameNode..."
    docker compose up -d namenode
    wait_for_service "NameNode" 10
    print_success "NameNode started"

    print_step "Starting DataNodes (datanode1, datanode2)..."
    docker compose up -d datanode1 datanode2
    wait_for_service "DataNodes" 10
    print_success "DataNodes started"

    # Phase 3: YARN
    print_header "PHASE 3: YARN Compute Layer"
    
    print_step "Starting ResourceManager..."
    docker compose up -d resourcemanager
    wait_for_service "ResourceManager" 5
    print_success "ResourceManager started"

    print_step "Starting NodeManager..."
    docker compose up -d nodemanager1
    wait_for_service "NodeManager" 5
    print_success "NodeManager started"

    print_step "Starting JobHistory Server..."
    docker compose up -d historyserver
    wait_for_service "JobHistory Server" 5
    print_success "JobHistory Server started"

    # Phase 4: CLI Tools
    print_header "PHASE 4: Interactive CLI Tools"
    
    print_step "Starting Hadoop CLI..."
    docker compose up -d hadoop-cli
    print_success "Hadoop CLI started"

    # Phase 5: Hive
    print_header "PHASE 5: Hive SQL Engine"
    
    print_step "Starting Hive Metastore Database (PostgreSQL)..."
    docker compose up -d hive-metastore-db
    wait_for_service "PostgreSQL" 10
    print_success "PostgreSQL started"

    print_step "Starting Hive Metastore Service..."
    docker compose up -d hive-metastore
    wait_for_service "Hive Metastore" 15
    print_success "Hive Metastore started"

    print_step "Starting HiveServer2..."
    docker compose up -d hive-server
    wait_for_service "HiveServer2" 10
    print_success "HiveServer2 started"

    print_step "Starting Hive CLI..."
    docker compose up -d hive-cli
    print_success "Hive CLI started"

    # Final status
    print_header "STARTUP COMPLETE ✓"

    echo -e "${GREEN}All services have been started successfully!${NC}\n"

    echo "Verifying cluster status..."
    echo ""
    docker compose ps
    echo ""

    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🎉 CLUSTER IS READY!${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"

    echo "Access the cluster dashboards:"
    echo -e "  ${BLUE}NameNode UI${NC}:              http://localhost:9870"
    echo -e "  ${BLUE}ResourceManager UI${NC}:       http://localhost:8088"
    echo -e "  ${BLUE}DataNode1 UI${NC}:             http://localhost:9864"
    echo -e "  ${BLUE}DataNode2 UI${NC}:             http://localhost:9865"
    echo -e "  ${BLUE}NodeManager UI${NC}:           http://localhost:8042"
    echo -e "  ${BLUE}JobHistory UI${NC}:            http://localhost:8188"
    echo ""

    echo "Quick commands:"
    echo -e "  ${BLUE}Validate cluster health${NC}:    ./scripts/validate-cluster.sh"
    echo -e "  ${BLUE}Open Hadoop CLI${NC}:            docker exec -it hadoop-cli bash"
    echo -e "  ${BLUE}Open Hive CLI${NC}:              docker exec -it hive-cli bash"
    echo -e "  ${BLUE}View logs${NC}:                  docker compose logs -f <service>"
    echo -e "  ${BLUE}Stop cluster${NC}:               ./scripts/stop-cluster.sh"
    echo ""

    echo "Next steps:"
    echo "  1. Run validation script: ./scripts/validate-cluster.sh"
    echo "  2. Test HDFS: docker exec -it hadoop-cli hdfs dfs -ls /"
    echo "  3. Query Hive: docker exec -it hive-cli beeline -u \"jdbc:hive2://hive-server:10000/\""
    echo ""
}

# Execute main function
main
