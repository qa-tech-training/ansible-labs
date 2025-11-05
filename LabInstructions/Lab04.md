# Lab ANS04 - Reusable Configuration Best Practices

## Objective
Parameterise Ansible configuration files and enhance the reusability of Ansible config.

## Outcomes
By the end of this lab, you will have:
* Used variables and facts to parameterise an Ansible playbook
* Used Ansible's template module to dynamically alter the contents of a file
* Used handlers to make individual tasks repeatable on-demand
* Used a role to streamline the reuse of Ansible configuration 

## High-Level Steps

## Detailed Steps

### Deploy the Infrastructure
We can use the same terrform files from the previous lab to provision some target infrastructure for this lab. Change directory into lab03 and apply the configuration:
```bash
cd ~/ansible-labs/lab03
terraform plan -var gcp_project=<gcp project from qwiklabs> -var pubkey_path=$(pwd)/ansible_key.pub
terraform apply -var gcp_project=<gcp project from qwiklabs> -var pubkey_path=$(pwd)/ansible_key.pub
```
Make a note of the server IPs and proxy IP outputs, as we will use these later

### Starting Point - Playbook, Inventory and NGINX Configs
Change into the lab04 directory, and review the initial playbook state:
```yaml
---
- hosts: all
  become: true
  tasks:
  - name: Install NGINX
    apt:
      pkg: 
      - nginx
      - git
      state: latest
      update_cache: true
  - name: Start NGINX Service
    service:
      name: nginx
      state: started
- hosts: gcp_role_appserver
  become: true
  tasks:
  - name: 'update website from the git repository'
    git:
      repo: "https://gitlab.com/qacdevops/static-website-example"
      dest: "/opt/static-website-example"
  - name: 'install the nginx.conf file on to the remote machine'
    copy:
      src: nginx-server.conf
      dest: /etc/nginx/nginx.conf
  - name: Restart NGINX Service
    service:
      name: nginx
      state: restarted
- hosts: gcp_role_proxy
  become: true
  tasks:
  - name: transfer_nginx_conf
    copy:
      src: nginx-proxy.conf
      dest: /etc/nginx/nginx.conf
  - name: Restart NGINX Service
    service:
      name: nginx
      state: restarted
```
The logic here is:
* Install NGINX and git on all hosts
* Setup a static website on the appserver hosts, and supply a custom nginx.conf to serve it
* For the proxy, supply a custom NGINX config which will load balance between the appservers.

Next, edit inventory.gcp_compute.yml and fill in your project ID from qwiklabs:
```yaml
projects:
  - qwiklabs-gcp-XX-XXXXXXXXXXXX # <- edit this line
```
Now edit lines 5 and 6 in the nginx-proxy.conf file and add the server IP addresses you noted earlier (Note: be careful to use the server IPs, NOT the proxy IP):
```conf
    upstream appservers {
        server SERVER_1_IP:8080; # <- edit this line
        server SERVER_2_IP:8080; # <- and this one
    }
```
Execute the playbook:
```bash
ansible-playbook -i inventory.gcp_compute.yml playbook.yml
```
Once the execution is complete, navigate to the proxy IP in a browser - you should be presented with the static website.  
Before moving on, destroy and recreate the infrastructure, so that we have a clean slate for the next part of the lab:
```bash
cd ~/ansible-labs/lab03
terraform destroy -var gcp_project=<gcp project from qwiklabs> -var pubkey_path=$(pwd)/ansible_key.pub
terraform apply -var gcp_project=<gcp project from qwiklabs> -var pubkey_path=$(pwd)/ansible_key.pub
```
When the apply is complete, note the new proxy IP.

### Improvements
So far, whilst this is a longer playbook than those we have used previously, everything we have done should be fairly familiar from previous activities. We will now introduce some new concepts to improve upon the basic playbook we have created, using _variables_, _handlers_, _roles_ and _templates_:
* _Variables_ allow for parameterised execution of playbooks - the same playbook could be executed against the same set of hosts, with different parameters leading to possibly very different results. This ensures greater reusability of playbooks.
* _Handlers_ are, in effect, tasks within a playbook that can be triggered on-demand by a notification from another task.
* _Roles_ are, in effect, what modules are to terraform - directories containing a collection of tasks and other resources which can then be referenced within playbooks, in order to streamline the re-use of complex configurations
* _Templates_ are used to dynamically alter the contents of a file before copying to a remote host, allowing for reuse of config files.  

