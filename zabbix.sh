#!/bin/bash

# Zabbix Standalone Installation Script
# Install Zabbix with Docker and Nginx SSL

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_banner() {
    clear
    print_color $CYAN "======================================"
    print_color $CYAN "     🌐 Zabbix Installation 🌐"
    print_color $CYAN "======================================"
    print_color $YELLOW "    Network Monitoring Platform"
    print_color $CYAN "======================================"
    echo
}

check_prerequisites() {
    print_color $BLUE "🔍 Checking prerequisites..."
    
    if [ "$EUID" -ne 0 ]; then
        print_color $RED "❌ Please run as root or with sudo"
        exit 1
    fi
    
    # Check system requirements
    TOTAL_RAM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    if [ "$TOTAL_RAM" -lt 2048 ]; then
        print_color $YELLOW "⚠️  Warning: Zabbix recommends at least 2GB RAM. Current: ${TOTAL_RAM}MB"
        read -p "Do you want to continue anyway? (y/N): " CONTINUE
        if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Install Docker if not present
    if ! command -v docker &> /dev/null; then
        print_color $YELLOW "📦 Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        systemctl start docker
        systemctl enable docker
        rm get-docker.sh
    fi
    
    # Install Docker Compose if not present
    if ! command -v docker-compose &> /dev/null; then
        print_color $YELLOW "📦 Installing Docker Compose..."
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
    
    # Install Nginx if not present
    if ! command -v nginx &> /dev/null; then
        print_color $YELLOW "📦 Installing Nginx..."
        apt update
        apt install -y nginx
        systemctl start nginx
        systemctl enable nginx
    fi
    
    # Install Certbot if not present
    if ! command -v certbot &> /dev/null; then
        print_color $YELLOW "📦 Installing Certbot..."
        apt update
        apt install -y certbot python3-certbot-nginx
    fi
    
    print_color $GREEN "✅ Prerequisites ready!"
}

get_configuration() {
    print_banner
    print_color $YELLOW "🌐 Configuration Setup"
    echo
    
    # Get domain
    read -p "Enter domain for Zabbix (e.g., zabbix.yourdomain.com): " ZABBIX_DOMAIN
    if [ -z "$ZABBIX_DOMAIN" ]; then
        print_color $RED "❌ Domain cannot be empty"
        get_configuration
    fi
    
    # Get email for SSL
    read -p "Enter email for SSL certificate: " SSL_EMAIL
    if [ -z "$SSL_EMAIL" ]; then
        print_color $RED "❌ Email cannot be empty"
        get_configuration
    fi
    
    # Get database credentials
    read -p "Enter MySQL root password: " MYSQL_ROOT_PASSWORD
    if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
        print_color $RED "❌ MySQL root password cannot be empty"
        get_configuration
    fi
    
    read -p "Enter Zabbix database password: " MYSQL_PASSWORD
    if [ -z "$MYSQL_PASSWORD" ]; then
        print_color $RED "❌ Zabbix database password cannot be empty"
        get_configuration
    fi
    
    # Check port conflicts
    ZABBIX_WEB_PORT=8080
    ZABBIX_SERVER_PORT=10051
    MYSQL_PORT=3306
    
    while netstat -tlnp | grep ":$ZABBIX_WEB_PORT " > /dev/null 2>&1; do
        ZABBIX_WEB_PORT=$((ZABBIX_WEB_PORT + 1))
    done
    
    while netstat -tlnp | grep ":$ZABBIX_SERVER_PORT " > /dev/null 2>&1; do
        ZABBIX_SERVER_PORT=$((ZABBIX_SERVER_PORT + 1))
    done
    
    while netstat -tlnp | grep ":$MYSQL_PORT " > /dev/null 2>&1; do
        MYSQL_PORT=$((MYSQL_PORT + 1))
    done
    
    print_color $GREEN "✅ Configuration complete!"
    print_color $BLUE "   Domain: $ZABBIX_DOMAIN"
    print_color $BLUE "   Web Port: $ZABBIX_WEB_PORT"
    print_color $BLUE "   Server Port: $ZABBIX_SERVER_PORT"
    print_color $BLUE "   MySQL Port: $MYSQL_PORT"
    sleep 2
}

