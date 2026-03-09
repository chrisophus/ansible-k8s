# SSH setup (one-time)

Same root password on all hosts.

**1. From the repo root, create kubeadmin and deploy the project key:**

```bash
cd /path/to/ansible-k8s-homelab
ansible-playbook -i inventory.ini create-ansible-user-all.yml -k -e "ansible_user=root"
```

Enter the root password when prompted (once).

**2. Test (must run from repo root so `keys/` is found):**

```bash
ansible -i inventory.ini all -m ping
```

You should see `pong` from all three hosts with no password prompt.

**3. Deploy the cluster:**

```bash
ansible-playbook -i inventory.ini site.yml
```

---

If ping still fails, re-run the setup playbook as root to re-deploy the key:

```bash
ansible-playbook -i inventory.ini create-ansible-user-all.yml -k -e "ansible_user=root"
```

Then ping again (from repo root).
