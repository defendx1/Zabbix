# Zabbix Docker Installation Script

![Zabbix Logo](https://assets.zabbix.com/img/logo/zabbix_logo_500x131.png)

A comprehensive automated installation script for deploying Zabbix monitoring platform with Docker, Nginx reverse proxy, and SSL certificates.

## 🚀 Features

- **Automated Installation**: Complete Zabbix stack deployment with minimal user input
- **Docker-based**: Uses official Zabbix Docker images for easy management
- **SSL/HTTPS Support**: Automatic SSL certificate generation with Let's Encrypt
- **Nginx Reverse Proxy**: Professional web server configuration with security headers
- **MySQL Database**: Persistent data storage with optimized configuration
- **Management Scripts**: Built-in scripts for easy maintenance and monitoring
- **Security Hardened**: Includes security best practices and configurations
- **Multi-component Stack**: Includes Zabbix Server, Web UI, Agent, and MySQL

## 📋 Prerequisites

### System Requirements
- **OS**: Ubuntu 18.04+ / Debian 10+ / CentOS 7+
- **RAM**: Minimum 2GB (recommended 4GB+)
- **Disk Space**: Minimum 10GB free space
- **Network**: Public IP address with domain pointing to it
- **Privileges**: Root access or sudo privileges

### Required Ports
- **80**: HTTP (for SSL certificate validation)
- **443**: HTTPS (Nginx reverse proxy)
- **10051**: Zabbix Server (configurable)
- **3306**: MySQL (localhost only)

## 🛠 Installation

### Quick Start

1. **Clone the repository**:
   ```bash
   git clone https://github.com/defendx1/Zabbix.git
   cd Zabbix
   chmod +x install-zabbix.sh
   ```

   **Or download directly**:
   ```bash
   wget https://raw.githubusercontent.com/defendx1/Zabbix/main/install-zabbix.sh
   chmod +x install-zabbix.sh
   ```

2. **Run the installation**:
   ```bash
   sudo ./install-zabbix.sh
   ```

3. **Follow the prompts**:
   - Enter your domain name (e.g., `zabbix.yourdomain.com`)
   - Provide email for SSL certificate
   - Set MySQL root password
   - Set Zabbix database password

### Manual Installation Steps

The script automatically handles:
- ✅ Docker and Docker Compose installation
- ✅ Nginx web server installation
- ✅ Certbot for SSL certificates
- ✅ System requirements validation
- ✅ Port conflict resolution
- ✅ Directory structure creation
- ✅ Docker Compose configuration
- ✅ SSL certificate generation
- ✅ Nginx reverse proxy setup

## 🔧 Configuration

### Default Credentials
- **Username**: `Admin`
- **Password**: `zabbix`
- **⚠️ Important**: Change the default password immediately after first login

### Docker Services
The installation creates the following containers:
- `zabbix-mysql`: MySQL 8.0 database server
- `zabbix-server`: Zabbix Server with MySQL support
- `zabbix-web`: Zabbix Web UI with Apache
- `zabbix-agent`: Zabbix Agent for local monitoring

### File Structure
```
/opt/zabbix-docker/
├── docker-compose.yml      # Main Docker Compose configuration
├── .env                    # Environment variables
├── manage-zabbix.sh       # Management script
├── mysql-data/            # MySQL data persistence
├── zabbix-scripts/        # Custom alert scripts
├── zabbix-modules/        # Custom Zabbix modules
└── zabbix-enc/           # Encryption files
```

## 🎮 Management Commands

Use the built-in management script for easy operations:

```bash
cd /opt/zabbix-docker

# Start all services
./manage-zabbix.sh start

# Stop all services
./manage-zabbix.sh stop

# Restart all services
./manage-zabbix.sh restart

# View logs (all services)
./manage-zabbix.sh logs

# View specific service logs
./manage-zabbix.sh logs server   # Zabbix Server logs
./manage-zabbix.sh logs web      # Web UI logs
./manage-zabbix.sh logs mysql    # Database logs
./manage-zabbix.sh logs agent    # Agent logs

# Check status
./manage-zabbix.sh status

# Create backup
./manage-zabbix.sh backup

# Update containers
./manage-zabbix.sh update

# Connect to MySQL
./manage-zabbix.sh mysql
```

## 🔐 Security Features

### SSL/TLS Configuration
- **TLS 1.2/1.3** support only
- **HSTS** (HTTP Strict Transport Security) headers
- **Security headers**: X-Content-Type-Options, X-Frame-Options, X-XSS-Protection
- **Automatic HTTP to HTTPS** redirection

### Network Security
- MySQL accessible only from localhost
- Zabbix services isolated in Docker network
- Configurable port assignments to avoid conflicts

### File Permissions
- Proper file ownership and permissions
- Read-only mounts for security-sensitive directories

## 🛡️ Monitoring Setup

### Initial Configuration Steps

1. **Access Zabbix Web Interface**:
   - Navigate to `https://your-domain.com`
   - Login with `Admin` / `zabbix`

2. **Change Default Password**:
   - Go to User Settings → Change Password
   - Use a strong password

3. **Configure Hosts**:
   - Add your servers and devices to monitor
   - Apply appropriate templates

4. **Set Up Notifications**:
   - Configure email/SMS notifications
   - Create alert scripts in `/opt/zabbix-docker/zabbix-scripts/`

### Built-in Monitoring
The script automatically configures:
- **Self-monitoring**: Zabbix server monitors itself
- **System metrics**: CPU, memory, disk, network
- **Docker monitoring**: Container health and metrics

## 🔄 Backup and Restore

### Automated Backup
```bash
./manage-zabbix.sh backup
```
Creates timestamped backup including:
- MySQL database dump
- Configuration files
- Custom scripts and modules

### Manual Backup
```bash
# Database backup
docker-compose exec mysql-server mysqldump -u root -p zabbix > backup.sql

# Full backup
tar -czf zabbix-backup-$(date +%Y%m%d).tar.gz /opt/zabbix-docker/
```

### Restore Process
```bash
# Stop services
./manage-zabbix.sh stop

# Restore database
docker-compose exec mysql-server mysql -u root -p zabbix < backup.sql

# Restore files
tar -xzf zabbix-backup.tar.gz -C /

# Start services
./manage-zabbix.sh start
```

## 🚨 Troubleshooting

### Common Issues

**1. Services won't start**
```bash
# Check logs
./manage-zabbix.sh logs

# Check system resources
free -h
df -h
```

**2. SSL certificate issues**
```bash
# Renew certificate
certbot renew --nginx

# Check certificate status
certbot certificates
```

**3. Database connection errors**
```bash
# Check MySQL logs
./manage-zabbix.sh logs mysql

# Connect to database
./manage-zabbix.sh mysql
```

**4. Memory issues**
```bash
# Check container resources
docker stats

# Restart services
./manage-zabbix.sh restart
```

### Log Locations
- **Nginx**: `/var/log/nginx/`
- **Docker**: `docker-compose logs`
- **System**: `/var/log/syslog`

## 🔄 Updates and Maintenance

### Update Zabbix
```bash
cd /opt/zabbix-docker
./manage-zabbix.sh update
```

### SSL Certificate Renewal
Certificates auto-renew via cron. Manual renewal:
```bash
certbot renew --nginx
systemctl reload nginx
```

### System Maintenance
```bash
# Clean up Docker
docker system prune -f

# Update system packages
apt update && apt upgrade -y

# Check disk space
df -h /opt/zabbix-docker/
```

## 📊 Performance Tuning

### MySQL Optimization
Edit `/opt/zabbix-docker/docker-compose.yml`:
```yaml
environment:
  - MYSQL_INNODB_BUFFER_POOL_SIZE=512M
  - MYSQL_INNODB_LOG_FILE_SIZE=128M
```

### Zabbix Server Optimization
Adjust in docker-compose.yml:
```yaml
environment:
  - ZBX_STARTPREPROCESSORS=5
  - ZBX_STARTPOLLERSUNREACHABLE=2
  - ZBX_STARTTRAPPERS=10
```

## 🆘 Support and Resources

## 🔗 Resources & Links

### Project Resources
- **GitHub Repository**: [https://github.com/defendx1/Zabbix](https://github.com/defendx1/Zabbix)
- **Issues & Support**: [Report Issues](https://github.com/defendx1/Zabbix/issues)
- **Latest Releases**: [View Releases](https://github.com/defendx1/Zabbix/releases)

### Official Documentation
- [Zabbix Documentation](https://www.zabbix.com/documentation)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [Nginx Documentation](https://nginx.org/en/docs/)

### Community Support
- [Zabbix Community Forum](https://www.zabbix.com/forum)
- [DefendX1 Telegram](https://t.me/defendx1)

## 📄 License

This script is provided under the MIT License. See LICENSE file for details.

---

## 👨‍💻 Author & Contact

**Script Developer**: Sunil Kumar  
**Website**: [https://defendx1.com/](https://defendx1.com/)  
**Telegram**: [t.me/defendx1](https://t.me/defendx1)

### About DefendX1
DefendX1 specializes in cybersecurity solutions, infrastructure automation, and monitoring systems. Visit [defendx1.com](https://defendx1.com/) for more security tools and resources.

---

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository: [https://github.com/defendx1/Zabbix](https://github.com/defendx1/Zabbix)
2. Create a feature branch
3. Submit a pull request

## ⭐ Star This Project

If this script helped you, please consider starring the repository at [https://github.com/defendx1/Zabbix](https://github.com/defendx1/Zabbix)!

## 📥 Download & Repository

**GitHub Repository**: [https://github.com/defendx1/Zabbix](https://github.com/defendx1/Zabbix)

Clone or download the latest version:
```bash
git clone https://github.com/defendx1/Zabbix.git
```

---

**Last Updated**: June 2025  
**Version**: 1.0.0
