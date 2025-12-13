# Couchbase Vector Database Setup Guide

## 📋 Overview

This guide explains how to set up and configure Couchbase as the vector database for Ell-ena's meeting search functionality. Couchbase offers one of the fastest vector databases in the market with built-in caching, horizontal scalability, and multi-model capabilities.

## 🎯 Why Couchbase?

### Performance Benefits
- **Sub-millisecond latency** for vector similarity search
- **Built-in caching** reduces database load
- **Horizontal scaling** for millions of embeddings
- **Multi-model database** combines documents and vectors

### vs PostgreSQL (pgvector)
| Feature | Couchbase | PostgreSQL (pgvector) |
|---------|-----------|----------------------|
| **Search Speed** | Sub-millisecond | 10-100ms |
| **Scalability** | Horizontal | Vertical (limited) |
| **Caching** | Built-in | External required |
| **Replication** | Multi-master | Master-slave |
| **Vector Dimensions** | Unlimited | Limited by RAM |

## 🛠️ Prerequisites

- Couchbase Server 7.6+ (with Full-Text Search)
- Admin access to Couchbase cluster
- Flutter app with vector database abstraction layer

## 📦 Installation Steps

### 1. Install Couchbase Server

#### Option A: Docker (Recommended for Development)
```bash
docker run -d --name couchbase \
  -p 8091-8096:8091-8096 \
  -p 11210-11211:11210-11211 \
  couchbase:enterprise-7.6.0

# Access Web Console at http://localhost:8091
```

#### Option B: Direct Installation
- Download from: https://www.couchbase.com/downloads
- Follow platform-specific installation guide

### 2. Configure Couchbase Cluster

1. **Access Web Console**: Navigate to `http://localhost:8091`

2. **Setup Cluster**:
   - Click "Setup New Cluster"
   - Set cluster name: `ell-ena-cluster`
   - Create admin credentials
   - Configure memory quotas:
     - Data Service: 1024 MB
     - Index Service: 512 MB
     - Search Service: 512 MB

3. **Enable Services**:
   - ✅ Data
   - ✅ Query
   - ✅ Index
   - ✅ Search (Required for vector search)

### 3. Create Bucket and Scope

```sql
-- Create bucket
CREATE BUCKET `ell-ena` WITH {
  "ramQuota": 1024,
  "replicaNumber": 1
};

-- Create scope (optional, defaults to _default)
CREATE SCOPE `ell-ena`.`meetings`;

-- Create collection
CREATE COLLECTION `ell-ena`.`meetings`.`embeddings`;
```

Or via Web Console:
1. Go to **Buckets** → **Add Bucket**
2. Name: `ell-ena`
3. Memory Quota: 1024 MB
4. Enable Replicas: 1

### 4. Create Vector Search Index

#### Via N1QL Query Editor:
```sql
-- Create Full-Text Search index for vector similarity
CREATE INDEX vector_index ON `ell-ena`.`_default`.`_default`(embedding) 
USING FTS WITH {
  "type": "fulltext-index",
  "name": "vector_index",
  "sourceType": "gocbcore",
  "sourceName": "ell-ena",
  "planParams": {
    "maxPartitionsPerPIndex": 16,
    "indexPartitions": 6
  },
  "params": {
    "doc_config": {
      "mode": "scope.collection.type_field",
      "type_field": "type"
    },
    "mapping": {
      "default_mapping": {
        "enabled": false
      },
      "types": {
        "meeting_embedding": {
          "enabled": true,
          "properties": {
            "embedding": {
              "enabled": true,
              "fields": [
                {
                  "name": "embedding",
                  "type": "vector",
                  "dims": 768,
                  "similarity": "dot_product",
                  "vector_index_optimized_for": "recall"
                }
              ]
            },
            "metadata": {
              "enabled": true,
              "dynamic": true
            }
          }
        }
      }
    }
  }
}
```

