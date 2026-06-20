# Mirza Bot Docker Deployment Guide

## Quick Start

```bash
# Clone the repository
git clone https://github.com/mahdiMGF2/mirzabot.git
cd mirzabot

# Create environment file
cp docker/.env.example docker/.env
# Edit docker/.env with your values

# Start services
docker compose up -d

# Check logs
docker compose logs -f app
```

## Environment Variables

| Variable | Description | Required |
|---|---|---|
| `DB_HOST` | MySQL host (default: `db`) | Yes |
| `DB_NAME` | Database name (default: `mirzaprobot`) | Yes |
| `DB_USER` | MySQL username | Yes |
| `DB_PASS` | MySQL password | Yes |
| `DB_ROOT_PASS` | MySQL root password | Yes |
| `TELEGRAM_TOKEN` | Telegram Bot API token | Yes |
| `ADMIN_ID` | Your Telegram user ID | Yes |
| `DOMAIN` | Your domain name (e.g., `bot.example.com`) | Yes |
| `BOT_USERNAME` | Telegram bot username (without @) | Yes |
| `WEBHOOK_SECRET_TOKEN` | Custom webhook secret (auto-generated if not set) | No |
| `TG_PROXY` | SOCKS5/HTTP proxy for Telegram API (e.g., `socks5://host:port`) | No |

## Services

| Service | Port | Description |
|---|---|---|
| app | 8080 | Main bot application |
| db | 3306 (internal) | MySQL 8.0 database |
| phpmyadmin | 8081 | Database management UI |

## Reverse Proxy Setup

For production, use a reverse proxy for SSL termination and domain routing.

### Option 1: Nginx

```nginx
server {
    listen 80;
    server_name bot.example.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name bot.example.com;

    ssl_certificate /etc/letsencrypt/live/bot.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/bot.example.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Option 2: Caddy

```caddy
bot.example.com {
    reverse_proxy localhost:8080
}
```

Caddy automatically handles SSL certificates.

### Option 3: Traefik

Add labels to docker compose.yml:

```yaml
services:
  app:
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.mirza.rule=Host(`bot.example.com`)"
      - "traefik.http.routers.mirza.entrypoints=websecure"
      - "traefik.http.routers.mirza.tls.certresolver=letsencrypt"
      - "traefik.http.services.mirza.loadbalancer.server.port=80"
```

## SSL Certificate Setup (Nginx)

```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx

# Get certificate
sudo certbot --nginx -d bot.example.com

# Auto-renewal is configured by default
sudo certbot renew --dry-run
```

## Persistent Data

Docker volumes preserve data across container restarts:

| Volume | Purpose |
|---|---|
| `db-data` | MySQL database files |
| `app-storage` | Bot cache and temp files |
| `app-data` | User data and balance files |

### Backup

```bash
# Backup database
docker compose exec db mysqldump -u root -p mirzaprobot > backup.sql

# Backup all volumes
docker run --rm -v mirzabot_db-data:/data -v $(pwd):/backup alpine tar czf /backup/db-data.tar.gz -C /data .
```

## Updating

```bash
# Pull latest changes
git pull

# Rebuild and restart
docker compose up -d --build
```

## Troubleshooting

### Bot not receiving updates

1. Check webhook: `curl https://api.telegram.org/botYOUR_TOKEN/getWebhookInfo`
2. Verify domain points to your server
3. Check SSL certificate is valid
4. Review app logs: `docker compose logs app`

### Database connection failed

1. Ensure MySQL is running: `docker compose ps`
2. Check credentials in `.env` match `docker compose.yml`
3. Wait for MySQL healthcheck to pass

### phpMyAdmin access

- URL: `http://localhost:8081`
- Username: `root`
- Password: Your `DB_ROOT_PASS` value

## Security Notes

- phpMyAdmin is exposed on port 8081 without SSL in development. For production, either:
  - Disable phpMyAdmin in docker compose.yml
  - Place it behind your reverse proxy with SSL
  - Use SSH tunnel: `ssh -L 8081:localhost:8081 your-server`
- The `config.php` file is generated at runtime and is not exposed in the Docker image
- Webhook secret token validates Telegram callback authenticity

## Localhost Proxy

If your SOCKS proxy listens on `127.0.0.1` (e.g., SSH tunnel), Docker containers can't reach it directly. Use socat on the host to forward:

```bash
# Find your Docker gateway IP
docker network inspect bridge | grep Gateway

# Start socat (replace 172.17.0.1 with your gateway IP)
socat TCP-LISTEN:20171,reuseaddr,fork,bind=172.17.0.1 TCP:127.0.0.1:20170 &
```

Then set in `docker/.env`:
```
TG_PROXY=socks5://172.17.0.1:20171
```

To make it persistent, create `/etc/systemd/system/socat-proxy.service`:
```ini
[Unit]
Description=Socat proxy forwarder
After=network.target

[Service]
ExecStart=/usr/bin/socat TCP-LISTEN:20171,reuseaddr,fork,bind=0.0.0.0 TCP:127.0.0.1:20170
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable --now socat-proxy
```

## TODO

- `mysql_native_password` is deprecated in MySQL 8.0 and will be removed in MySQL 9.0. Migrate to `caching_sha2_password` when upgrading MySQL or PHP, which will require enabling SSL or public key retrieval in the PHP connection.
