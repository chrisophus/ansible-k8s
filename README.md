# Kubernetes HA Homelab with Ansible

A production-grade 3-node HA Kubernetes cluster deployment using Ansible, featuring:
- **High Availability**: 3 control plane nodes with keepalived VIP
- **Networking**: Calico CNI with proper IPAM
- **Security**: Automatic updates with reboot management
- **Foundation**: Ready for application deployment via Helm

## Architecture

```
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│    node1    │  │    node2    │  │    node3    │
│ (control)   │  │ (control)   │  │ (control)   │
│   prio:110  │  │   prio:100  │  │   prio:90   │
└─────────────┘  └─────────────┘  └─────────────┘
       │                │                │
       └────────────────┼────────────────┘
                        │
                 VIP: 192.168.1.100
```

## Prerequisites

- 3 Ubuntu 22.04+ servers with sudo access
- 4GB+ RAM and 2+ CPU cores per node
- Network connectivity between all nodes
- SSH key-based authentication configured

## Quick Start

1. **Clone and configure**:
   ```bash
   git clone <this-repo>
   cd ansible-k8s-homelab
   ```

2. **Edit inventory.ini** with your actual hosts:
   ```ini
   [controlplane]
   node1 ansible_host=192.168.1.10 keepalived_priority=110
   node2 ansible_host=192.168.1.11 keepalived_priority=100
   node3 ansible_host=192.168.1.12 keepalived_priority=90

   [all:vars]
   ansible_user=your-ssh-user
   ```

3. **Configure variables** in `group_vars/all.yml`:
   ```yaml
   # Network configuration
   network_interface: "eth0"
   cluster_vip: "192.168.1.100"
   keepalived_password: "your-secure-password"

   # Monitoring passwords
   grafana_password: "your-grafana-password"
   ```

4. **Validate configuration**:
   ```bash
   # Validate your configuration (recommended)
   ansible-playbook -i inventory.ini validate-config.yml
   ```

5. **Verify playbook syntax** (catches task/YAML errors before deploy):
   ```bash
   ./verify-syntax.sh
   # Or with a specific inventory: ./verify-syntax.sh my-inventory.ini
   ```

6. **Deploy the cluster**:
   ```bash
   # Deploy base cluster
   ansible-playbook -i inventory.ini site.yml
   ```

## Components

### Core Cluster
- **Kubernetes**: v1.35.x with kubeadm
- **CNI**: Calico with IPAM
- **Load Balancer**: keepalived with VIP
- **Runtime**: containerd
- **Security**: Automatic updates with scheduled reboots
- **Metrics**: metrics-server (for `kubectl top nodes` / `kubectl top pods`)

### Post-Deployment Applications
- **Storage**: Run `deploy-storage.yml` to install Rancher local-path (default StorageClass so PVCs bind). Optional: Longhorn for replicated storage (see Next Steps).
- **Monitoring**: Prometheus/Grafana stack (Helm)
- **Applications**: Plex, Jellyfin, or other services

## Access Points

After deployment:

- **Kubernetes API**: `https://<cluster_vip>:6443`
- **kubectl**: Configure with `scp user@<any-node>:~/.kube/config ~/.kube/config`

## Configuration

### Network Settings
Configure in `group_vars/all.yml`:
```yaml
network_interface: "eth0"           # Your network interface
cluster_vip: "192.168.1.100"       # VIP for HA
keepalived_password: "secure-pass"  # keepalived auth
```

## Playbooks

- `site.yml` - Main cluster deployment (includes metrics-server).
- `deploy-storage.yml` - Install Rancher local-path provisioner (default StorageClass). Run after `site.yml` so PVCs (e.g. Postgres) can bind.
- `validate-config.yml` - Configuration validation
- `merge-kubeconfig.yml` - Merge this cluster into local `~/.kube/config` (unique name, set as current context; does not overwrite existing config)
- `create-k8s-readonly-client-cert.yml` - For **kubeadm** clusters (this repo): bind `k8s_readonly_client_username` to built-in `view` plus a small extra ClusterRole for read-only `nodes`/`nodes/status` (built-in `view` does not allow `kubectl get nodes`), sign an X.509 client cert with `/etc/kubernetes/pki/ca.{crt,key}` on the first control-plane, and fetch a read-only kubeconfig to the Ansible controller (see `group_vars/all.yml`)
- `reset-k8s-only.yml` - Cluster reset/cleanup