#### Via Web Console:
1. Go to **Search** → **Add Index**
2. Index Name: `vector_index`
3. Bucket: `ell-ena`
4. Type Mappings:
   - Type: `meeting_embedding`
   - Add Field: `embedding`
   - Field Type: **Vector**
   - Dimensions: `768`
   - Similarity: `dot_product`
5. Click **Create Index**

### 5. Verify Index Creation

```sql
-- Check index status
SELECT * FROM system:indexes 
WHERE name = 'vector_index';

-- Wait for index to be online
-- Status should be "online"
```

## ⚙️ Application Configuration

### 1. Update Environment Variables

Add to `.env` file:
```env
# Couchbase Configuration
COUCHBASE_URL=http://localhost:8091
COUCHBASE_USERNAME=Administrator
COUCHBASE_PASSWORD=your_password
COUCHBASE_BUCKET=ell-ena
```

### 2. Switch to Couchbase in App

The app now supports runtime switching between vector databases:

```dart
// In your app initialization
final aiService = AIService();
await aiService.initialize();

// Switch to Couchbase
await aiService.vectorDbFactory.updateCouchbaseConfig(
  url: 'http://your-couchbase-server:8091',
  username: 'Administrator',
  password: 'your_password',
  bucket: 'ell-ena',
);

await aiService.vectorDbFactory.switchProvider(
  VectorDbProvider.couchbase,
  supabaseClient,
);
```

## 🔄 Migration from pgvector

### Option 1: Dual-Write Strategy (Recommended)

Write to both databases during migration:

```dart
// Store embeddings in both databases
await pgVectorDb.storeEmbedding(
  id: meetingId,
  embedding: embeddingVector,
  metadata: metadata,
);

await couchbaseDb.storeEmbedding(
  id: meetingId,
  embedding: embeddingVector,
  metadata: metadata,
);
```

### Option 2: Bulk Migration Script

```dart
// Migration script to copy all embeddings
Future<void> migrateEmbeddings() async {
  final pgVector = PgVectorDatabase(supabaseClient);
  final couchbase = CouchbaseVectorDatabase(/* config */);
  
  // Fetch all meetings with embeddings from PostgreSQL
  final meetings = await supabaseClient
      .from('meetings')
      .select('id, summary_embedding, meeting_summary_json')
      .not('summary_embedding', 'is', null);
  
  for (final meeting in meetings) {
    await couchbase.storeEmbedding(
      id: meeting['id'],
      embedding: List<double>.from(meeting['summary_embedding']),
      metadata: meeting['meeting_summary_json'],
    );
  }
  
  print('✅ Migrated ${meetings.length} embeddings to Couchbase');
}
```

## 🧪 Testing the Setup

### 1. Test Connection

```dart
final factory = VectorDatabaseFactory();
final isHealthy = await factory.testCouchbaseConnection(
  url: 'http://localhost:8091',
  username: 'Administrator',
  password: 'your_password',
  bucket: 'ell-ena',
);

print(isHealthy ? '✅ Connection successful' : '❌ Connection failed');
```

### 2. Test Vector Operations

```dart
// Store test embedding
final testId = 'test-meeting-123';
final testEmbedding = List.generate(768, (i) => i / 768.0);
final testMetadata = {
  'title': 'Test Meeting',
  'meeting_date': DateTime.now().toIso8601String(),
};

final success = await couchbaseDb.storeEmbedding(
  id: testId,
  embedding: testEmbedding,
  metadata: testMetadata,
);

// Search similar
final results = await couchbaseDb.searchSimilar(
  queryEmbedding: testEmbedding,
  limit: 5,
);

print('Found ${results.length} similar vectors');
```

## 📊 Performance Tuning

### Memory Configuration

Adjust memory quotas based on expected data:

```
Data Size Estimate:
- 1 embedding = 768 dimensions × 8 bytes = 6KB
- 1 million embeddings = ~6GB
- Add 50% overhead = ~9GB recommended
```

