# reset-k8s role

Resets Kubernetes from all nodes (kubeadm reset, package removal, iptables cleanup). Use when tearing down the cluster or before a clean reinstall.

## If nodes are unreachable after a reset (SSH lockout)

If an older run of this role flushed the **filter** table (or you ran `iptables -F` globally), firewall rules that allow SSH may have been removed and the nodes will no longer accept SSH.

**Fix: use out-of-band access, then restore SSH in the firewall.**

1. **Get a shell on each node without SSH**
   - Physical console (monitor + keyboard), or
   - IPMI / iLO / BMC, or
   - Cloud serial console (e.g. AWS EC2 Serial Console, GCP Serial Console, Azure Serial Console)

2. **On each node, restore SSH access**

   If the nodes use **UFW** (this repo’s security role does):

   ```bash
   sudo ufw allow 22/tcp
   sudo ufw enable
   # or, if UFW was already enabled and only rules were lost:
   sudo ufw reload
   ```

   If you prefer a one-off iptables rule (no UFW):

   ```bash
   sudo iptables -I INPUT -p tcp --dport 22 -j ACCEPT
   ```

3. **Verify**  
   From your laptop: `ssh <user>@<node-ip>`.

4. **Re-run reset or site**  
   After SSH is back, you can run the (updated) reset playbook again or run `site.yml` for a fresh deploy. The role no longer flushes the filter table, so future resets will not lock you out.
