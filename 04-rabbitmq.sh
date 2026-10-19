
#!/bin/bash

# Check root access
user_id=$(id -u)

if [ "$user_id" -ne 0 ]; then
    echo "Please run this script with sudo access."
    exit 1
fi

# Variables
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
logs_folder="/var/log/roboshop"
logs_file="${logs_folder}/$(basename "$0").log"

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

# Create log directory
mkdir -p "$logs_folder" || {
    echo "ERROR: Unable to create log directory: $logs_folder"
    exit 1
}

timestamp() {
    date "+%F %T"
}

# Validate command status
validate() {
    local status="$1"
    local message="$2"

    if [ "$status" -ne 0 ]; then
        echo -e "$(timestamp) [ERROR] ${message}...${R}FAILED${N}" | tee -a "$logs_file"
        echo "$(timestamp) [INFO] Script failed." | tee -a "$logs_file"
        exit 1
    else
        echo -e "$(timestamp) [INFO] ${message}...${G}SUCCESS${N}" | tee -a "$logs_file"
    fi
}

echo "$(timestamp) [INFO] ===== Script started execution =====" | tee -a "$logs_file"

# Verify RabbitMQ repository file
if [ ! -f "${SCRIPT_DIR}/rabbitmq.repo" ]; then
    echo "$(timestamp) [ERROR] rabbitmq.repo not found in ${SCRIPT_DIR}" | tee -a "$logs_file"
    exit 1
fi

# Copy RabbitMQ repository
cp "${SCRIPT_DIR}/rabbitmq.repo" /etc/yum.repos.d/rabbitmq.repo
validate $? "Adding RabbitMQ repository"

# Install Erlang and RabbitMQ
dnf install erlang rabbitmq-server -y >> "$logs_file" 2>&1
validate $? "Installing Erlang and RabbitMQ server"

# Enable RabbitMQ service
systemctl enable rabbitmq-server >> "$logs_file" 2>&1
validate $? "Enabling RabbitMQ server"

# Start RabbitMQ service
systemctl start rabbitmq-server >> "$logs_file" 2>&1
validate $? "Starting RabbitMQ server"

# Wait until RabbitMQ is ready
rabbitmqctl await_startup >> "$logs_file" 2>&1
validate $? "Waiting for RabbitMQ startup"

# Create Roboshop user only if it does not already exist
if rabbitmqctl list_users 2>> "$logs_file" | awk 'NR > 1 {print $1}' | grep -qx "roboshop"; then
    echo "$(timestamp) [INFO] RabbitMQ user roboshop already exists." | tee -a "$logs_file"
else
    rabbitmqctl add_user roboshop 'roboshop123' >> "$logs_file" 2>&1
    validate $? "Creating RabbitMQ user for Roboshop"
fi

# Set permissions
rabbitmqctl set_permissions -p / roboshop ".*" ".*" ".*" >> "$logs_file" 2>&1
validate $? "Setting permissions for Roboshop user"

# Completion
echo "$(timestamp) [INFO] Script completed in ${SECONDS} seconds." | tee -a "$logs_file"
echo "$(timestamp) [INFO] ===== Script completed successfully =====" | tee -a "$logs_file"