We will start by using some variables to parameterise the playbook. Edit lines 21 and 22 in the playbook and replace the hard-coded information with variables:
```yaml
...
  - name: 'update website from the git repository'
    git:
      repo: "{{ repository_url }}" # <- edit this line
      dest: "{{ install_dir }}"    # <- and this one
...
```
Now the repository and the install directory are parameterised, we could potentially re-use this playbook to install any repository into any location on the target hosts.  
Next, we will reconfigure the nginx config files to act as templates. Starting with nginx-server.conf, edit the file contents to be as follows:
```conf
events {}
http {
    server {
        listen 8080;
        root {{ install_dir }}; # <- changed this line
        index index.html;
        include /etc/nginx/mime.types; 
        proxy_read_timeout  90;
        proxy_set_header X-Forwarded-Host $host:$server_port;
        proxy_set_header X-Forwarded-Server $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Real-IP $remote_addr;
    
        location / {
            try_files $uri /index.html;
        }
    }
}
```
Ansible templates will be rendered by the _Jinja2_ templating engine prior to transfer to the host, allowing for injection of dynamic parameters. The server config is a fairly simple template, referencing the same install_dir variable as in the playbook. We can also use templates to improve the proxy config. Replace the contents of nginx-proxy.conf with the following:
```conf
events {}

http {
    upstream appservers {
        {% for host in groups['gcp_role_appserver'] %}
        server {{ hostvars[host]['ansible_facts']['default_ipv4']['address'] }}:8080;
        {% endfor %}
    }
    server {
        listen 80;
        location / {
            proxy_pass http://appservers;
        }
    }
}
```
This is a slightly more complex template which uses a for-loop over the hosts in the gcp_role_appserver group to dynamically construct the upstream, using _facts_ about the hosts to retrieve the IP addresses.  
To use these templates effectively, we must also update the playbook again, replacing 'copy' with 'template' on lines 24 and 35. The full playbook should then look like:
```yaml
---
- hosts: all
  become: true
  tasks:
  - name: Install NGINX
    apt:
      pkg: 
      - nginx
      - git
      state: latest
      update_cache: true
  - name: Start NGINX Service
    service:
      name: nginx
      state: started
- hosts: gcp_role_appserver
  become: true
  vars:
    repository_url: "https://gitlab.com/qacdevops/static-website-example"
    install_dir: "/opt/static-website-example" 
  tasks:
  - name: 'update website from the git repository'
    git:
      repo: "{{ repository_url }}"
      dest: "{{ install_dir }}"
  - name: 'install the nginx.conf file on to the remote machine'
    template:
      src: nginx-server.conf
      dest: /etc/nginx/nginx.conf
  - name: Restart NGINX Service
    service:
      name: nginx
      state: restarted
- hosts: gcp_role_proxy
  become: true
  tasks:
  - name: transfer_nginx_conf
    template:
      src: nginx-proxy.conf
      dest: /etc/nginx/nginx.conf
  - name: Restart NGINX Service
    service:
      name: nginx
      state: restarted
```
Execute the playbook:
```bash
cd ~/ansible-labs/lab04
ansible-playbook -i inventory.gcp_compute.yml playbook.yml
```
Once execution is complete you should again be able to access the website by navigating to the proxy IP in a browser. Destroy and recreate the infrastructure again, to give us a clean slate:
```bash
cd ~/ansible-labs/lab03
terraform destroy -var gcp_project=<gcp project from qwiklabs> -var pubkey_path=$(pwd)/ansible_key.pub
terraform apply -var gcp_project=<gcp project from qwiklabs> -var pubkey_path=$(pwd)/ansible_key.pub
```

### Handlers and Roles
We can now make a few more changes to our configuration to reduce a lot of the repetition and improve reusability. We will start by initialising 3 _roles_:
```bash
cd ~/ansible-labs/lab04
ansible-galaxy init common
ansible-galaxy init appserver
ansible-galaxy init proxy
```
A role defines a collection of tasks, templates, variables and other data which can then by used within a playbook without having to duplicate the config. We will configure the three roles to hold most of our configuration. Begin with the `common` role:  
Add the following to _common/tasks/main.yml_
```yaml
- name: Install NGINX
  apt:
    pkg: 
    - nginx
    - git
    state: latest
    update_cache: true
- name: Start NGINX Service
  service:
    name: nginx
    state: started
```
And add the following to _common/handlers/main.yml_
```yaml
- name: restart nginx
  service:
    name: nginx
    state: restarted
```
Next, we will edit the `appserver` role. Add the following to _appserver/tasks/main.yml_
```yaml
- name: 'update website from the git repository'
  git:
    repo: "{{ repository_url }}"
    dest: "{{ install_dir }}"
- name: 'install the nginx.conf file on to the remote machine'
  template:
    src: nginx-server.conf
    dest: /etc/nginx/nginx.conf
  notify: restart nginx
```
When using roles, any templates referenced need to be located within the role directory as well, so copy the nginx-server.conf into the right location:
```bash
cp nginx-server.conf appserver/templates/nginx-server.conf
```
Next, add the following to _proxy/tasks/main.yml_
```yaml
- name: transfer_nginx_conf
  template:
    src: nginx-proxy.conf
    dest: /etc/nginx/nginx.conf
  notify: restart nginx
```
And copy the other conf file to the right location for ansible to find it:
```bash
cp nginx-proxy.conf proxy/templates/nginx-proxy.conf
```
Now with most of our configuration separated out into roles, the playbook can become much simpler. Back up your existing playbook first, for comparison:
```bash
cp playbook.yml playbook-old.yml
```
Then replace the contents of playbook.yml with the following:
```yaml
---
- hosts: gcp_role_appserver
  become: true
  vars:
    repository_url: "https://gitlab.com/qacdevops/static-website-example"
    install_dir: "/opt/static-website-example"
  roles:
  - common
  - appserver
- hosts: gcp_role_proxy
  become: true
  roles:
  - common
  - proxy
```
Executing the playbook and navigating to the proxy IP in a browser should, again, result in the website being accessible:
```bash
ansible-playbook -i inventory.gcp_compute.yml playbook.yml
```