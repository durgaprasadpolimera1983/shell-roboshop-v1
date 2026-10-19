
#!/bin/bash

# Check root access
USER_ID=$(id -u)

# Log configuration
LOGS_FOLDER="/var/log/roboshop"
LOGS_FILE="${LOGS_FOLDER}/$(basename "$0" .sh).log"

# Colors
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

# Check root user
if [ "$USER_ID" -ne 0 ]; then
    echo -e "${R}Please run this script with sudo access.${N}"
    exit 1
fi

# Create log directory
mkdir -p "$LOGS_FOLDER" || {
    echo "Failed to create log directory: $LOGS_FOLDER"
    exit 1
}

# Timestamp function
timestamp() {
    date "+%F %T"
}

# Logging function
log() {
    echo -e "$(timestamp) [$1] $2" | tee -a "$LOGS_FILE"
}

# Validation function
validate() {
    local status=$1
    local message=$2

    if [ "$status" -ne 0 ]; then
        log ERROR "${message}... ${R}FAILED${N}"
        log ERROR "Check log file: $LOGS_FILE"
        exit 1
    else
        log INFO "${message}... ${G}SUCCESS${N}"
    fi
}

# Start script
START_TIME=$SECONDS
log INFO "==== MySQL Script Started ===="

# Enable MySQL 8.4 module
dnf module enable mysql:8.4 -y >> "$LOGS_FILE" 2>&1
validate $? "Enabling MySQL 8.4 module"

# Install MySQL server
dnf install mysql-server -y >> "$LOGS_FILE" 2>&1
validate $? "Installing MySQL server"

# Enable MySQL service
systemctl enable mysqld >> "$LOGS_FILE" 2>&1
validate $? "Enabling MySQL service"

# Start MySQL service
systemctl start mysqld >> "$LOGS_FILE" 2>&1
validate $? "Starting MySQL service"

# Configure MySQL root password
mysql_secure_installation --set-root-pass 'RoboShop@1' >> "$LOGS_FILE" 2>&1
validate $? "Setting MySQL root password"

# Complete script
log INFO "Script completed in $((SECONDS - START_TIME)) seconds"
log INFO "==== MySQL Script Completed Successfully ===="
