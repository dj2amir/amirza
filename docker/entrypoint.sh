#!/bin/bash
set -e

echo "=== Mirza Bot Docker Entrypoint ==="

# Validate required environment variables
for var in DB_HOST DB_NAME DB_USER DB_PASS TELEGRAM_TOKEN ADMIN_ID DOMAIN BOT_USERNAME; do
    eval val=\$$var
    if [ -z "$val" ]; then
        echo "ERROR: Required environment variable $var is not set."
        exit 1
    fi
done

# Proxy status
if [ -n "$TG_PROXY" ]; then
    masked="${TG_PROXY:0:10}...${TG_PROXY: -3}"
    echo "TG_PROXY is set: ${masked}"
else
    echo "TG_PROXY is not set (direct connection)"
fi

echo "Waiting for MySQL to be ready..."
until php -r "
try {
    new PDO('mysql:host=${DB_HOST};charset=utf8mb4', '${DB_USER}', '${DB_PASS}');
    exit(0);
} catch (PDOException \$e) {
    exit(1);
}
" 2>/dev/null; do
    echo "  MySQL not ready, retrying in 3s..."
    sleep 3
done
echo "MySQL is ready."

# Generate secret token for webhook validation
SECRET_TOKEN="${WEBHOOK_SECRET_TOKEN:-$(openssl rand -base64 10 | tr -dc 'a-zA-Z0-9' | cut -c1-8)}"
echo "Webhook secret token: ${SECRET_TOKEN}"

echo "Generating config.php..."
cat > /var/www/html/config.php << 'PHPEOF'
<?php
// This variable added for high load panels which their response time is long and bot can't communicate with online panel!
// null for default settings
$request_exec_timeout = null;
$dbhost = 'DBHOST_PLACEHOLDER';
$dbname = 'DBNAME_PLACEHOLDER';
$usernamedb = 'DBUSER_PLACEHOLDER';
$passworddb = 'DBPASS_PLACEHOLDER';
$connect = mysqli_connect($dbhost, $usernamedb, $passworddb, $dbname);
if ($connect->connect_error) { die("error" . $connect->connect_error); }
mysqli_set_charset($connect, "utf8mb4");
$options = [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    PDO::ATTR_EMULATE_PREPARES => false,
];
$dsn = "mysql:host=$dbhost;dbname=$dbname;charset=utf8mb4";
try {
    $pdo = new PDO($dsn, $usernamedb, $passworddb, $options);
} catch (\PDOException $e) {
    error_log("Database connection failed: " . $e->getMessage());
    die("error: database connection failed");
}
$secrettoken = 'SECRET_TOKEN_PLACEHOLDER';
$APIKEY = 'TELEGRAM_TOKEN_PLACEHOLDER';
$adminnumber = 'ADMIN_ID_PLACEHOLDER';
$domainhosts = 'DOMAIN_PLACEHOLDER';
$usernamebot = 'BOT_USERNAME_PLACEHOLDER';
?>
PHPEOF

sed -i "s|DBHOST_PLACEHOLDER|${DB_HOST}|g" /var/www/html/config.php
sed -i "s|DBNAME_PLACEHOLDER|${DB_NAME}|g" /var/www/html/config.php
sed -i "s|DBUSER_PLACEHOLDER|${DB_USER}|g" /var/www/html/config.php
sed -i "s|DBPASS_PLACEHOLDER|${DB_PASS}|g" /var/www/html/config.php
sed -i "s|SECRET_TOKEN_PLACEHOLDER|${SECRET_TOKEN}|g" /var/www/html/config.php
sed -i "s|TELEGRAM_TOKEN_PLACEHOLDER|${TELEGRAM_TOKEN}|g" /var/www/html/config.php
sed -i "s|ADMIN_ID_PLACEHOLDER|${ADMIN_ID}|g" /var/www/html/config.php
sed -i "s|DOMAIN_PLACEHOLDER|${DOMAIN}|g" /var/www/html/config.php
sed -i "s|BOT_USERNAME_PLACEHOLDER|${BOT_USERNAME}|g" /var/www/html/config.php

chown www-data:www-data /var/www/html/config.php
chmod 640 /var/www/html/config.php

mkdir -p /var/www/html/storage/cache
chown -R www-data:www-data /var/www/html/storage

echo "Initializing database tables..."
php /var/www/html/table.php 2>/dev/null || echo "Warning: table.php initialization skipped (tables may already exist)"

echo "Testing connection to Telegram API..."
PROXY_OPT=""
if [ -n "$TG_PROXY" ]; then
    PROXY_OPT="--proxy $TG_PROXY"
    echo "Using proxy: $TG_PROXY"
fi

CURL_OUTPUT=$(curl -s $PROXY_OPT --max-time 10 "https://api.telegram.org/bot${TELEGRAM_TOKEN}/getMe" 2>&1)
CURL_EXIT=$?
if [ $CURL_EXIT -ne 0 ]; then
    echo "ERROR: Cannot reach Telegram API (curl exit code: ${CURL_EXIT})"
    echo "curl output: ${CURL_OUTPUT}"
    if [ -n "$TG_PROXY" ]; then
        echo "TIP: Check if your proxy is reachable. Test with: curl -x ${TG_PROXY} https://api.telegram.org"
    else
        echo "TIP: Telegram is blocked. Set TG_PROXY in docker/.env (e.g., socks5://host:port)"
    fi
    exit 1
fi
echo "Telegram API is reachable."

echo "Setting Telegram webhook..."
WEBHOOK_URL="https://${DOMAIN}/index.php"
WEBHOOK_RESPONSE=$(curl -s $PROXY_OPT -F "url=${WEBHOOK_URL}" -F "secret_token=${SECRET_TOKEN}" "https://api.telegram.org/bot${TELEGRAM_TOKEN}/setWebhook" 2>&1)
WEBHOOK_EXIT=$?
if [ $WEBHOOK_EXIT -ne 0 ]; then
    echo "ERROR: Webhook setup failed (curl exit code: ${WEBHOOK_EXIT})"
    echo "curl output: ${WEBHOOK_RESPONSE}"
    exit 1
fi
if echo "$WEBHOOK_RESPONSE" | grep -q '"ok":true'; then
    echo "Webhook set successfully: ${WEBHOOK_URL}"
else
    echo "ERROR: Webhook API returned error:"
    echo "${WEBHOOK_RESPONSE}"
    echo "You can set it manually later via: curl -F 'url=https://YOUR_DOMAIN/index.php' -F 'secret_token=YOUR_TOKEN' https://api.telegram.org/botYOUR_TOKEN/setWebhook"
    exit 1
fi

echo "Sending welcome message to admin..."
curl -s $PROXY_OPT -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d chat_id="${ADMIN_ID}" \
    -d text="The Mirza bot is installed and running!" > /dev/null 2>&1 || true

echo "Starting services..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
