# Qdrant Vector Database - Infrastructure Documentation

## Executive Summary

Qdrant is a deployed centralized vector database infrastructure service providing high-performance vector search capabilities for AI applications including mem0, RAG systems, and semantic search.

## Current Status

- **Status**: ✅ Fully Operational with OAuth2 SSO
- **Version**: 1.15.5
- **Containers**: qdrant, qdrant-auth-proxy
- **Deployed**: 2025-11-02
- **OAuth2 Deployed**: 2025-11-02
- **Purpose**: Centralized vector storage infrastructure
- **External Access**: https://qdrant.ai-servicers.com/dashboard (Keycloak SSO)

## Access Information

### External Access (OAuth2 Protected)
- **Dashboard**: https://qdrant.ai-servicers.com/dashboard
- **API Root**: https://qdrant.ai-servicers.com/
- **API Documentation**: https://qdrant.ai-servicers.com/docs (Swagger UI)
- **Collections**: https://qdrant.ai-servicers.com/collections
- **Metrics**: https://qdrant.ai-servicers.com/metrics (Prometheus)

### LAN Access (Direct)
- **Dashboard**: http://linuxserver.lan:6333/dashboard
- **API Documentation**: http://linuxserver.lan:6333/docs (Swagger UI)
- **REST API**: http://linuxserver.lan:6333
- **Health Endpoint**: http://linuxserver.lan:6333/healthz
- **Metrics**: http://linuxserver.lan:6333/metrics (Prometheus)

### Internal Docker Network Access
- **URL**: http://qdrant:6333 (via qdrant-net)
- **gRPC**: qdrant:6334 (high-performance API)

### Authentication
- **External (HTTPS)**: Keycloak OAuth2 SSO (administrators group required)
- **LAN (HTTP)**: None - Direct network access
- **Internal Docker**: None - Network-level isolation via qdrant-net

## Architecture

### Service Design
- **Type**: Single-node deployment (centralized infrastructure)
- **Pattern**: Reusable by multiple applications
- **Persistence**: External Docker volume for data survival
- **Security**: OAuth2 Proxy for external access with Keycloak SSO

### Containers
1. **qdrant**: Main vector database service
2. **qdrant-auth-proxy**: OAuth2 Proxy for authentication gateway

### Ports
- **6333**: REST API + Web Dashboard (exposed to LAN)
- **6334**: gRPC API (internal Docker network only)
- **4180**: OAuth2 Proxy (internal only, proxied via Traefik)

### Networks
- **qdrant-net**: Primary network for consuming services (mem0, RAG apps) + backend connectivity
- **loki-net**: Monitoring and logging integration (Promtail auto-discovery)
- **traefik-net**: External web access via OAuth2 proxy
- **keycloak-net**: OAuth2 authentication to Keycloak

### OAuth2 Architecture
```
Internet → Traefik (HTTPS) → OAuth2 Proxy → Keycloak (auth)
                                   ↓
                              Qdrant Backend
```

### Storage
- **Data Directory**: /home/administrator/projects/data/qdrant
- **Container Mount**: /qdrant/storage
- **Type**: Bind mount (centralized data storage)
- **Persistence**: Survives container restarts and rebuilds
- **Backup**: Standard file-based tools (rsync, tar)

### Resource Limits
- **Memory**: 2GB limit, 512MB reservation
- **CPU**: 2 cores limit, 0.5 reservation

## Integration Guide

### Python Client

**Installation**:
```bash
pip install qdrant-client
```

**REST API Usage**:
```python
from qdrant_client import QdrantClient

# For production (via qdrant-net)
client = QdrantClient(host="qdrant", port=6333)

# For local testing
client = QdrantClient(url="http://linuxserver.lan:6333")

# Create collection
client.create_collection(
    collection_name="my_collection",
    vectors_config={
        "size": 384,  # Vector dimension (e.g., OpenAI embeddings)
        "distance": "Cosine"  # or "Euclidean" or "Dot"
    }
)

# Insert vectors
from qdrant_client.models import PointStruct

client.upsert(
    collection_name="my_collection",
    points=[
        PointStruct(
            id=1,
            vector=[0.1, 0.2, ...],  # 384 dimensions
            payload={"text": "example document", "metadata": "value"}
        )
    ]
)

# Search
results = client.search(
    collection_name="my_collection",
    query_vector=[0.1, 0.2, ...],
    limit=5
)
```

