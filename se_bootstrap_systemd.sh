#!/bin/bash
# set -xv  # Enable full debugging

sanitize_filename() {
    local filename="$1"
    # Remove invalid characters: `/ \ ? * : | " < >`
    filename=$(echo "$filename" | sed 's/[\/\\?*:|"<>]//g')
    # Replace spaces with underscores
    filename=$(echo "$filename" | tr ' ' '_')
    # Trim leading/trailing spaces or dots
    filename=$(echo "$filename" | sed 's/^[._]*//;s/[._]*$//')
    echo "$filename"
}

###
### Description:
### With this script, setup SE binary executable as systemd unit
###
cat <<EOF
Description:
    With this script, unpack SE binary, install under /var/mammoth-se and setup SE instance as systemd unit.

Usage: $0 [zip-se.tgz] or $0 -uninstall
    Files required within same directory:
        1. bootstrap.sh - this is the configuration file
        2. zip-se.tgz - the pack file contains SE binary and server certificate. You can provide a different file name as an argument. 

    Result:
        1. Install SE binary and cert under /var/mammoth-se
        2. Extract the parameters from the bootstrap.sh
        3. Add and run SE binary as systemd unit

EOF

###
## Step1: check runtime environment
###
# Check if running as root
if [[ "$EUID" -ne 0 ]]; then
    echo "Error: This script must be run as root or with sudo."
    exit 1
fi

echo "Running as root. Proceeding with installation..."
IMAGE_FILE="${1:-zip-se.tgz}"

if echo "$@" | grep -qiE '(^| )(-uninstall|--uninstall)( |$)'; then
    UNINSTALL=true
fi


###
## Step2: extract the parameters from the bootstrap.sh and convert to env file
###
# Set the file path and the search string
FILE="bootstrap.sh"
SEARCH_STRING="se_bootstrap.sh"

# Find the last matching line
LINE=$(grep "$SEARCH_STRING" "$FILE" | tail -n 1)

# Check if a matching line was found
if [[ -z "$LINE" ]]; then
    echo "No matching line found"
    exit 1
fi

# Remove everything before and including the search string
LINE=$(echo "$LINE" | sed -E "s/.*$SEARCH_STRING\s*//")

# Extract values into an array
VALUES=()
for value in $LINE; do
    value=$(echo "$value" | xargs | sed 's/^"\|"$//g')  # Trim spaces and quotes
    # eval if value is a variable
    if [[ "$value" == \$* ]]; then
        value=$(eval echo "$value")
    fi
    VALUES+=("$value")
done

# Assign extracted values to positional parameters
set -- "${VALUES[@]}"

# Print out the extracted values
# echo "Extracted Positional Variables:"
# for i in "${!VALUES[@]}"; do
#     echo "\$$((i+1)) = ${VALUES[i]}"
# done
echo "Configuration parsed successfully."

export auth_token=$1
export auth_secret=$2
export server_validation_code=$3
export server_addr=$4
export network_type=$5
export network_name=$6
export service_edge_number=$7
export scope=$8
export projectName=$9

# need add {} if parameter is greater than 10
export proxyUrl=${10}  # if need to connect through proxy. Format is http://[username:password@]proxyAddr
export label=${11}      # only applicable to device-mesh, should be unique
export serialno=${12}   # only applicable to device-mesh, must be unique

# sanitize
projectName=$(sanitize_filename "$projectName")
DESTDIR="/var/lib/mammoth-se/${projectName}"
mkdir -p "$DESTDIR"

SERVICE_NAME="mammoth-se.${projectName}"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME.service"

# now prepare the environment file
SEENV="$DESTDIR/se.env"
cat <<EOF > "$SEENV"
auth_token=$auth_token
auth_secret=$auth_secret
server_validation_code=$server_validation_code
server_addr=$server_addr
network_type=$network_type
network_name=$network_name
service_edge_number=$service_edge_number
http_proxy=$proxyUrl
EOF
#always set permission immediately in case the rest script fails
chmod --preserve-root --recursive go= "$DESTDIR"

if [[ ! -f "$SEENV" ]]; then
    echo "Error: SE env file '$SEENV' not found."
    exit 1
fi


###
## Option: uninstall
###
if [[ "${UNINSTALL,,}" == "true" ]]; then
    echo "Uninstalling Systemd service '$SERVICE_NAME'..."
    systemctl stop $SERVICE_NAME
    systemctl disable $SERVICE_NAME
    rm -f "$SERVICE_PATH"
    rm -rf "$DESTDIR"
    systemctl daemon-reload
    echo "Systemd service '$SERVICE_NAME' uninstalled successfully."
    exit 0
fi


###
## Step3: unpack and install
###
DESTBIN="$DESTDIR/appaegis-se2"
tar -xzf "$IMAGE_FILE" --no-same-owner -C "$DESTDIR"
chmod +x "$DESTBIN"
dir -l "$DESTDIR"

if [[ ! -f "$DESTBIN" ]]; then
    echo "Error: SE binary '$DESTBIN' not found."
    exit 1
fi


SEINI="$DESTDIR/frpc.ini"
cat <<EOF > "$SEINI"
[common]
tls_enable=true
tls_trusted_ca_file = $DESTDIR/isrgrootx1_and_trustid-x3-root.pem
login_fail_exit=false
EOF

# below is SE Linux stuff
FILE_TYPE=NetworkManager_exec_t
for file in "$DESTDIR"/*; do
    echo "Setting SELinux context for $file"
    semanage fcontext -a -t $FILE_TYPE "$file"  || true
    restorecon -v "$file"                       || true
done



###
## Finally: add and run SE binary as systemd unit
###
# do this again in case any new files are added
chmod --preserve-root --recursive go= "$DESTDIR"
# Define the systemd service file path

# Check if the service is already running
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "Service '$SERVICE_NAME' is already running. Exiting."
    exit 0
fi

# Ensure the target directory exists
mkdir -p $(dirname "$SERVICE_PATH")

# Generate the systemd service file using a heredoc
cat <<EOF > "$SERVICE_PATH"
[Unit]
Description=Mammoth Cyber Service Edge native binary ${projectName}
After=network-online.target
Requires=network-online.target

[Service]
EnvironmentFile=$SEENV
ExecStart=$DESTBIN
WorkingDirectory=$DESTDIR

Restart=always
RemainAfterExit=yes
RestartSec=5

StandardOutput=journal
StandardError=journal
LimitNOFILE=65535

[Install]
# below should be added automatically but just in case
WantedBy=multi-user.target default.target

EOF

# Confirm the service file was created
if [[ -f "$SERVICE_PATH" ]]; then
    echo "Systemd service file created at: $SERVICE_PATH"
else
    echo "Failed to create Systemd service file."
    exit 1
fi

# Reload systemd daemon and enable the service
systemctl daemon-reload
sleep 1
systemctl enable --now $SERVICE_NAME
sleep 1
systemctl start $SERVICE_NAME
systemctl status $SERVICE_NAME

# Confirm the service is running
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "Systemd service '$SERVICE_NAME' has been installed and started successfully."
else
    echo "Failed to start Systemd service '$SERVICE_NAME'. Check logs for details."
    exit 1
fi

###