install_zabbix() {
    print_color $BLUE "📁 Creating directory structure..."
    mkdir -p /opt/zabbix-docker/{mysql-data,zabbix-scripts,zabbix-modules,zabbix-enc}
    
    cd /opt/zabbix-docker
    
    print_color $BLUE "🐳 Creating Docker Compose configuration..."
    cat > docker-compose.yml << EOF
version: '3.8'

services:
  mysql-server:
    image: mysql:8.0
    container_name: zabbix-mysql
    restart: unless-stopped
    ports:
      - "127.0.0.1:${MYSQL_PORT}:3306"
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
      - MYSQL_DATABASE=zabbix
      - MYSQL_USER=zabbix
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
      - MYSQL_CHARACTER_SET_SERVER=utf8
      - MYSQL_COLLATION_SERVER=utf8_bin
    volumes:
      - ./mysql-data:/var/lib/mysql
    networks:
      - zabbix-network
    command:
      - mysqld
      - --character-set-server=utf8
      - --collation-server=utf8_bin
      - --default-authentication-plugin=mysql_native_password

  zabbix-server:
    image: zabbix/zabbix-server-mysql:alpine-6.4-latest
    container_name: zabbix-server
    restart: unless-stopped
    ports:
      - "${ZABBIX_SERVER_PORT}:10051"
    environment:
      - DB_SERVER_HOST=mysql-server
      - MYSQL_DATABASE=zabbix
      - MYSQL_USER=zabbix
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
      - ZBX_ENABLE_SNMP_TRAPS=true
      - ZBX_STARTPREPROCESSORS=3
      - ZBX_STARTPOLLERSUNREACHABLE=1
      - ZBX_STARTTRAPPERS=5
      - ZBX_STARTPINGERS=1
      - ZBX_STARTDISCOVERERS=1
      - ZBX_STARTHTTPPOLLERS=1
    volumes:
      - ./zabbix-scripts:/usr/lib/zabbix/alertscripts:ro
      - ./zabbix-modules:/var/lib/zabbix/modules:ro
      - ./zabbix-enc:/var/lib/zabbix/enc:ro
    depends_on:
      - mysql-server
    networks:
      - zabbix-network

  zabbix-web:
    image: zabbix/zabbix-web-apache-mysql:alpine-6.4-latest
    container_name: zabbix-web
    restart: unless-stopped
    ports:
      - "127.0.0.1:${ZABBIX_WEB_PORT}:8080"
    environment:
      - ZBX_SERVER_HOST=zabbix-server
      - DB_SERVER_HOST=mysql-server
      - MYSQL_DATABASE=zabbix
      - MYSQL_USER=zabbix
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
      - PHP_TZ=UTC
      - ZBX_SERVER_NAME=Zabbix Server
    depends_on:
      - mysql-server
      - zabbix-server
    networks:
      - zabbix-network

  zabbix-agent:
    image: zabbix/zabbix-agent:alpine-6.4-latest
    container_name: zabbix-agent
    restart: unless-stopped
    privileged: true
    pid: "host"
    environment:
      - ZBX_HOSTNAME=zabbix-server
      - ZBX_SERVER_HOST=zabbix-server
      - ZBX_SERVER_PORT=10051
      - ZBX_PASSIVE_ALLOW=true
      - ZBX_ACTIVE_ALLOW=true
    volumes:
      - /proc:/proc:ro
      - /sys:/sys:ro
      - /dev:/dev:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    depends_on:
      - zabbix-server
    networks:
      - zabbix-network

networks:
  zabbix-network:
    driver: bridge
EOF

    cat > .env << EOF
ZABBIX_DOMAIN=${ZABBIX_DOMAIN}
ZABBIX_WEB_PORT=${ZABBIX_WEB_PORT}
ZABBIX_SERVER_PORT=${ZABBIX_SERVER_PORT}
MYSQL_PORT=${MYSQL_PORT}
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
MYSQL_PASSWORD=${MYSQL_PASSWORD}
SSL_EMAIL=${SSL_EMAIL}
EOF

    print_color $BLUE "🚀 Starting Zabbix stack..."
    docker-compose up -d
    
    print_color $YELLOW "⏳ Waiting for database initialization (this may take several minutes)..."
    sleep 120
    
    # Check if services are running
    if docker-compose ps | grep -q "zabbix-server.*Up" && docker-compose ps | grep -q "zabbix-web.*Up" && docker-compose ps | grep -q "zabbix-mysql.*Up"; then
        print_color $GREEN "✅ Zabbix stack is running"
        
        local_test=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:${ZABBIX_WEB_PORT}/ 2>/dev/null || echo "000")
        if [ "$local_test" = "200" ] || [ "$local_test" = "302" ]; then
            print_color $GREEN "✅ Zabbix web interface is responding locally ($local_test)"
        else
            print_color $YELLOW "⚠️  Zabbix web interface response: $local_test (may need more time to initialize)"
        fi
    else
        print_color $RED "❌ Some Zabbix services failed to start"
        docker-compose logs --tail=50
        exit 1
    fi
}

