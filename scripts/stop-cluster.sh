#!/bin/bash

################################################################################
# Hadoop & Hive Cluster Shutdown Script
# Purpose: Safely stop all services and optionally clean up data
# Usage: ./stop-cluster.sh [--full] [--force]
# Options:
#   --full   : Remove all containers AND delete data volumes
#   --force  : Force stop without waiting (no graceful shutdown)
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Options
FULL_CLEANUP=false
FORCE_STOP=false

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

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

confirm() {
    local prompt="$1"
    local response
    
    echo -e "${YELLOW}$prompt${NC} (yes/no): "
    read -r response
    
    if [[ "$response" == "yes" || "$response" == "y" ]]; then
        return 0
    else
        return 1
    fi
}

################################################################################
# Shutdown Functions
################################################################################

stop_cluster() {
    print_header "Stopping Cluster Services"

    if [ "$FORCE_STOP" = true ]; then
        print_warning "Force stopping containers (may cause data loss)..."
        docker compose kill
    else
        print_step "Gracefully stopping containers..."
        docker compose stop
    fi

    print_success "All containers stopped"
}

remove_containers() {
    print_header "Removing Containers"

    print_step "Removing container instances..."
    docker compose rm -f
    
    print_success "Containers removed"
}

remove_volumes() {
    print_header "Removing Data Volumes"

    if confirm "This will DELETE ALL DATA in HDFS and Hive. Continue?"; then
        print_warning "Removing data volumes..."
        docker compose down -v
        print_success "Volumes removed"
    else
        print_info "Data volumes preserved"
    fi
}

clean_data_directory() {
    print_header "Cleaning Data Directory"

    if [ -d "./data" ]; then
        if confirm "This will DELETE all files in ./data directory. Continue?"; then
            print_warning "Removing data directory contents..."
            rm -rf ./data/*
            print_success "Data directory cleaned"
        else
            print_info "Data directory preserved"
        fi
    else
        print_info "Data directory not found"
    fi
}

verify_stopped() {
    print_header "Verification"

    print_step "Checking container status..."
    
    local container_count=$(docker compose ps --services | wc -l)
    
    if [ "$container_count" -eq 0 ]; then
        print_success "All containers have been stopped"
    else
        docker compose ps
        print_warning "Some containers may still be running"
    fi
}

show_usage() {
    echo -e "${BLUE}Usage: $0 [OPTIONS]${NC}"
    echo ""
    echo "Options:"
    echo "  --full     Remove containers AND delete all data volumes"
    echo "  --force    Force stop containers immediately (no graceful shutdown)"
    echo "  --help     Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Gracefully stop (keep data)"
    echo "  $0"
    echo ""
    echo "  # Stop and remove containers (keep data)"
    echo "  $0 --force"
    echo ""
    echo "  # Full cleanup (delete everything)"
    echo "  $0 --full"
    echo ""
}

################################################################################
# Parse Arguments
################################################################################

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --full)
                FULL_CLEANUP=true
                shift
                ;;
            --force)
                FORCE_STOP=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

################################################################################
# Main Execution
################################################################################

main() {
    clear
    
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║   HADOOP & HIVE CLUSTER SHUTDOWN SCRIPT                       ║"
    echo "║   Version: 1.0                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi

    # Parse command line arguments
    parse_arguments "$@"

    # Show shutdown plan
    print_header "Shutdown Plan"
    
    echo "Configuration:"
    echo -e "  ${BLUE}Full cleanup${NC}:   $FULL_CLEANUP"
    echo -e "  ${BLUE}Force stop${NC}:     $FORCE_STOP"
    echo ""

    if [ "$FULL_CLEANUP" = true ]; then
        echo -e "${YELLOW}⚠ WARNING: Full cleanup will DELETE ALL DATA!${NC}"
        echo ""
        echo "The following will be removed:"
        echo "  • All running containers"
        echo "  • All data volumes"
        echo "  • HDFS data and metadata"
        echo "  • Hive database contents"
        echo "  • All configuration data"
        echo ""
    fi

    # Confirm shutdown
    if confirm "Proceed with shutdown?"; then
        print_success "Proceeding with shutdown"
    else
        print_info "Shutdown cancelled"
        exit 0
    fi

    echo ""

    # Execute shutdown sequence
    stop_cluster
    remove_containers

    if [ "$FULL_CLEANUP" = true ]; then
        remove_volumes
        clean_data_directory
    fi

    verify_stopped

    # Final status
    print_header "Shutdown Complete ✓"

    if [ "$FULL_CLEANUP" = true ]; then
        echo -e "${RED}All services, containers, and data have been removed.${NC}"
        echo -e "${YELLOW}To restart, run: ./scripts/start-cluster.sh${NC}"
    else
        echo -e "${GREEN}All services have been stopped gracefully.${NC}"
        echo -e "${YELLOW}Data has been preserved.${NC}"
        echo -e "${YELLOW}To restart, run: docker compose start${NC}"
    fi

    echo ""
    echo "Service status:"
    echo ""
    docker compose ps || echo "No containers running"
    echo ""
}

# Execute main function
parse_arguments "$@"
main
