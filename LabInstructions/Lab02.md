# Lab ANS02 - Ansible Playbooks

## Objective
Configure a local webserver using an Ansible _playbook_ 

## Outcomes
By the end of this lab, you will have:
* Executed a playbook using Ansible
* Modified a playbook

## High-Level Steps
* Run a basic Ansible playbook
* Add tasks to a playbook to edit server configuration

## Detailed Steps

### Setup
In the cloud IDE, focus the lab02 directory in the explorer pane, and change directory into lab02 in the terminal:
```bash
cd lab02
```

### Review Existing Configuration
Whilst ad-hoc commands such as those used in the previous lab are fine for a quick demonstration, _declarative_ configurations are a much better way to store and share configuration information. Ansible uses _playbooks_ to define declarative configurations. A base playbook called _playbook.yml_ has been provided for this lab:
```yaml
---
- hosts: localhost
  name: Basic Play
  connection: local
  become: true
  tasks:
  - name: Install nginx
    apt:
      name: nginx
      state: present
      update_cache: true
```
This defines a single _play_, called 'Basic Play', which in turn consists of a single _task_ named 'Install nginx'. Note how this configuration maps to the elements of the ad-hoc command from the previous lab - this playbook does the exact same thing, but in a declarative fashion.  
Execute the playbook:
```bash
ansible-playbook playbook.yml
```
Wait for the play to finish, then verify that NGINX was installed:
```bash
curl http://localhost
```
You should expect to see the same response as earlier. As before, re-run the playbook and confirm that nothing changes:
```bash
ansible-playbook playbook.yml
```
The output should show 0 changed.

### Update the Webserver Configuration
We will now edit the playbook to reconfigure NGINX to return a different response. Review the provided _nginx.conf_ file:
```conf
events {}
http {
    server {
        listen 80;
        location / {
          return 200 "Hello from nginx\n";
        }
    } 
}
```
To get nginx to use this new configuration, we need to:
* place this configuration file in the location from which NGINX reads its' configuration
* restart the nginx server

Ansible can do both of these things. Edit playbook.yml so that it contains the following:
```yaml
---
- hosts: localhost
  name: Basic Play
  connection: local
  become: true
  tasks:
  - name: Install nginx
    apt:
      name: nginx
      state: present
      update_cache: true
  
  - name: Copy nginx.conf
    copy:
      src: nginx.conf
      dest: /etc/nginx/nginx.conf
    register: nginx_config

  - name: Restart nginx if needed
    service:
      name: nginx
      state: restarted
```
We have added 2 additional tasks, one to copy our `nginx.conf` file to the relevant place and another to restart NGINX to take in the new changes.

Now execute the playbook:
```bash
ansible-playbook playbook.yml
```
Verify that NGINX is using the new configuration:
```bash
curl localhost
```
You should see:
```
Hello from nginx
```
There is one more improvement we can make to this configuration. Re-run the playbook again:
```bash
ansible-playbook playbook.yml
```
Note that, even though the configuration is the same, the output still shows 1 change: the restarting of NGINX is not idempotent, and will happen every time we execute this playbook. To stop this, and restore the idempotence of our playbook, we can make the 'restart nginx' task conditional on the result of the 'copy nginx.conf' task. Edit playbook.yml again, and ensure that it has the following contents:
```yaml
---
- hosts: localhost
  name: Basic Play
  connection: local
  become: true
  tasks:
  - name: Install nginx
    apt:
      name: nginx
      state: present
      update_cache: true
  
  - name: Copy nginx.conf
    copy:
      src: nginx.conf
      dest: /etc/nginx/nginx.conf
    register: nginx_config

  - name: Restart nginx if needed
    service:
      name: nginx
      state: restarted
    when: nginx_config.changed == true # uses the result registered as nginx_config, from the task above
```
Now NGINX will _only_ be restarted if a change to nginx.conf necessitated the copy to be re-executed. To observe this, re-run the playbook again:
```bash
ansible-playbook playbook.yml
```
Now the section for the restart nginx task in the output should say something like:
```
TASK [Restart nginx if needed] **************************************************************************************************
skipping: [localhost]
```
as the nginx.conf file is unchanged, so there is no need to restart NGINX.