configure_nginx() {
    print_color $BLUE "🌐 Configuring Nginx..."
    
    # Initial HTTP configuration
    cat > /etc/nginx/sites-available/${ZABBIX_DOMAIN} << EOF
server {
    listen 80;
    server_name ${ZABBIX_DOMAIN};
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/${ZABBIX_DOMAIN} /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx
    
    print_color $BLUE "🔒 Obtaining SSL certificate..."
    certbot --nginx -d ${ZABBIX_DOMAIN} --email ${SSL_EMAIL} --agree-tos --non-interactive --redirect
    
    # Final HTTPS configuration
    cat > /etc/nginx/sites-available/${ZABBIX_DOMAIN} << EOF
server {
    listen 80;
    server_name ${ZABBIX_DOMAIN};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${ZABBIX_DOMAIN};

    ssl_certificate /etc/letsencrypt/live/${ZABBIX_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${ZABBIX_DOMAIN}/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_session_timeout 1d;

    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-XSS-Protection "1; mode=block";

    access_log /var/log/nginx/${ZABBIX_DOMAIN}_access.log;
    error_log /var/log/nginx/${ZABBIX_DOMAIN}_error.log;

    client_max_body_size 100M;
    proxy_connect_timeout 300s;
    proxy_send_timeout 300s;
    proxy_read_timeout 300s;

    location / {
        proxy_pass http://127.0.0.1:${ZABBIX_WEB_PORT};
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$server_name;
        proxy_redirect off;
        
        proxy_buffering off;
        proxy_request_buffering off;
    }

    location ~ \.php\$ {
        proxy_pass http://127.0.0.1:${ZABBIX_WEB_PORT};
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
        
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }

    location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg)\$ {
        proxy_pass http://127.0.0.1:${ZABBIX_WEB_PORT};
        proxy_set_header Host \$http_host;
        
        expires 1d;
        add_header Cache-Control "public";
    }
}
EOF

    nginx -t && systemctl reload nginx
    print_color $GREEN "✅ Nginx configured with SSL"
}

create_management_script() {
    print_color $BLUE "📝 Creating management script..."
    cat > /opt/zabbix-docker/manage-zabbix.sh << 'EOF'
#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

case "$1" in
    start)
        echo "Starting Zabbix stack..."
        docker-compose up -d
        ;;
    stop)
        echo "Stopping Zabbix stack..."
        docker-compose down
        ;;
    restart)
        echo "Restarting Zabbix stack..."
        docker-compose restart
        ;;
    logs)
        service=${2:-}
        if [ -z "$service" ]; then
            echo "Showing all logs..."
            docker-compose logs -f
        else
            case $service in
                server|srv)
                    docker-compose logs -f zabbix-server
                    ;;
                web|www)
                    docker-compose logs -f zabbix-web
                    ;;
                mysql|db)
                    docker-compose logs -f mysql-server
                    ;;
                agent)
                    docker-compose logs -f zabbix-agent
                    ;;
                *)
                    echo "Unknown service. Use: server, web, mysql, or agent"
                    ;;
            esac
        fi
        ;;
    status)
        echo "Zabbix stack status:"
        docker-compose ps
        echo
        echo "Service URLs:"
        echo "Zabbix Web: https://$(grep ZABBIX_DOMAIN .env | cut -d= -f2)/"
        echo "Server Port: $(grep ZABBIX_SERVER_PORT .env | cut -d= -f2)"
        ;;
    backup)
        echo "Creating backup..."
        docker-compose exec mysql-server mysqldump -u root -p$(grep MYSQL_ROOT_PASSWORD .env | cut -d= -f2) zabbix > zabbix_backup_$(date +%Y%m%d_%H%M%S).sql
        tar -czf "zabbix-backup-$(date +%Y%m%d-%H%M%S).tar.gz" mysql-data zabbix_backup_*.sql
        rm zabbix_backup_*.sql
        echo "Backup created"
        ;;
    update)
        echo "Updating Zabbix stack..."
        docker-compose pull
        docker-compose up -d
        ;;
    mysql)
        echo "Connecting to MySQL..."
        docker-compose exec mysql-server mysql -u root -p$(grep MYSQL_ROOT_PASSWORD .env | cut -d= -f2) zabbix
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|logs [service]|status|backup|update|mysql}"
        echo "Available log services: server, web, mysql, agent"
        exit 1
        ;;
