#!/bin/bash
set -e

echo "=========================================="
echo "Qdrant Vector Database Deployment"
echo "=========================================="
echo ""

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Project directory
PROJECT_DIR="/home/administrator/projects/qdrant"
cd "$PROJECT_DIR"

echo -e "${YELLOW}Step 1: Pre-deployment checks${NC}"
echo "Checking Docker..."
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}ERROR: Docker is not running${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker is running${NC}"

echo ""
echo -e "${YELLOW}Step 2: Network setup${NC}"

# Create qdrant-net if it doesn't exist
if ! docker network inspect qdrant-net > /dev/null 2>&1; then
    echo "Creating qdrant-net network..."
    docker network create qdrant-net
    echo -e "${GREEN}✓ Created qdrant-net${NC}"
else
    echo -e "${GREEN}✓ qdrant-net already exists${NC}"
fi

# Verify observability-net exists
if ! docker network inspect observability-net > /dev/null 2>&1; then
    echo -e "${YELLOW}WARNING: observability-net does not exist (logging may not work)${NC}"
    echo "Creating observability-net..."
    docker network create observability-net
    echo -e "${GREEN}✓ Created observability-net${NC}"
else
    echo -e "${GREEN}✓ observability-net exists${NC}"
fi

echo ""
echo -e "${YELLOW}Step 3: Deploying Qdrant container${NC}"

# Stop and remove existing container if it exists
if docker ps -a | grep -q qdrant; then
    echo "Stopping existing Qdrant container..."
    docker compose down
fi

# Deploy Qdrant
echo "Starting Qdrant..."
docker compose up -d

# Wait for container to start
echo "Waiting for container to start..."
sleep 5

echo ""
echo -e "${YELLOW}Step 4: Health check${NC}"

# Check if container is running
if docker ps | grep -q qdrant; then
    echo -e "${GREEN}✓ Qdrant container is running${NC}"
else
    echo -e "${RED}ERROR: Qdrant container failed to start${NC}"
    echo "Container logs:"
    docker logs qdrant
    exit 1
fi

# Wait for health check
echo "Waiting for health check to pass (up to 60 seconds)..."
for i in {1..12}; do
    if curl -s -f http://localhost:6333/healthz > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Health check passed${NC}"
        break
    fi
    if [ $i -eq 12 ]; then
        echo -e "${RED}ERROR: Health check failed after 60 seconds${NC}"
        docker logs qdrant
        exit 1
    fi
    sleep 5
done

echo ""
echo -e "${YELLOW}Step 5: Verification tests${NC}"

# Test REST API
echo "Testing REST API..."
if curl -s http://localhost:6333/ > /dev/null; then
    echo -e "${GREEN}✓ REST API responding${NC}"
else
    echo -e "${RED}ERROR: REST API not responding${NC}"
    exit 1
fi

# Test dashboard
echo "Testing dashboard..."
if curl -s http://localhost:6333/dashboard > /dev/null; then
    echo -e "${GREEN}✓ Dashboard accessible${NC}"
else
    echo -e "${YELLOW}WARNING: Dashboard may not be accessible${NC}"
fi

# Create test collection
echo "Testing vector operations..."
TEST_RESULT=$(curl -s -X PUT http://localhost:6333/collections/deployment_test \
  -H 'Content-Type: application/json' \
  -d '{"vectors": {"size": 4, "distance": "Cosine"}}' | grep -o '"status":"ok"' || echo "")

if [ -n "$TEST_RESULT" ]; then
    echo -e "${GREEN}✓ Collection creation successful${NC}"

    # Clean up test collection
    curl -s -X DELETE http://localhost:6333/collections/deployment_test > /dev/null
    echo -e "${GREEN}✓ Test collection cleaned up${NC}"
else
    echo -e "${YELLOW}WARNING: Collection creation test failed (may still be starting)${NC}"
fi

echo ""
echo -e "${YELLOW}Step 6: Network connectivity test${NC}"

# Test internal DNS resolution
echo "Testing internal DNS (qdrant:6333)..."
if docker run --rm --network qdrant-net alpine ping -c 3 qdrant > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Internal DNS resolution working${NC}"
else
    echo -e "${YELLOW}WARNING: Internal DNS test failed${NC}"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}Qdrant Deployment Complete!${NC}"
echo "=========================================="
echo ""
echo "Access URLs:"
echo "  Dashboard:  http://linuxserver.lan:6333/dashboard"
echo "  API Docs:   http://linuxserver.lan:6333/docs"
echo "  REST API:   http://linuxserver.lan:6333"
echo "  Health:     http://linuxserver.lan:6333/healthz"
echo ""
echo "Internal Access (via qdrant-net):"
echo "  http://qdrant:6333"
echo ""
echo "Container Status:"
docker ps | grep qdrant
echo ""
echo "Logs: docker logs qdrant"
echo "Stop:  docker compose down"
echo "Start: docker compose up -d"
echo ""
