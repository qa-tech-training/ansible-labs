# Lab ANS01 - Ansible Introduction

## Objective
Use ansible to deploy a webserver resource locally

## Outcomes
By the end of this lab, you will have:
* Installed Ansible
* Used ad-hoc commands to configure a local webserver

## High-Level Steps
* Use apt to install ansible
* Execute an ad-hoc command to install NGINX
* Demonstrate idempotence
* Execute another command to uninstall NGINX

## Detailed Steps

### Installation
Ansible is not preinstalled in the lab environment, so our first step will be to install it. Since the cloudshell VM is debian-based, we will use apt:
```bash
sudo apt update 
sudo apt install software-properties-common
sudo apt-add-repository --yes --update ppa:ansible/ansible
sudo apt install ansible
```
Confirm the installation:
```bash
ansible --version
```

### Use Ansible to Install a Web Server
In subsequent labs we will explore many of the powerful features that Ansible offers. For now though, we will keep things simple and run an _ad-hoc_ command to configure a web server:
```bash
ansible 127.0.0.1 -m apt -a "name=nginx state=present update_cache=true" --become
```
This command instructs ansible to:
* target the local machine via the 127.0.0.1 loopback address
* execute the built-in _apt_ module
* pass the arguments defined by the string following the -a flag to the module
* use privilege escalation via sudo to gain the permissions necessary to manage system packages

You should see that Ansible returns a JSON object, showing you that it has completed the task. 

### Check NGINX has been Installed Correctly
The `curl` command can be used to check that our web server is running correctly:
```bash
curl http://localhost
```
You should get a response back similar to this:
```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

### Demonstrate Idempotence
One of the benefits of using a declarative configuration tool like Ansible is _idempotence_ - if the target resources are already in their desired state, then reapplying the configuration should do nothing. We can observe this by re-running the same ansible command again:
```bash
ansible 127.0.0.1 -m apt -a "name=nginx state=present update_cache=true" --become
```
You should see that the execution is a lot quicker and that you get a different output, like this:
```
localhost | SUCCESS => {
    "cache_update_time": 1612268706, 
    "cache_updated": true, 
    "changed": false
}
```
You should see that the changed value is false; this means Ansible noticed that NGINX was already installed and didn't make any changes. You can run this command as many times as you like and you will get a success message.

### Uninstall NGINX
We will want to be able to install NGINX again in a subsequent lab, so for now we will uninstall it. Run the following ansible command:
```bash
ansible 127.0.0.1 -m apt -a "name=nginx state=absent update_cache=true" --become
```
Note the difference from the previous command: in the module arguments, state is set to absent, as opposed to present, meaning ensure that NGINX is not installed. Verify that NGINX is no longer running:
```bash
curl http://localhost # should fail to connect
```