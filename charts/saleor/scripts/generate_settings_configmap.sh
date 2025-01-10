#!/bin/bash

# generate_settings_configmap.sh
#
# Description:
#   This script generates a Kubernetes ConfigMap containing a modified version of Saleor's settings.py
#   that includes read replica database configuration. The script should be run whenever:
#   1. The Saleor version is updated in the Helm chart (check Chart.yaml for the version)
#   2. The database configuration for read replicas needs to be modified
#
# Usage:
#   ./generate_settings_configmap.sh <saleor-version>
#
# Example:
#   ./generate_settings_configmap.sh 3.20.65
#
# Dependencies:
#   - curl: for downloading the settings.py file
#   - sed: for text processing
#
# The script will:
#   1. Download the settings.py file from the specified Saleor version
#   2. Modify the DATABASES configuration to include read replica settings
#   3. Generate a ConfigMap in the correct Helm chart templates directory
#
# Note:
#   This script should be run from the root of the helm-charts repository
#   or from within the charts/saleor directory.

set -e  # Exit on any error

# Function to find the correct chart directory
find_chart_dir() {
    local current_dir="$PWD"
    local chart_dir

    # Check if we're in the charts/saleor directory
    if [[ "$current_dir" == */charts/saleor ]]; then
        chart_dir="$current_dir"
    # Check if we're in the helm-charts root
    elif [[ "$current_dir" == */helm-charts ]]; then
        chart_dir="$current_dir/charts/saleor"
    # Check if we're in the scripts directory
    elif [[ "$current_dir" == */charts/saleor/scripts ]]; then
        chart_dir="$(dirname "$current_dir")"
    else
        echo "Error: Script must be run from helm-charts root or charts/saleor directory"
        echo "Current directory: $current_dir"
        exit 1
    fi

    echo "$chart_dir"
}

# Check if version parameter is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <saleor-version>"
    echo "Example: $0 3.20.65"
    exit 1
fi

# Validate version format
if ! [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Version must be in format X.Y.Z (e.g., 3.20.65)"
    exit 1
fi

VERSION=$1
SETTINGS_URL="https://raw.githubusercontent.com/saleor/saleor/refs/tags/${VERSION}/saleor/settings.py"

# Find the correct chart directory and set output paths
CHART_DIR=$(find_chart_dir)
TEMPLATES_DIR="$CHART_DIR/templates"
OUTPUT_FILE="$TEMPLATES_DIR/configmap-settings.yaml"

echo "Chart directory: $CHART_DIR"
echo "Output file: $OUTPUT_FILE"

# Verify the templates directory exists
if [ ! -d "$TEMPLATES_DIR" ]; then
    echo "Error: Templates directory not found at $TEMPLATES_DIR"
    exit 1
fi

# Download the original settings.py
echo "Downloading settings.py from version ${VERSION}..."
SETTINGS_CONTENT=$(curl -s "$SETTINGS_URL")

if [ $? -ne 0 ]; then
    echo "Error: Failed to download settings.py from $SETTINGS_URL"
    exit 1
fi

# Create a temporary file for the modified settings
TEMP_FILE=$(mktemp)

# Write the settings content to the temp file
echo "$SETTINGS_CONTENT" > "$TEMP_FILE"

# Use sed to replace the DATABASES block
echo "Modifying settings.py..."
sed -i.bak '/^DATABASES = {/,/^}/c\
DATABASES = {\
    "default": dj_database_url.config(\
        default=os.environ.get("DATABASE_URL"),\
        conn_max_age=DB_CONN_MAX_AGE,\
    ),\
    "replica": dj_database_url.config(\
        default=os.environ.get("DATABASE_URL_REPLICA"),\
        conn_max_age=DB_CONN_MAX_AGE,\
        test_options={"MIRROR": "default"},\
    ),\
}\
\
DATABASE_CONNECTION_REPLICA_NAME = "replica"\
DATABASE_CONNECTION_DEFAULT_NAME = "default"\
DATABASE_CONNECTION_REPLICA_TIMEOUT = int(\
    os.environ.get("DATABASE_CONNECTION_REPLICA_TIMEOUT", 3)\
)' "$TEMP_FILE"

# Create the ConfigMap
echo "Generating ConfigMap..."
cat > "$OUTPUT_FILE" << EOF
{{- if include "saleor.readReplicaEnabled" . }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "saleor.fullname" . }}-settings
  labels:
    {{- include "saleor.labels" . | nindent 4 }}
data:
  settings.py: |
$(sed 's/^/    /' "$TEMP_FILE")
{{- end }}
EOF

# Clean up
rm "$TEMP_FILE" "$TEMP_FILE.bak"

echo "ConfigMap generated at $OUTPUT_FILE"
echo "Done!"

# Add a reminder about Chart.yaml version
echo
echo "Remember to check that the Saleor version in Chart.yaml matches $VERSION"
echo "Current location: $CHART_DIR/Chart.yaml"
