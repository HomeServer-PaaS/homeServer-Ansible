# HomeServer Kubernetes Worker Automation

Ansible automation for preparing an Ubuntu on-premises host and joining it as a
Worker to an existing kubeadm Kubernetes cluster. The Controller runs in an
isolated Docker Compose container; Ansible and its collections are not installed
on managed hosts.

## Scope and safeguards

- The read-only preflight checks the worker OS, architecture, hostname, memory,
  free disk, time synchronization, swap, current Kubernetes/runtime state, API
  TCP 6443 reachability, Control Plane version, and API certificate SAN.
- Worker preparation configures kernel modules and sysctls, installs
  containerd, kubeadm, and kubelet, and configures the kubelet Node IP. It
  targets only the selected Worker and does not install or upgrade the
  Control Plane.
- The join playbook creates a short-lived bootstrap token on the Control Plane
  and joins only the selected Worker. The token and join command are hidden
  from Ansible output. It does not run kubeadm reset or retry a partial join.
- Verification reads the Node and relevant kube-system and Calico workload
  status. It creates no test Pods.
- This project does not change firewall, Netplan, router, switch, Wi-Fi, or
  Calico configuration. It does not manage application deployments, storage,
  kubeconfig, or node removal.
- Network and Calico checks are explicit gates. A failed preflight or an
  unconfirmed route, address, or required port is a stop signal. Resolve it
  outside this project before continuing.

## Versions

The example inventory pins Kubernetes packages to 1.37.0 from the v1.37
package repository, containerd to 2.3.6, and runc to 1.5.2. Review these
versions against the existing cluster and your host OS before deployment.
containerd and runc are installed from upstream releases with checksum
validation. Existing unmanaged runtime binaries or configuration cause the
role to stop rather than overwrite them.

## Prerequisites

- A controller with Docker Engine and the Docker Compose plugin.
- A running ssh-agent with the appropriate key loaded.
- SSH aliases and known host keys for the Control Plane and Worker.
- The SSH config and known-hosts file at the paths mounted by compose.yml.
  SSH private-key files are not mounted; authentication uses the forwarded
  agent socket. Host-key checking remains enabled.
- A sudo password for the selected hosts. The run examples prompt for it;
  never place passwords in Inventory or Git.

The Controller uses Docker's default bridge network. Confirm that it can reach
the SSH endpoints and that the Worker can reach the API endpoint. This project
does not alter host or Docker routing.

## Create a private inventory

The committed example inventory uses reserved documentation IP ranges and
example.invalid host aliases. It is not a usable production inventory.

Copy it to the ignored local inventory directory, then replace the example
values with addresses and SSH aliases for your cluster:

    mkdir -p inventory/production
    cp -a inventory/example/. inventory/production/

Edit these files in inventory/production:

- hosts.yml: set the Control Plane and Worker inventory names.
- host_vars/*.yml: set ansible_host to SSH aliases reachable from the
  Controller container.
- group_vars/all.yml: set the Kubernetes API endpoint and versions to match
  the existing cluster and hosts.
- group_vars/onprem_workers.yml: set the Worker Node IP and name.

The inventory/production directory is excluded from Git and Docker build
contexts. Keep credentials and cluster access files out of the repository.
If using Ansible Vault, keep its password file outside the repository.

## Run sequence

Run commands from the project root. These commands are instructions and have
not been executed as part of this documentation.

    docker compose build ansible

    docker compose run --rm ansible ansible all -i inventory/production/hosts.yml -m ping

    docker compose run --rm ansible ansible-playbook -i inventory/production/hosts.yml playbooks/preflight.yml --limit worker-01 --ask-become-pass

Preparation changes the selected Worker:

    docker compose run --rm ansible ansible-playbook -i inventory/production/hosts.yml playbooks/prepare-worker.yml --limit worker-01 --ask-become-pass

Before joining, verify the API certificate and reachability; Control Plane to
Worker TCP 10250; node-to-node VXLAN UDP 4789; Calico Operator address
autodetection; and whether Typha is deployed. If Typha is used, also verify
Worker-to-Typha TCP 5473. Only after checking each applicable path, set the
corresponding confirmation flags in the private Worker inventory to true.
This project does not configure those network paths or Calico.

    docker compose run --rm ansible ansible-playbook -i inventory/production/hosts.yml playbooks/join-worker.yml --limit worker-01 --ask-become-pass

After the join, run read-only verification:

    docker compose run --rm ansible ansible-playbook -i inventory/production/hosts.yml playbooks/verify-worker.yml --limit worker-01 --ask-become-pass

For each additional Worker, add a host and explicit host_vars to the private
inventory. Keep preparation and join limited to one SSH alias at a time.

## Layout

    .
    ├── Dockerfile
    ├── compose.yml
    ├── ansible.cfg
    ├── requirements-controller.txt
    ├── requirements.yml
    ├── inventory/
    │   └── example/
    ├── playbooks/
    └── roles/

The default Ansible inventory points to the safe example inventory. Deployment
commands should explicitly select your private inventory with the -i option.
