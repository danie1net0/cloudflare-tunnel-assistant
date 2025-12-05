#!/bin/bash

# Cloudflare Tunnel Assistant
# Interactive script for managing Cloudflare tunnels

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Cloudflared config directory
CLOUDFLARED_DIR="$HOME/.cloudflared"

print_header() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════╗"
    echo "║     Cloudflare Tunnel Assistant                ║"
    echo "╚════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_menu() {
    echo -e "${YELLOW}Choose an option:${NC}"
    echo ""
    echo "   1) Quick Tunnel (no authentication)"
    echo "   2) Login to Cloudflare"
    echo "   3) List tunnels"
    echo "   4) Create named tunnel"
    echo "   5) Route DNS"
    echo "   6) Create configuration file"
    echo "   7) Run tunnel (foreground)"
    echo "   8) Start tunnel (background)"
    echo "   9) Stop tunnel"
    echo "  10) Tunnels status"
    echo "  11) Delete tunnel"
    echo "   0) Exit"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}! $1${NC}"
}

print_info() {
    echo -e "${BLUE}→ $1${NC}"
}

check_cloudflared() {
    if ! command -v cloudflared &> /dev/null; then
        print_error "cloudflared is not installed."
        echo ""
        echo "Install with:"
        echo "  macOS:  brew install cloudflared"
        echo "  Linux:  See https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/"
        echo ""
        exit 1
    fi
}

press_enter() {
    echo ""
    read -p "Press Enter to continue..."
}

confirm() {
    read -p "$1 (y/N): " response
    [[ "$response" =~ ^[Yy]$ ]]
}

check_auth() {
    if [[ ! -f "$CLOUDFLARED_DIR/cert.pem" ]]; then
        print_error "You need to login first (option 2)."
        press_enter
        return 1
    fi
    return 0
}

get_tunnel_id() {
    local tunnel_name=$1
    cloudflared tunnel info "$tunnel_name" 2>/dev/null | grep -oE '[a-f0-9-]{36}' | head -1
}

check_credentials() {
    local tunnel_name=$1
    local tunnel_id=$(get_tunnel_id "$tunnel_name")

    if [[ -z "$tunnel_id" ]]; then
        print_error "Tunnel '$tunnel_name' not found."
        return 1
    fi

    local cred_file="$CLOUDFLARED_DIR/$tunnel_id.json"
    if [[ ! -f "$cred_file" ]]; then
        print_error "Credentials file not found: $cred_file"
        print_warning "This tunnel was probably created on another machine."
        print_info "Copy the credentials file from the original machine or recreate the tunnel."
        return 1
    fi
    return 0
}

# 1) Quick Tunnel
quick_tunnel() {
    print_header
    echo -e "${YELLOW}=== Quick Tunnel ===${NC}"
    echo ""
    echo "This will create a temporary tunnel without authentication."
    echo "The URL will change each time you run it."
    echo ""

    read -p "Local URL (e.g., http://localhost:3000): " local_url

    if [[ -z "$local_url" ]]; then
        print_error "URL cannot be empty."
        press_enter
        return
    fi

    echo ""
    print_info "Starting tunnel... (Ctrl+C to stop)"
    echo ""

    cloudflared tunnel --url "$local_url"
}

# 2) Login
cloudflare_login() {
    print_header
    echo -e "${YELLOW}=== Login to Cloudflare ===${NC}"
    echo ""

    if [[ -f "$CLOUDFLARED_DIR/cert.pem" ]]; then
        print_warning "You are already authenticated."
        if ! confirm "Do you want to reauthenticate?"; then
            return
        fi
    fi

    print_info "Opening browser for authentication..."
    cloudflared tunnel login

    if [[ -f "$CLOUDFLARED_DIR/cert.pem" ]]; then
        print_success "Authentication successful!"
    else
        print_error "Authentication failed."
    fi

    press_enter
}

# 3) List tunnels
list_tunnels() {
    print_header
    echo -e "${YELLOW}=== Existing Tunnels ===${NC}"
    echo ""

    check_auth || return

    cloudflared tunnel list

    press_enter
}

# 4) Create named tunnel
create_tunnel() {
    print_header
    echo -e "${YELLOW}=== Create Named Tunnel ===${NC}"
    echo ""

    check_auth || return

    read -p "Tunnel name: " tunnel_name

    if [[ -z "$tunnel_name" ]]; then
        print_error "Name cannot be empty."
        press_enter
        return
    fi

    echo ""
    print_info "Creating tunnel '$tunnel_name'..."
    echo ""

    cloudflared tunnel create "$tunnel_name"

    print_success "Tunnel created!"
    press_enter
}

