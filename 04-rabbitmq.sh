
#!/bin/bash

USER_ID=$(id -u)

LOGS_FOLDER="/var/log/roboshop"
LOGS_FILE="${LOGS_FOLDER}/10-rabbitmq.log"

R="\e[31m"
G="\e[32m"
N="\e[0m"

if [ "$USER_ID" -ne 0 ]; then
    echo "Please run this script with sudo access."
    exit 1
fi

mkdir -p "$LOGS_FOLDER" || exit 1
touch "$LOGS_FILE" || exit 1

timestamp() {
    date "+%F %T"
}

validate() {
    local status=$1
    local message=$2

    if [ "$status" -ne 0 ]; then
        echo -e "$(timestamp) [ERROR] ${message}... ${R}FAILED${N}" |
            tee -a "$LOGS_FILE"
        echo "Check log file: $LOGS_FILE"
        exit 1
    else
        echo -e "$(timestamp) [INFO] ${message}... ${G}SUCCESS${N}" |
            tee -a "$LOGS_FILE"
    fi
}

echo "$(timestamp) [INFO] ===== RabbitMQ installation started =====" |
    tee -a "$LOGS_FILE"

# Find repository file alongside this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Copy repository configuration
cp "$SCRIPT_DIR/rabbitmq.repo" /etc/yum.repos.d/rabbitmq.repo \
    >> "$LOGS_FILE" 2>&1
validate $? "Adding RabbitMQ repository"

# Import official signing keys
rpm --import \
    https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-erlang.E495BB49CC4BBE5B.key \
    >> "$LOGS_FILE" 2>&1
validate $? "Importing Erlang signing key"

rpm --import \
    https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-server.9F4587F226208342.key \
    >> "$LOGS_FILE" 2>&1
validate $? "Importing RabbitMQ signing key"

# Refresh repository metadata
dnf clean all >> "$LOGS_FILE" 2>&1
dnf makecache --refresh >> "$LOGS_FILE" 2>&1
validate $? "Refreshing repository metadata"

# Install packages
dnf install -y erlang rabbitmq-server >> "$LOGS_FILE" 2>&1
validate $? "Installing Erlang and RabbitMQ server"

# Enable and start service
systemctl enable rabbitmq-server >> "$LOGS_FILE" 2>&1
validate $? "Enabling RabbitMQ service"

systemctl start rabbitmq-server >> "$LOGS_FILE" 2>&1
validate $? "Starting RabbitMQ service"

# Check service status
systemctl is-active --quiet rabbitmq-server
validate $? "Checking RabbitMQ service status"

# Create user if missing
if rabbitmqctl list_users 2>> "$LOGS_FILE" |
    awk '{print $1}' | grep -qx 'roboshop'; then
    echo "$(timestamp) [INFO] RoboShop user already exists" |
        tee -a "$LOGS_FILE"
else
    rabbitmqctl add_user roboshop 'roboshop123' \
        >> "$LOGS_FILE" 2>&1
    validate $? "Creating RoboShop RabbitMQ user"
fi

# Set permissions
rabbitmqctl set_permissions -p / roboshop '.*' '.*' '.*' \
    >> "$LOGS_FILE" 2>&1
validate $? "Setting RoboShop user permissions"

echo "$(timestamp) [INFO] ===== RabbitMQ installation completed =====" |
    tee -a "$LOGS_FILE"