esac
EOF

    chmod +x /opt/zabbix-docker/manage-zabbix.sh
}

# Main installation flow
main() {
    print_banner
    check_prerequisites
    get_configuration
    install_zabbix
    configure_nginx
    create_management_script
    
    print_color $GREEN "✅ Zabbix installation completed!"
    echo
    print_color $CYAN "======================================"
    print_color $CYAN "    Installation Complete!"
    print_color $CYAN "======================================"
    echo
    print_color $YELLOW "📍 Access Information:"
    print_color $BLUE "   URL: https://${ZABBIX_DOMAIN}"
    print_color $BLUE "   Username: Admin"
    print_color $BLUE "   Password: zabbix"
    print_color $BLUE "   Server Port: ${ZABBIX_SERVER_PORT}"
    echo
    print_color $YELLOW "🔧 Management Commands:"
    print_color $BLUE "   /opt/zabbix-docker/manage-zabbix.sh start"
    print_color $BLUE "   /opt/zabbix-docker/manage-zabbix.sh stop"
    print_color $BLUE "   /opt/zabbix-docker/manage-zabbix.sh restart"
    print_color $BLUE "   /opt/zabbix-docker/manage-zabbix.sh logs [service]"
    print_color $BLUE "   /opt/zabbix-docker/manage-zabbix.sh status"
    print_color $BLUE "   /opt/zabbix-docker/manage-zabbix.sh backup"
    print_color $BLUE "   /opt/zabbix-docker/manage-zabbix.sh mysql"
    echo
    print_color $YELLOW "📁 Configuration Location:"
    print_color $BLUE "   /opt/zabbix-docker/"
    echo
    print_color $YELLOW "🔧 Next Steps:"
    print_color $BLUE "   1. Access Zabbix at https://${ZABBIX_DOMAIN}"
    print_color $BLUE "   2. Login with Admin/zabbix"
    print_color $BLUE "   3. Change default password immediately"
    print_color $BLUE "   4. Configure monitoring hosts and templates"
    echo
    print_color $GREEN "🌐 Access Zabbix at: https://${ZABBIX_DOMAIN}"
    print_color $YELLOW "📁 Script Developer:"
    print_color $YELLOW "📁 DefendX1:"
    print_color $YELLOW "📁 https://defendx1.com/:"
}

# Run main function
main "$@"