**gRPC API Usage** (High Performance):
```python
from qdrant_client import QdrantClient

client = QdrantClient(host="qdrant", port=6334, prefer_grpc=True)
# Same API as REST, but faster for large operations
```

### JavaScript Client

**Installation**:
```bash
npm install @qdrant/js-client-rest
```

**Usage**:
```javascript
const { QdrantClient } = require('@qdrant/js-client-rest');

// For production
const client = new QdrantClient({ url: 'http://qdrant:6333' });

// For local testing
const client = new QdrantClient({ url: 'http://linuxserver.lan:6333' });

// Create collection
await client.createCollection('my_collection', {
  vectors: { size: 384, distance: 'Cosine' }
});

// Insert vectors
await client.upsert('my_collection', {
  points: [
    {
      id: 1,
      vector: [0.1, 0.2, ...],
      payload: { text: 'example', metadata: 'value' }
    }
  ]
});

// Search
const results = await client.search('my_collection', {
  vector: [0.1, 0.2, ...],
  limit: 5
});
```

### REST API (curl)

```bash
# Create collection
curl -X PUT http://qdrant:6333/collections/my_collection \
  -H 'Content-Type: application/json' \
  -d '{"vectors": {"size": 384, "distance": "Cosine"}}'

# Insert vectors
curl -X PUT http://qdrant:6333/collections/my_collection/points \
  -H 'Content-Type: application/json' \
  -d '{
    "points": [
      {"id": 1, "vector": [0.1, 0.2, 0.3, ...], "payload": {"key": "value"}}
    ]
  }'

# Search
curl -X POST http://qdrant:6333/collections/my_collection/points/search \
  -H 'Content-Type: application/json' \
  -d '{"vector": [0.1, 0.2, 0.3, ...], "limit": 5}'

# Get collection info
curl http://qdrant:6333/collections/my_collection

# Delete collection
curl -X DELETE http://qdrant:6333/collections/my_collection
```

## Collection Naming Conventions

**Recommended Pattern**: `{application}_{purpose}`

**Examples**:
- `mem0_conversations` - mem0 conversation memory
- `mem0_user_profiles` - mem0 user context
- `rag_documents` - RAG document embeddings
- `rag_code` - RAG code search
- `semantic_search_products` - Product search vectors

**Benefits**:
- Clear application ownership
- Easy to identify and manage
- Supports multi-tenant usage

## Common Vector Dimensions

- **OpenAI text-embedding-3-small**: 1536 dimensions
- **OpenAI text-embedding-3-large**: 3072 dimensions
- **OpenAI text-embedding-ada-002**: 1536 dimensions
- **Sentence Transformers (all-MiniLM-L6-v2)**: 384 dimensions
- **Sentence Transformers (all-mpnet-base-v2)**: 768 dimensions

## Distance Metrics

- **Cosine**: Best for normalized vectors (e.g., embeddings) - most common
- **Euclidean**: Best for absolute distance measurements
- **Dot**: Best for unnormalized vectors or when magnitude matters

## mem0 Integration

mem0 will use Qdrant as vector store for AI memory:

```python
# Expected mem0 configuration
import mem0
from qdrant_client import QdrantClient

# mem0 will connect to Qdrant
client = QdrantClient(host="qdrant", port=6333)

# Collections mem0 may create:
# - mem0_conversations
# - mem0_user_profiles
# - mem0_session_context
```

## Operations

### Start/Stop

```bash
cd /home/administrator/projects/qdrant

# Start
docker compose up -d

# Stop
docker compose down

# Restart
docker compose restart

# View logs
docker logs qdrant -f

# Check status
docker ps | grep qdrant
```

### Health Check

```bash
# Container health
docker inspect qdrant --format='{{.State.Health.Status}}'

# API health
curl http://linuxserver.lan:6333/healthz

# Collection list
curl http://linuxserver.lan:6333/collections
```

### Monitoring

**Logs** (via Loki):
```
# Grafana Explore
{container_name="qdrant"}
```

**Metrics** (Prometheus format):
```bash
curl http://linuxserver.lan:6333/metrics
```

**Resource Usage**:
```bash
docker stats qdrant
```

## Backup and Restore

### Snapshot Backup

Qdrant supports snapshots for collections:

