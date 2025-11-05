# Lab ANS03 - Ansible Inventories

## Objective
Use Ansible inventories to configure the hosts available during playbook execution

## Outcomes
By the end of this lab, you will have:
* Created an inventory file to configure Ansible access to remote hosts
* Executed a playbook against a set of remote hosts
* Used a _dynamic inventory_ to automatically register new hosts

## High-Level Steps
* Configure SSH keys
* Use the provided Terraform files to provision some VMs
* Create and use a static inventory of VM IPs
* Create and use a dynamic inventory

## Detailed Steps

### Configure SSH Keys
When connecting to remote linux hosts, Ansible uses SSH. This means we will need an SSH key that Ansible can use to connect to the instances we will be working with. Generate a new SSH key pair
```bash
cd ~/ansible-labs/lab03 # ensure we are in the lab03 folder
ssh-keygen -q -t ed25519 -f $(pwd)/ansible_key # hit enter on both passphrase prompts to create the key without a passphrase
```

### Provision Instances
Now that we have a key pair, we can provision some instances. The lab03 folder already contains the necessary Terraform files to deploy a set of VMs onto a network with access to required ports. Provision the infrastructure by following the usual terraform workflow:
```bash
terraform init
terraform plan -var gcp_project=<gcp project from qwiklabs> -var pubkey_path=$(pwd)/ansible_key.pub
terraform apply -var gcp_project=<gcp project from qwiklabs> -var pubkey_path=$(pwd)/ansible_key.pub
```
Wait for the apply to finish. Once the apply is complete, make a note of the _external_ IPs of your VMs as displayed by the Terraform outputs.

### Connectivity Check
Before continuing, it would be a good idea to check that everything is configured correctly for SSH. For each of the IP addresses output by terraform, run the following:
```bash
ssh -i ./ansible_key ansible@<ip_address>
```
When prompted, enter 'yes' to trust the host keys from the VMs.  
Note: the username 'ansible' is important, as this is the username for which the public SSH key has been added to the VMs.

### Creating the inventory
So far we have used Ansible to execute tasks against the cloudshell machine on which we are running Ansible. In reality, we would like to be able to configure hosts remotely, and for this Ansible needs information about the target hosts, which we store in an _inventory_ file. Create a new file in lab03, called inventory.yml, and add the following:
```yaml
all:
  children:
    test:
      hosts:
        IP_OF_HOST_1: # replace 
        IP_OF_HOST_2: # replace
        IP_OF_HOST_3: # replace
      vars:
        ansible_user: ansible
        ansible_ssh_private_key_file: '~/ansible-labs/lab03/ansible_key'
```
This defines a single group of hosts, called 'all', with one subgroup called 'test'. We have also defined the ansible user and SSH key file to use to make the SSH connection.

### Playbook
Still in the lab03 folder, create a file called _playbook.yml_, with the following contents:
```yaml
---
- hosts: all
  name: Ping Hosts
  tasks:
  - name: "Ping {{ inventory_hostname }}"
    ping:
    register: ping_info
  
  - name: "Show ping_info in console"
    debug:
      msg: "{{ ping_info }}"
```
All this playbook does is tell Ansible to connect to all hosts defined in the inventory file, and run the `ping` module.
This playbook will confirm that we can successfully connect to all of the hosts and execute tasks on them:
```bash
ansible-playbook -v -i inventory.yml playbook.yml
```
You should see output similar to the following, indicating that Ansible was able to connect successfully to the hosts configured in the inventory file:

```text
<output omitted>
TASK [Show ping_info in console] ************************************************************************************
ok: [IP_OF_HOST_1] => {
    "msg": {
        "changed": false, 
        "failed": false, 
        "ping": "pong"
    }
}
ok: [IP_OF_HOST_2] => {
    "msg": {
        "changed": false, 
        "failed": false, 
        "ping": "pong"
    }
}
ok: [IP_OF_HOST_3] => {
    "msg": {
        "changed": false, 
        "failed": false, 
        "ping": "pong"
    }
}

PLAY RECAP **********************************************************************************************************
IP_OF_HOST_1                     : ok=3    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
IP_OF_HOST_2                     : ok=3    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
IP_OF_HOST_3                     : ok=3    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0  
```

### Using a Dynamic Inventory
The inventory file we have just created, with hardcoded host IPs, is called a _static inventory_. This is not particularly useful when configuring environments that have ephemeral infrastructure, with instances being constantly provisioned and deprovisioned. For such environments, we can instead use _dynamic inventories_ to automatically detect and group hosts within a cloud environment.  
Destroy the existing instances, and create new ones:
```bash
terraform destroy -var gcp_project=<project_id_from_qwiklabs> -var pubkey_path=$(pwd)/ansible_key.pub
terraform apply -var gcp_project=<project_id_from_qwiklabs> -var pubkey_path=$(pwd)/ansible_key.pub
```
This will create new instances with new IP addresses.  
Next, add another new file, `inventory.gcp_compute.yml`, with the following contents:
```yaml
plugin: google.cloud.gcp_compute
zones:
  - europe-west1-b
projects:
  - qwiklabs-gcp-XX-XXXXXXXXXXXX # replace with your qwiklabs project ID
filters:
  - status = RUNNING
  - scheduling.automaticRestart = true AND status = RUNNING
auth_kind: application
scopes:
  - 'https://www.googleapis.com/auth/cloud-platform'
  - 'https://www.googleapis.com/auth/compute.readonly'
keyed_groups:
  - prefix: gcp
    key: labels
name_suffix: .qa.com
hostnames:
  - name
compose:
  ansible_host: networkInterfaces[0].accessConfigs[0].natIP
```
This uses a dynamic inventory plugin to construct an inventory consisting of all VMs found in the specified zones for the specified projects. This configuration will also automatically group the detected hosts based on their labels. Verify that the new inventory can detect the new hosts:
```bash
ansible-inventory -i inventory.gcp_compute.yml --list
```
In order to execute playbooks against these dynamically detected hosts, there is one thing missing - the SSH configuration. Since this will not be included in the generated inventory, we will need to define this information somewhere else. One way to do this is via a config file, _ansible.cfg_, in the same directory as our inventory and playbook:
```ini
[defaults]
  remote_user=ansible
  private_key_file=~/ansible-labs/lab03/ansible_key

[ssh_connection]
  ssh_args="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
```
This defines the user and keyfile that were previously set in inventory.yml, and also disables host key checking. You can now use the dynamic inventory to run the same playbook as before against the new hosts:
```bash
ansible-playbook -i inventory.gcp_compute.yml playbook.yml
```

### Clean Up
Destroy the resources you have created:
```bash
terraform destroy -var gcp_project=<gcp project from qwiklabs> -var pubkey_path=$(pwd)/ansible_key.pub
```