# 5) Route DNS
route_dns() {
    print_header
    echo -e "${YELLOW}=== Route DNS ===${NC}"
    echo ""

    check_auth || return

    echo "Existing tunnels:"
    cloudflared tunnel list
    echo ""

    read -p "Tunnel name: " tunnel_name
    read -p "Full hostname (e.g., app.yourdomain.com): " hostname

    if [[ -z "$tunnel_name" ]] || [[ -z "$hostname" ]]; then
        print_error "Name and hostname are required."
        press_enter
        return
    fi

    echo ""
    print_info "Configuring DNS..."

    cloudflared tunnel route dns "$tunnel_name" "$hostname"

    print_success "DNS configured! $hostname → $tunnel_name"
    press_enter
}

# 6) Create configuration file
create_config() {
    print_header
    echo -e "${YELLOW}=== Create Configuration File ===${NC}"
    echo ""

    check_auth || return

    echo "Existing tunnels:"
    cloudflared tunnel list
    echo ""

    read -p "Tunnel name: " tunnel_name

    if [[ -z "$tunnel_name" ]]; then
        print_error "Name cannot be empty."
        press_enter
        return
    fi

    # Get tunnel UUID
    tunnel_info=$(cloudflared tunnel info "$tunnel_name" 2>/dev/null | head -5)
    tunnel_uuid=$(echo "$tunnel_info" | grep -oE '[a-f0-9-]{36}' | head -1)

    if [[ -z "$tunnel_uuid" ]]; then
        print_error "Could not find tunnel UUID."
        press_enter
        return
    fi

    echo ""
    read -r -p "How many routes? " route_count

    if [[ -z "$route_count" ]] || [[ "$route_count" -lt 1 ]]; then
        route_count=1
    fi

    routes=""
    for ((i=1; i<=route_count; i++)); do
        echo ""
        echo "Route $i:"
        read -r -p "  Hostname (e.g., app.yourdomain.com): " hostname

        if [[ -z "$hostname" ]]; then
            continue
        fi

        read -r -p "  Local service (e.g., http://localhost:3000): " service

        if [[ -z "$service" ]]; then
            service="http://localhost:80"
        fi

        routes+="  - hostname: $hostname
    service: $service
"
    done

    if [[ -z "$routes" ]]; then
        print_warning "No routes added. Adding default route only."
    fi

    config_file="$CLOUDFLARED_DIR/config.yml"

    cat > "$config_file" << EOF
tunnel: $tunnel_name
credentials-file: $CLOUDFLARED_DIR/$tunnel_uuid.json

ingress:
$routes  - service: http_status:404
EOF

    print_success "Configuration file created: $config_file"
    echo ""
    echo "Content:"
    echo "----------------------------------------"
    cat "$config_file"
    echo "----------------------------------------"

    press_enter
}

# 7) Run tunnel (foreground)
run_tunnel() {
    print_header
    echo -e "${YELLOW}=== Run Tunnel (Foreground) ===${NC}"
    echo ""

    check_auth || return

    echo "Existing tunnels:"
    cloudflared tunnel list
    echo ""

    read -p "Tunnel name: " tunnel_name

    if [[ -z "$tunnel_name" ]]; then
        print_error "Name cannot be empty."
        press_enter
        return
    fi

    if ! check_credentials "$tunnel_name"; then
        press_enter
        return
    fi

    echo ""
    read -p "Local URL (leave empty to use config.yml): " local_url

    echo ""
    print_info "Starting tunnel... (Ctrl+C to stop)"
    echo ""

    if [[ -n "$local_url" ]]; then
        cloudflared tunnel --url "$local_url" run "$tunnel_name"
    else
        cloudflared tunnel run "$tunnel_name"
    fi
}

