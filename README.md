# 🚀 LevelDB SRE Challenge - Resilient Kubernetes Deployment

## 📋 Overview

This project implements a production-ready, resilient LevelDB application deployment on Kubernetes with comprehensive backup, monitoring, scaling, and disaster recovery capabilities.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Kubernetes Cluster                       │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   Ingress       │  │   Monitoring    │  │   Backup        │  │
│  │   Controller    │  │   Stack         │  │   System        │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│           │                     │                     │         │
│           ▼                     ▼                     ▼         │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    LevelDB StatefulSet                    │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │  │
│  │  │   Pod-0     │  │   Pod-1     │  │   Pod-2     │        │  │
│  │  │ (Primary)   │  │ (Read Repl) │  │ (Read Repl) │        │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘        │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                  │
│                              ▼                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    Persistent Storage                     │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │  │
│  │  │   PVC-0     │  │   PVC-1     │  │   PVC-2     │        │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘        │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## 🎯 Key Features

### ✅ **Resilience & Recovery**
- **StatefulSet** with stable network identities
- **Pod Disruption Budget** for high availability
- **Liveness & Readiness probes** with proper timeouts
- **Resource limits** and requests for stability
- **Non-root container** execution for security

### ✅ **Backup & Restore**
- **Restic** integration with S3 backend
- **Automated backups** every 6 hours (configurable)
- **LVM snapshots** for consistent backups
- **Backup verification** and cleanup
- **Disaster recovery** procedures

### ✅ **Scalability**
- **Horizontal Pod Autoscaler** (1-3 replicas)
- **CPU/Memory-based scaling** policies
- **Read replicas** for LevelDB
- **Vertical scaling** capabilities

### ✅ **Monitoring & Observability**
- **Prometheus** metrics collection
- **Grafana** dashboards
- **Custom application metrics**
- **Alert rules** for critical issues
- **Service monitoring**

### ✅ **Security**
- **Network policies** for pod isolation
- **Pod Security Standards** enforcement
- **RBAC** with least privilege
- **TLS/SSL** support via ingress
- **Service accounts** for operations

## 🚀 Quick Start

### Prerequisites

### 🧱 1. Environment Setup

```bash
# Install LVM and Restic
sudo apt update && sudo apt install -y lvm2 restic curl nano git jq wget gnupg2 software-properties-common vim zip apt-transport-https ca-certificates

# Install k3s (includes kubectl)
curl -sfL https://get.k3s.io | sh -

# Verify k3s is running
sudo kubectl get nodes

# Set up kubectl for non-root usage

mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
export KUBECONFIG=$HOME/.kube/config
echo 'export KUBECONFIG=$HOME/.kube/config' >> ~/.bashrc
source ~/.bashrc

# Confirm access
kubectl get pods -A
```

### 🛠️ 2. Install Required Tools (Docker, Helm, LVM, Restic, etc.)

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add current user to docker group (optional)
sudo usermod -aG docker $USER
newgrp docker

# Configure Docker
docker login

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# NOTE: No need to install kubectl separately — k3s includes it.
```

### 🛠️ 3. Create And Mount Volume

```bash
# Check LVM version
sudo lvdisplay --version

# Create physical volume, volume group, and logical volume (example)
sudo pvcreate /dev/sdb
sudo vgcreate vgdata /dev/sdb
sudo lvcreate -L 2048G -n lvleveldb vgdata

# Format and mount LVM volume
sudo mkfs.ext4 /dev/vgdata/lvleveldb
sudo mkdir -p /data/leveldb
sudo mount /dev/vgdata/lvleveldb /data/leveldb

# Verify and make sure the mount is working correctly
df -h /data/leveldb && mount | grep leveldb

# Make the mount persists across reboots
echo "/dev/mapper/vgdata-lvleveldb /data/leveldb ext4 defaults 0 2" | sudo tee -a /etc/fstab
```

### 1. Configure Secrets

Update the backup secrets with your AWS credentials:

```bash
# Edit backup/restic-secret.yaml with your actual credentials
kubectl apply -f backup/restic-secret.yaml
```

### 2. Build and Push Docker Image

```bash
# Make build script executable
chmod +x build-and-push.sh

# Build and push the LevelDB Docker image
./build-and-push.sh
```

### 3. Deploy Basic Application

```bash
# Make deployment script executable
chmod +x simple-deploy.sh

# Run the basic deployment
./simple-deploy.sh
```

### 4. Deploy All Components (Optional)

```bash
# Make deployment script executable
chmod +x deploy-all.sh

# Run the complete deployment with all features
./deploy-all.sh
```

### 5. Deploy Components Individually (Optional)

```bash
# Deploy components step by step
./deploy-security.sh      # Security policies
./deploy-backup.sh        # Backup system
./deploy-monitoring.sh    # Monitoring stack
./deploy-ingress.sh       # Ingress controller
./deploy-ssl.sh          # SSL/TLS certificates
./deploy-scalability.sh   # Auto-scaling
```

### 6. Verify Deployment

```bash
# Check all components
kubectl get all -n leveldb
kubectl get pvc -n leveldb
kubectl get hpa -n leveldb

# Test the application on localhost
kubectl port-forward svc/leveldb-service -n leveldb 8080:8080