**Single-role playbooks** (no manual steps; run when you need only that component on an existing cluster):

- `security.yml` - Re-run security role only (e.g. after adding UFW rules like kubelet 10250). Example: `ansible-playbook -i inventory.ini security.yml`
- `metrics-server.yml` - Install or update metrics-server only (for `kubectl top nodes` / `kubectl top pods`). Example: `ansible-playbook -i inventory.ini metrics-server.yml`

## Maintenance

### Resuming after a failed run
If the playbook fails (e.g. at `Initialize Kubernetes cluster`) and you’ve fixed the cause (e.g. containerd config, reset the node), you can resume from that task instead of re-running everything:

```bash
ansible-playbook -i inventory.ini site.yml --start-at-task "Initialize Kubernetes cluster (only on first control-plane)"
```

This skips the common, security, keepalived, and earlier controlplane tasks and runs from `kubeadm init` onward. Use a full run (no `--start-at-task`) if you changed base setup (e.g. `group_vars`, containerd, or packages).

### Adding Nodes
See `README-adding-nodes.md` for detailed instructions.

### Backup
```bash
# Backup etcd
kubectl -n kube-system get secret etcd-certs -o yaml > etcd-backup.yaml

# Application data backups depend on your storage solution
```

### Updates
```bash
# Update Kubernetes version in group_vars/all.yml, then:
ansible-playbook -i inventory.ini site.yml
```

## Next Steps: Application Deployment

After your cluster is running:

### Storage (default StorageClass for PVCs)
```bash
ansible-playbook -i inventory.ini deploy-storage.yml
```
Installs Rancher local-path provisioner and sets it as the default StorageClass. Workloads that use PVCs without a `storageClassName` (e.g. marketplace-cp Postgres) will bind. For replicated storage instead, install Longhorn manually:
```bash
helm repo add longhorn https://charts.longhorn.io
helm repo update
helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace
```

### Prometheus/Grafana Stack
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace
```

## Troubleshooting

### Common Issues

1. **Control plane pods never start (runc exit 127 / permission denied)**  
   On Ubuntu, the runc package’s AppArmor profile can block runc from loading libseccomp and starting containers. The playbook disables this profile (`aa-disable runc`) so the control plane can start. If you manage AppArmor yourself, ensure the runc profile is disabled or adjusted for Kubernetes.

2. **VIP not responding**:
   ```bash
   # Check keepalived status
   ansible all -i inventory.ini -m shell -a "systemctl status keepalived"
   ```

3. **Calico (CNI) not ready** (pods 0/1, "BGP not established"):
   - **Preferred fix (no BGP):** Switch to Calico VXLAN so readiness does not depend on BGP. Run once:
     ```bash
     ansible-playbook -i inventory.ini switch-calico-vxlan.yml
     ```
     New installs use VXLAN by default (`calico_use_vxlan: true` in `group_vars/all.yml`).
   - **Alternative (keep BGP):** Open TCP **179** between nodes (e.g. `ufw allow from <cluster_node_cidr> to any port 179 proto tcp`), re-run the security role, then `kubectl -n kube-system rollout restart daemonset calico-node`.
   - For more detail: `ansible-playbook -i inventory.ini calico-diagnostics.yml`
   - If nodes are NotReady, or ImagePullBackOff / CrashLoopBackOff, see README and logs.

4. **Pods stuck pending**:
   ```bash
   # Check node resources
   kubectl describe nodes
   kubectl get events --sort-by=.metadata.creationTimestamp
   ```

5. **Storage issues**:
   ```bash
   # Check storage driver status (depends on your solution)
   kubectl get pods -n <storage-namespace>
   kubectl get pv,pvc --all-namespaces
   ```

### Logs
```bash
# Cluster logs
kubectl logs -n kube-system -l component=kube-apiserver
kubectl logs -n kube-system -l k8s-app=calico-node

# Application logs (examples)
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus
kubectl logs -n <app-namespace> -l app=<app-name>
```

## Security Notes

- Change default passwords in `group_vars/all.yml`
- Use vault encryption for sensitive variables:
  ```bash
  ansible-vault encrypt group_vars/secrets.yml
  ```
- Configure firewall rules for cluster ports
- Use TLS for all external access

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test your changes
4. Submit a pull request

## Support

For issues and questions:
- Check the troubleshooting section
- Review Kubernetes and component documentation
- Open an issue with detailed logs and configuration