# 8) Start tunnel (background)
start_tunnel_background() {
    print_header
    echo -e "${YELLOW}=== Start Tunnel (Background) ===${NC}"
    echo ""

    check_auth || return

    echo "Existing tunnels:"
    cloudflared tunnel list
    echo ""

    read -p "Tunnel name: " tunnel_name

    if [[ -z "$tunnel_name" ]]; then
        print_error "Name cannot be empty."
        press_enter
        return
    fi

    if ! check_credentials "$tunnel_name"; then
        press_enter
        return
    fi

    read -p "Local URL (leave empty to use config.yml): " local_url

    log_file="/tmp/cloudflared-$tunnel_name.log"
    pid_file="/tmp/cloudflared-$tunnel_name.pid"

    echo ""
    print_info "Starting tunnel in background..."

    if [[ -n "$local_url" ]]; then
        nohup cloudflared tunnel --url "$local_url" run "$tunnel_name" > "$log_file" 2>&1 &
    else
        nohup cloudflared tunnel run "$tunnel_name" > "$log_file" 2>&1 &
    fi

    echo $! > "$pid_file"

    sleep 2

    if ps -p $(cat "$pid_file") > /dev/null 2>&1; then
        print_success "Tunnel started! PID: $(cat $pid_file)"
        print_info "Log: $log_file"
    else
        print_error "Failed to start tunnel. Check log: $log_file"
    fi

    press_enter
}

# 9) Stop tunnel
stop_tunnel() {
    print_header
    echo -e "${YELLOW}=== Stop Tunnel ===${NC}"
    echo ""

    # List running tunnels
    echo "Running tunnel processes:"
    echo ""

    pids=$(pgrep -f "cloudflared tunnel" 2>/dev/null || true)

    if [[ -z "$pids" ]]; then
        print_warning "No running tunnels found."
        press_enter
        return
    fi

    ps aux | grep "cloudflared tunnel" | grep -v grep
    echo ""

    read -p "Tunnel name (or 'all' to stop all): " tunnel_name

    if [[ "$tunnel_name" == "all" ]]; then
        if confirm "Stop all tunnels?"; then
            pkill -f "cloudflared tunnel" || true
            print_success "All tunnels stopped."
        fi
    else
        pid_file="/tmp/cloudflared-$tunnel_name.pid"

        if [[ -f "$pid_file" ]]; then
            pid=$(cat "$pid_file")
            if ps -p "$pid" > /dev/null 2>&1; then
                kill "$pid"
                rm "$pid_file"
                print_success "Tunnel '$tunnel_name' stopped."
            else
                print_warning "Process not found. Cleaning up PID file."
                rm "$pid_file"
            fi
        else
            # Try to find by name
            pkill -f "cloudflared tunnel.*$tunnel_name" || print_warning "Tunnel not found."
        fi
    fi

    press_enter
}

# 10) Tunnels status
tunnels_status() {
    print_header
    echo -e "${YELLOW}=== Tunnels Status ===${NC}"
    echo ""

    check_auth || return

    echo "Registered tunnels:"
    echo "-------------------"
    cloudflared tunnel list
    echo ""

    echo "Running processes:"
    echo "------------------"
    ps aux | grep "cloudflared tunnel" | grep -v grep || echo "No running tunnels."
    echo ""

    echo "PID files:"
    echo "----------"
    ls -la /tmp/cloudflared-*.pid 2>/dev/null || echo "No PID files."

    press_enter
}

# 11) Delete tunnel
delete_tunnel() {
    print_header
    echo -e "${YELLOW}=== Delete Tunnel ===${NC}"
    echo ""

    check_auth || return

    echo "Existing tunnels:"
    cloudflared tunnel list
    echo ""

    read -p "Tunnel name to delete: " tunnel_name

    if [[ -z "$tunnel_name" ]]; then
        print_error "Name cannot be empty."
        press_enter
        return
    fi

    if confirm "Are you sure you want to delete '$tunnel_name'?"; then
        echo ""
        print_info "Deleting tunnel..."

        # Stop if running
        pkill -f "cloudflared tunnel.*$tunnel_name" 2>/dev/null || true

        cloudflared tunnel delete "$tunnel_name"

        print_success "Tunnel deleted!"
    else
        print_info "Operation cancelled."
    fi

    press_enter
}

# Main
main() {
    check_cloudflared

    while true; do
        print_header
        print_menu

        read -p "Option: " option

        case $option in
            1) quick_tunnel ;;
            2) cloudflare_login ;;
            3) list_tunnels ;;
            4) create_tunnel ;;
            5) route_dns ;;
            6) create_config ;;
            7) run_tunnel ;;
            8) start_tunnel_background ;;
            9) stop_tunnel ;;
            10) tunnels_status ;;
            11) delete_tunnel ;;
            0)
                echo ""
                print_info "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid option."
                press_enter
                ;;
        esac
    done
}

main
