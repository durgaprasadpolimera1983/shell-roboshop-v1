
#!/bin/bash

USER_ID=$(id -u)
LOGS_FOLDER="/var/log/roboshop"
LOGS_FILE="${LOGS_FOLDER}/mongo.log"

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

# Check root privileges
if [ "$USER_ID" -ne 0 ]; then
    echo "Please run this script with sudo access."
    exit 1
fi

# Create log directory
mkdir -p "$LOGS_FOLDER" || exit 1
touch "$LOGS_FILE" || exit 1

echo "$(date '+%F %T') [INFO] MongoDB installation started" | tee -a "$LOGS_FILE"

validate() {
    local status="$1"
    local message="$2"

    if [ "$status" -ne 0 ]; then
        echo -e "$(date '+%F %T') [ERROR] ${message}...${R}FAILED${N}" | tee -a "$LOGS_FILE"
        echo "Check logs: $LOGS_FILE"
        exit 1
    else
        echo -e "$(date '+%F %T') [INFO] ${message}...${G}SUCCESS${N}" | tee -a "$LOGS_FILE"
    fi
}

# Copy MongoDB repository file
if [ ! -f ./mongo.repo ]; then
    echo "mongo.repo file not found in the current directory."
    exit 1
fi

cp ./mongo.repo /etc/yum.repos.d/mongo.repo
validate $? "Adding MongoDB repository"

# Refresh repository metadata
dnf clean all &>> "$LOGS_FILE"
validate $? "Cleaning DNF cache"

dnf makecache &>> "$LOGS_FILE"
validate $? "Refreshing DNF cache"

# Install MongoDB 7.0
dnf install mongodb-org -y &>> "$LOGS_FILE"
validate $? "Installing MongoDB"

# Enable MongoDB service
systemctl enable mongod &>> "$LOGS_FILE"
validate $? "Enabling MongoDB"

# Start MongoDB
systemctl start mongod &>> "$LOGS_FILE"
validate $? "Starting MongoDB"

# Configure MongoDB to listen on all IPv4 interfaces.
# Remote access must also be restricted using AWS security groups.
if grep -qE '^[[:space:]]*bindIp:' /etc/mongod.conf; then
    sed -i -E 's/^[[:space:]]*bindIp:.*/  bindIp: 0.0.0.0/' /etc/mongod.conf
else
    echo "[ERROR] bindIp setting not found in /etc/mongod.conf" | tee -a "$LOGS_FILE"
    exit 1
fi
validate $? "Configuring MongoDB bindIp"

# Restart MongoDB
systemctl restart mongod &>> "$LOGS_FILE"
validate $? "Restarting MongoDB"

# Verify service status
systemctl is-active --quiet mongod
validate $? "Checking MongoDB service status"

# Test MongoDB locally
mongosh --quiet --eval 'db.adminCommand({ ping: 1 })' &>> "$LOGS_FILE"
validate $? "Testing MongoDB connection"

echo "$(date '+%F %T') [INFO] MongoDB installation completed successfully" | tee -a "$LOGS_FILE"