### Index Optimization

```json
{
  "vector_index_optimized_for": "recall",  // vs "latency"
  "quantization_bits": 8,  // Reduce from 32 for speed
  "max_num_candidates": 1000,
  "ef_construction": 200,
  "ef_search": 100
}
```

### Caching Strategy

Couchbase automatically caches frequently accessed documents. For additional optimization:

1. **Enable bucket-level caching**
2. **Use memory-optimized storage**
3. **Configure replica vBuckets**

## 🔒 Security Best Practices

### 1. Enable TLS/SSL

```dart
final couchbase = CouchbaseVectorDatabase(
  clusterUrl: 'https://your-cluster.com:18091',  // Use HTTPS
  username: username,
  password: password,
  bucketName: bucketName,
);
```

### 2. Use Role-Based Access Control (RBAC)

```sql
-- Create read-only user for application
CREATE USER `ell-ena-app` WITH PASSWORD 'secure_password';

GRANT SELECT, FTS_SEARCHER 
ON BUCKET `ell-ena` 
TO `ell-ena-app`;
```

### 3. Rotate Credentials Regularly

Store credentials in secure vaults:
- AWS Secrets Manager
- Azure Key Vault
- HashiCorp Vault

## 🚨 Troubleshooting

### Issue: "Index not found"

**Solution**: Verify index creation:
```sql
SELECT * FROM system:indexes WHERE name = 'vector_index';
```

### Issue: "Connection timeout"

**Solutions**:
1. Check firewall rules (ports 8091-8096, 11210-11211)
2. Verify Couchbase service is running
3. Test network connectivity

### Issue: "Slow search performance"

**Solutions**:
1. Increase memory quota for Search service
2. Optimize index parameters
3. Use quantization for faster searches
4. Add more Search nodes to cluster

### Issue: "Out of memory"

**Solutions**:
1. Increase bucket memory quota
2. Enable data compression
3. Use eviction policies
4. Scale horizontally (add nodes)

## 📈 Monitoring

### Key Metrics to Track

1. **Search Latency**: Target < 50ms
2. **Index Build Time**: Depends on data size
3. **Memory Usage**: Should stay < 80%
4. **Cache Hit Rate**: Target > 90%

### Monitoring Tools

- **Couchbase Web Console**: Built-in monitoring
- **Prometheus Integration**: Export metrics
- **Custom Dashboard**: Track application-level metrics

## 🔄 Backup and Restore

### Backup Strategy

```bash
# Backup bucket
cbbackup http://localhost:8091 /backup/path \
  -u Administrator -p password \
  -b ell-ena

# Backup index definitions
curl -u Administrator:password \
  http://localhost:8091/api/index/vector_index \
  > vector_index_backup.json
```

### Restore Procedure

```bash
# Restore bucket data
cbrestore /backup/path http://localhost:8091 \
  -u Administrator -p password \
  -b ell-ena

# Restore index (recreate from backup JSON)
curl -X PUT -u Administrator:password \
  http://localhost:8091/api/index/vector_index \
  -d @vector_index_backup.json
```

## 📚 Additional Resources

- **Official Docs**: https://docs.couchbase.com/server/current/fts/vector-search.html
- **SDK Reference**: https://docs.couchbase.com/mobile/3.1/couchbase-lite-dart/index.html
- **Best Practices**: https://docs.couchbase.com/server/current/learn/services-and-indexes/indexes/index-replication.html
- **Community Forum**: https://forums.couchbase.com/

## 🎓 Next Steps

1. ✅ Complete initial setup and testing
2. ✅ Migrate existing embeddings
3. ✅ Monitor performance metrics
4. 🔄 Optimize index parameters
5. 🔄 Set up production cluster
6. 🔄 Implement backup automation
7. 🔄 Configure monitoring alerts

---

**Questions or Issues?**  
Open an issue on GitHub or contact the development team.
