#!/bin/bash
################################################################################
# Qdrant Manual Snapshot/Save
################################################################################
# Location: /home/administrator/projects/qdrant/manualsavealldb.sh
#
# Purpose: Forces Qdrant to create a snapshot of all collections
# This ensures all vector data and metadata is persisted before backup.
#
# Called by: backup scripts before creating tar archives
################################################################################

set -e

echo "=== Qdrant: Creating snapshots of all collections ==="

# Check if Qdrant API key is required
QDRANT_API_KEY=""
if [ -f /home/administrator/projects/secrets/qdrant.env ]; then
    source /home/administrator/projects/secrets/qdrant.env 2>/dev/null
fi

# Get Qdrant container IP (use localhost since we're on the same host)
# More reliable than trying to find the right network IP
QDRANT_IP="localhost"

if [ -z "$QDRANT_IP" ]; then
    echo "ERROR: Could not determine Qdrant IP address"
    exit 1
fi

QDRANT_URL="http://${QDRANT_IP}:6333"

# Build curl command with auth if needed
if [ -n "$QDRANT_API_KEY" ]; then
    AUTH_HEADER="-H api-key: $QDRANT_API_KEY"
    echo "Using authenticated connection"
else
    AUTH_HEADER=""
    echo "Using non-authenticated connection"
fi

# Get list of all collections
echo "Fetching list of collections from $QDRANT_URL..."
if [ -n "$AUTH_HEADER" ]; then
    COLLECTIONS=$(curl -s $AUTH_HEADER "$QDRANT_URL/collections" | jq -r '.result.collections[].name' 2>/dev/null)
else
    COLLECTIONS=$(curl -s "$QDRANT_URL/collections" | jq -r '.result.collections[].name' 2>/dev/null)
fi

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to fetch collections from Qdrant API"
    exit 1
fi

if [ -z "$COLLECTIONS" ]; then
    echo "✓ No collections found (empty database)"
    echo ""
    echo "=== Qdrant save operation complete ==="
    exit 0
fi

echo "Found collections:"
echo "$COLLECTIONS" | sed 's/^/  - /'
echo ""

# Create snapshot for each collection
SNAPSHOT_COUNT=0
FAILED_COUNT=0

while IFS= read -r collection; do
    if [ -n "$collection" ]; then
        echo "Creating snapshot for collection: $collection"

        if [ -n "$AUTH_HEADER" ]; then
            RESULT=$(curl -s -X POST $AUTH_HEADER \
                "$QDRANT_URL/collections/$collection/snapshots" 2>/dev/null)
        else
            RESULT=$(curl -s -X POST \
                "$QDRANT_URL/collections/$collection/snapshots" 2>/dev/null)
        fi

        # Check if snapshot was created successfully
        if echo "$RESULT" | jq -e '.result.name' >/dev/null 2>&1; then
            SNAPSHOT_NAME=$(echo "$RESULT" | jq -r '.result.name')
            echo "  ✓ Snapshot created: $SNAPSHOT_NAME"
            SNAPSHOT_COUNT=$((SNAPSHOT_COUNT + 1))
        else
            echo "  ✗ Failed to create snapshot"
            FAILED_COUNT=$((FAILED_COUNT + 1))
        fi
    fi
done <<< "$COLLECTIONS"

echo ""
if [ $FAILED_COUNT -eq 0 ]; then
    echo "✓ Qdrant snapshots completed successfully"
    echo "  Total snapshots created: $SNAPSHOT_COUNT"
    echo "  All vector collections are in consistent state for backup"
else
    echo "⚠ Qdrant snapshots completed with errors"
    echo "  Snapshots created: $SNAPSHOT_COUNT"
    echo "  Failed: $FAILED_COUNT"
fi

echo ""
echo "=== Qdrant save operation complete ==="
