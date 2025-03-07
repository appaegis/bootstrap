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
### With this script, setup SE container as systemd unit
###
cat <<'EOF'
Description:
    With this script, load SE container image and setup SE container as systemd unit.

Usage: ./$0 [image-se.tar]
    Files required within same directory:
        1. bootstrap.sh - this is the configuration file
        2. image-se.tar - the docker image file. You can provide a different file name as an argument. 
            Either tar or tar.gz format can be provided.

    Result:
        1. Load the SE container image
        2. Extract the parameters from the bootstrap.sh
        3. Add and run SE container as systemd unit

EOF

###
## Step1: check which container engine is supported by the host
###
# Check if Docker exists
if command -v docker &> /dev/null; then
    DOCKER="docker"
# If Docker doesn't exist, check for Podman
elif command -v podman &> /dev/null; then
    DOCKER="podman"
else
    echo "Neither Docker nor Podman found. Exiting..."
    exit 1
fi
# Print the selected container runtime
echo "Container engine: $DOCKER"

# Check if running as root
if [[ "$EUID" -ne 0 ]]; then
    echo "Error: This script must be run as root or with sudo."
    exit 1
fi

echo "Running as root. Proceeding with installation..."


###
## Step2: load image from local if exist
###
IMAGE_FILE="${1:-image-se.tar}"
IMAGE_FILE="${IMAGE_FILE%.gz}"

# Check if the file exists or need to unzip
if [[ ! -f "$IMAGE_FILE" ]]; then
    if [[ ! -f "$IMAGE_FILE.gz" ]]; then
        echo "Error: File '$IMAGE_FILE' or '$IMAGE_FILE.gz' not found!"
        exit 1
    else
        echo "Unzipping $IMAGE_FILE.gz"
        gunzip -k "$IMAGE_FILE.gz"
        if [[ ! -f "$IMAGE_FILE" ]]; then
            echo "Unzip failed!"
            exit 1
        fi
    fi
fi

# Run docker image load and capture the output
OUTPUT=$($DOCKER image load -i $IMAGE_FILE 2>&1)

# Extract the Image ID using grep and awk
IMAGE_ID=$(echo "$OUTPUT" | grep -oE 'image.+sha256:[a-f0-9]+' | head -n 1 | sed -n 's/.*sha256:\([a-f0-9]\+\).*/\1/p' | cut -c 1-12)

# Check if IMAGE_ID is found
if [[ -n "$IMAGE_ID" ]]; then
    echo "Loaded $IMAGE_FILE as Image ID: $IMAGE_ID"
else
    echo "Failed to extract Image ID"
    exit 1
fi


###
## Step3: extract the parameters from the bootstrap.sh
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

###
## Finally: add and run SE container as systemd unit
###
# Define the Quadlet service file path
SERVICE_NAME="mammoth-se.${projectName}"
SERVICE_PATH="/etc/containers/systemd/$SERVICE_NAME.container"

# Check if the service is already running
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "Service '$SERVICE_NAME' is already running. Exiting."
    exit 0
fi

# Ensure the target directory exists
mkdir -p /etc/containers/systemd

# Generate the Quadlet service file using a heredoc
cat <<EOF > "$SERVICE_PATH"
[Unit]
Description=Mammoth Cyber Service Edge Container ${projectName}
# below should be added automatically but just in case
After=network-online.target
Requires=network-online.target

[Container]
Label="com.centurylinklabs.watchtower.scope=$scope"
ContainerName=${projectName}.se
Image=$IMAGE_ID
Network=host

# Environment variables
Environment="auth_token=$auth_token"
Environment="auth_secret=$auth_secret"
Environment="server_validation_code=$server_validation_code"
Environment="server_addr=$server_addr"
Environment="network_type=$network_type"
Environment="network_name=$network_name"
Environment="service_edge_number=$service_edge_number"
Environment="http_proxy=$proxyUrl"

# Volumes
# Volume=.:/home/se/conf/
# Volume=shared:/var/shared/

# Logging options
LogDriver=journald

# below options are not supported by older quadlet
# LogDriver=json-file
# LogOpt=max-size=2m
# LogOpt=max-file=10
# LogOpt=compress=true

[Service]
Restart=always
RemainAfterExit=yes

[Install]
# below should be added automatically but just in case
WantedBy=multi-user.target default.target

EOF

# Confirm the service file was created
if [[ -f "$SERVICE_PATH" ]]; then
    echo "Quadlet container service file created at: $SERVICE_PATH"
else
    echo "Failed to create Quadlet container service file."
    exit 1
fi

# Reload systemd daemon and enable the Quadlet container
systemctl daemon-reload
systemctl start $SERVICE_NAME
systemctl enable --now $SERVICE_NAME
systemctl status $SERVICE_NAME

# Confirm the service is running
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "Quadlet service '$SERVICE_NAME' has been installed and started successfully."
else
    echo "Failed to start Quadlet service '$SERVICE_NAME'. Check logs for details."
    exit 1
fi

###

exit 0

###
## Alternative: run the SE container
###
$DOCKER run -d \
    --name "$(echo $projectName).se" \
    --network host \
    --restart always \
    -e auth_token="$auth_token" \
    -e auth_secret="$auth_secret" \
    -e server_validation_code="$server_validation_code" \
    -e server_addr="$server_addr" \
    -e network_type="$network_type" \
    -e network_name="$network_name" \
    -e service_edge_number="$service_edge_number" \
    -e http_proxy="$proxyUrl" \
    -v $(pwd):/home/se/conf/ \
    -v shared:/var/shared/ \
    --label "com.centurylinklabs.watchtower.scope=$scope" \
    --log-driver json-file \
    --log-opt max-size=2m \
    --log-opt max-file=10 \
    --log-opt compress=true \
    $IMAGE_ID

$DOCKER ps -a