```bash
# Create snapshot via API
curl -X POST http://linuxserver.lan:6333/collections/my_collection/snapshots

# Response includes snapshot name
# {"result":{"name":"my_collection-2025-11-02-18-00-00.snapshot","size":1024},"status":"ok"}

# Download snapshot
curl http://linuxserver.lan:6333/collections/my_collection/snapshots/my_collection-2025-11-02-18-00-00.snapshot \
  --output backup.snapshot
```

### Restore from Snapshot

```bash
# Upload and restore snapshot
curl -X PUT http://linuxserver.lan:6333/collections/my_collection/snapshots/upload \
  -F 'snapshot=@backup.snapshot'
```

### Directory Backup (Bind Mount)

```bash
# Backup entire data directory (all collections) - SIMPLE!
tar czf $HOME/backups/qdrant-backup-$(date +%Y%m%d).tar.gz \
  /home/administrator/projects/data/qdrant

# Restore from backup
tar xzf $HOME/backups/qdrant-backup-YYYYMMDD.tar.gz -C /

# Or use rsync for incremental backups
rsync -av /home/administrator/projects/data/qdrant/ /mnt/backups/qdrant/
```

**Note**: Since migration to bind mounts (2025-11-02), backups are much simpler using standard file tools.

## OAuth2 Deployment Notes

### Keycloak Client Configuration
- **Client ID**: qdrant
- **Client Type**: OpenID Connect
- **Access Type**: Confidential
- **Root URL**: https://qdrant.ai-servicers.com
- **Valid Redirect URIs**:
  - https://qdrant.ai-servicers.com/*
  - https://qdrant.ai-servicers.com/oauth2/callback
- **Client Scope**: qdrant-dedicated (with groups mapper)
- **Group Access**: /administrators

### Environment File
Configuration stored in: `$HOME/projects/secrets/qdrant-oauth2.env`

**Critical Settings**:
- `OAUTH2_PROXY_UPSTREAMS=http://qdrant:6333/` ← **Trailing slash required!**
- `OAUTH2_PROXY_HTTP_ADDRESS=0.0.0.0:4180` ← Must listen on all interfaces
- Hybrid URL strategy (external HTTPS for browser, internal HTTP for token validation)

### Deployment Lessons Learned

**Issue**: Bad gateway (502) error when accessing https://qdrant.ai-servicers.com

**Root Cause**: Missing trailing slash in `OAUTH2_PROXY_UPSTREAMS` configuration

**Investigation Process**:
1. Checked logs - OAuth2 proxy showed no errors
2. Tested connectivity - Qdrant backend was responsive
3. Examined Traefik logs - Showed 30-second timeouts
4. Verified configuration - Found `OAUTH2_PROXY_UPSTREAMS=http://qdrant:6333` (missing `/`)
5. Added trailing slash and missing `HTTP_ADDRESS` configuration
6. Added debug logging for future troubleshooting

**Fix Applied**:
```bash
# Wrong (causes 502 bad gateway)
OAUTH2_PROXY_UPSTREAMS=http://qdrant:6333

# Correct (works properly)
OAUTH2_PROXY_UPSTREAMS=http://qdrant:6333/
```

**Additional Configurations Added**:
- `OAUTH2_PROXY_HTTP_ADDRESS=0.0.0.0:4180`
- Debug logging enabled for troubleshooting

**Verification**:
- Error changed from 502 (bad gateway) to 403 (forbidden) for unauthenticated requests
- OAuth2 login page displays correctly
- Authentication flow works end-to-end
- Qdrant dashboard accessible after Keycloak login

**Reference**: Similar issue documented in Dashy deployment (CLAUDE.md)

## Troubleshooting

### OAuth2 Authentication Issues

**Symptom**: 502 Bad Gateway
- Check `OAUTH2_PROXY_UPSTREAMS` has trailing slash
- Verify `OAUTH2_PROXY_HTTP_ADDRESS=0.0.0.0:4180` is set
- Check OAuth2 proxy logs: `docker logs qdrant-auth-proxy`

**Symptom**: 403 Forbidden (expected for unauthenticated users)
- Normal behavior - redirects to Keycloak login
- Verify user is in /administrators group in Keycloak

**Symptom**: Infinite redirect loop
- Check OAuth2 proxy can reach Keycloak via keycloak-net
- Verify redirect URIs match in Keycloak client configuration

### Container Won't Start