# In another terminal
curl -X POST 'http://localhost:8080/write?key=test&value=hello'
curl 'http://localhost:8080/read?key=test'
curl 'http://localhost:8080/health'
curl 'http://localhost:8080/metrics'
```

## 📊 Monitoring

### Access Grafana Dashboard

```bash
# Internal access
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80

# External access (if ingress is configured)
# https://grafana.leveldb.setupwp.io
```

**Default credentials:**
- Username: `admin`
- Password: `prom-operator`

### Access Prometheus

```bash
# Internal access
kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n monitoring 9090:9090

# External access (if ingress is configured)
# https://prometheus.leveldb.setupwp.io
```

### Key Metrics

- **Application Metrics:**
  - `leveldb_requests_total` - Total requests by endpoint
  - `leveldb_request_duration_seconds` - Request latency
  - `leveldb_database_size_bytes` - Database size
  - `leveldb_memory_usage_bytes` - Memory usage

- **Infrastructure Metrics:**
  - Pod restart count
  - CPU/Memory utilization
  - PVC storage usage
  - Backup job status

## 🔄 Backup & Restore

### Manual Backup

```bash
# Trigger manual backup
kubectl create job --from=cronjob/leveldb-backup manual-backup -n leveldb

# Check backup status
kubectl get jobs -n leveldb
kubectl logs job/manual-backup -n leveldb
```

### Disaster Recovery

```bash
# Run disaster recovery
chmod +x disaster-recovery/restore.sh
./disaster-recovery/restore.sh
```

## 🔧 Configuration

### Scaling Configuration

Edit `scaling/hpa.yaml` to adjust scaling policies:

```yaml
spec:
  minReplicas: 1
  maxReplicas: 3
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Backup Schedule

Edit `backup/backup-cronjob.yaml` to change backup frequency:

```yaml
spec:
  schedule: "0 */6 * * *"  # Every 6 hours
```

### Resource Limits

Edit `app/leveldb-statefulset.yaml` to adjust resource allocation:

```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "1Gi"
    cpu: "500m"
```

## 🛠️ Troubleshooting

### Common Issues

1. **Pod stuck in Pending:**
   ```bash
   kubectl describe pod -n leveldb
   kubectl get events -n leveldb
   ```

2. **Backup failures:**
   ```bash
   kubectl logs -l job-name=leveldb-backup -n leveldb
   kubectl describe secret restic-secret -n leveldb
   ```

3. **Storage issues:**
   ```bash
   kubectl get pvc -n leveldb
   kubectl describe pvc -n leveldb
   ```

4. **Monitoring not working:**
   ```bash
   kubectl get servicemonitor -n monitoring
   kubectl get prometheusrule -n monitoring
   ```

### Logs

```bash
# Application logs
kubectl logs -l app=leveldb -n leveldb

# Backup job logs
kubectl logs -l job-name=leveldb-backup -n leveldb

# Monitoring logs
kubectl logs -l app=prometheus -n monitoring
```

## 🔒 Security Considerations

### Network Security

- **Network Policies** restrict pod-to-pod communication
- **Ingress** with TLS termination
- **Service mesh** ready (can be added)

### Access Control

- **RBAC** with minimal required permissions
- **Service accounts** for different operations
- **Pod Security Standards** enforcement

### Data Protection

- **Encrypted backups** with Restic
- **TLS** for data in transit
- **Non-root containers** for security

## 📈 Performance Optimization

### Recommendations

1. **Storage:**
   - Use SSD storage for better I/O performance
   - Consider local storage for low latency
   - Monitor storage usage and expand as needed

2. **Scaling:**
   - Adjust HPA thresholds based on load testing
   - Consider vertical scaling for single-threaded workloads
   - Monitor resource usage patterns

3. **Monitoring:**
   - Set up alerting for performance degradation
   - Monitor backup performance impact
   - Track application-specific metrics

## 🚀 Production Deployment

### Migration Strategy

1. **Phase 1: Infrastructure Setup**
   - Deploy Kubernetes cluster
   - Set up monitoring and logging
   - Configure backup systems

2. **Phase 2: Application Deployment**
   - Deploy LevelDB StatefulSet
   - Configure ingress and TLS
   - Set up network policies

3. **Phase 3: Data Migration**
   - Stop existing application
   - Backup existing data
   - Restore to Kubernetes
   - Verify data integrity

4. **Phase 4: Testing & Validation**
   - Load testing
   - Failover testing
   - Backup/restore testing
   - Performance validation

5. **Phase 5: Go-Live**
   - Switch traffic to new deployment
   - Monitor closely for issues
   - Keep old system as fallback

### High Availability Setup

For production environments, consider:

- **Multi-zone deployment** across availability zones
- **Load balancer** for external access
- **Database clustering** or read replicas
- **Automated failover** procedures
- **Regular disaster recovery** drills

## 📚 Additional Resources

- [Kubernetes StatefulSets Documentation](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [Restic Backup Documentation](https://restic.readthedocs.io/)
- [Prometheus Monitoring](https://prometheus.io/docs/)
- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)

## 🤝 Contributing

This is a proof-of-concept implementation. For production use:

1. Review and customize all configurations
2. Test thoroughly in staging environment
3. Implement proper CI/CD pipelines
4. Add comprehensive logging and monitoring
5. Document operational procedures
6. Train operations team

---