```bash
# Check logs
docker logs qdrant

# Check permissions on volume
docker volume inspect qdrant_qdrant_storage

# Verify networks exist
docker network ls | grep -E "qdrant-net|loki-net"

# Recreate networks if needed
docker network create qdrant-net
```

### API Not Responding

```bash
# Check if container is running
docker ps | grep qdrant

# Check port binding
docker port qdrant

# Test health endpoint
curl http://localhost:6333/healthz

# Check container logs for errors
docker logs qdrant --tail 50
```

### High Memory Usage

```bash
# Check current usage
docker stats qdrant

# Qdrant memory usage grows with:
# - Number of collections
# - Number of vectors
# - Vector dimensions
# - Payload size

# Optimize by:
# - Using quantization (reduces memory)
# - Setting on_disk storage for large collections
# - Implementing collection lifecycle management
```

### Network Connectivity Issues

```bash
# Test from another container
docker run --rm --network qdrant-net alpine ping -c 3 qdrant

# Test DNS resolution
docker run --rm --network qdrant-net alpine nslookup qdrant

# Check network connections
docker network inspect qdrant-net
```

### Collection Performance Issues

```bash
# Check collection stats
curl http://linuxserver.lan:6333/collections/my_collection

# Enable quantization for faster search
curl -X PUT http://linuxserver.lan:6333/collections/my_collection \
  -d '{
    "vectors": {
      "size": 384,
      "distance": "Cosine"
    },
    "quantization_config": {
      "scalar": {
        "type": "int8",
        "quantile": 0.99
      }
    }
  }'
```

## Performance Optimization

### Indexing

Qdrant uses HNSW (Hierarchical Navigable Small World) by default:

```python
# Configure HNSW parameters
client.create_collection(
    collection_name="optimized_collection",
    vectors_config={
        "size": 384,
        "distance": "Cosine"
    },
    hnsw_config={
        "m": 16,  # Number of edges per node (default: 16)
        "ef_construct": 100,  # Search quality during construction (default: 100)
    }
)

# Set search precision
client.search(
    collection_name="optimized_collection",
    query_vector=[...],
    search_params={"hnsw_ef": 128}  # Higher = better quality, slower
)
```

### On-Disk Storage (for large collections)

```python
# Use on-disk storage to reduce memory
client.create_collection(
    collection_name="large_collection",
    vectors_config={
        "size": 1536,
        "distance": "Cosine",
        "on_disk": True  # Store vectors on disk
    }
)
```

### Quantization (reduce memory)

```python
# Use scalar quantization
client.update_collection(
    collection_name="my_collection",
    quantization_config={
        "scalar": {
            "type": "int8",
            "quantile": 0.99
        }
    }
)
```

## Security Considerations

- **No Authentication**: Local network deployment only
- **Network Isolation**: qdrant-net provides service-level isolation
- **Port Exposure**: Only to LAN (0.0.0.0:6333), not internet-exposed
- **Data Encryption**: Not enabled (local deployment)

**For Production**:
- Enable API key authentication if needed
- Configure TLS for gRPC
- Implement application-level access control
- Regular backups of critical collections

## File Locations

### Project Directory
```
/home/administrator/projects/qdrant/
├── docker-compose.yml    # Container configuration
├── deploy.sh             # Deployment script
└── CLAUDE.md            # This documentation
```

### Data Directory
- **Location**: /home/administrator/projects/data/qdrant (bind mount)
- **Mount Point**: /qdrant/storage (inside container)
- **Contains**: Collections, indexes, snapshots
- **Migration Date**: 2025-11-02 (converted from Docker volume to bind mount)

### Logs
- **Container Logs**: `docker logs qdrant`
- **Loki/Grafana**: `{container_name="qdrant"}`

## Future Enhancements

- [ ] Enable quantization for memory optimization
- [ ] Set up automated snapshot backups
- [ ] Configure Prometheus metrics collection
- [ ] Create Grafana dashboard for Qdrant metrics
- [ ] Document collection lifecycle management
- [ ] Implement collection archival strategy

## References

- **Official Docs**: https://qdrant.tech/documentation/
- **Python Client**: https://github.com/qdrant/qdrant-client
- **JavaScript Client**: https://github.com/qdrant/qdrant-js
- **REST API**: https://qdrant.github.io/qdrant/redoc/index.html

---

**Created**: 2025-11-02
**Last Updated**: 2025-11-02
**Maintained By**: Infrastructure Team
**Next Service**: mem0 (will consume this infrastructure)
