# Lab ANS05 - Secret Management With Ansible-Vault

## Objective
Securely store and retrieve sensitive data using ansible-vault

## Outcomes
By the end of this lab, you will have:
* Created a vault file to securely store variables
* Retrieved data from a vault during playbook execution

## High-Level Steps
* Deploy a sample app that requires authentication
* Use ansible to make an authenticated request to the app
* Store the credentials in a vault file
* Reconfigure the playbook to retrieve the credentials from the vault file

## Detailed Steps

### Deploy a Sample App
For this lab, we will be deploying a sample API which Ansible will make requests to. Begin by cloning the API:
```bash
cd ~
git clone https://github.com/qa-tech-training/example_python_flask_apiserver.git api
```
Next, install dependencies and start the API:
```bash
cd api
python3 -m venv venv
venv/bin/pip3 install -r requirements.txt
venv/bin/python3 app.py
```
Leave the API running in this terminal and open a new terminal tab. Change directory into lab05 and create a new playbook:
```bash
cd ansible-labs/lab05
touch playbook.yml
```
Open playbook.yml in the editor, and add the following:
```yaml
---
- hosts: localhost
  connection: local
  name: Use Credentials
  tasks:
  - name: Make API Call
    uri:
      url: "http://localhost:5000/auth/tokens"
      method: "POST"
      url_username: "learner"
      url_password: "p@ssword"
      return_content: true
    register: result
  
  - name: print info
    debug:
      msg: "{{ result.content }}"
```
Execute the playbook:
```bash
ansible-playbook playbook.yml
```
You should see in the output a generated token, something like:
```
97506f8a1816434b5291a349f0dd5bd4574962ebf82f66505bccc87baf257ac3
```

### Secure the Credential
Having a hardcoded password in the playbook like this is a problem, especially if we want to share that playbook with others. And simply passing the value as a variable on the command line is not an ideal solution, as this leaves the sensitive credential potentially exposable via command history. Instead, a better approach would be to use _ansible-vault_ to encrypt the data at rest, and retrieve it during playbook execution.  
Create a new vault file:
```bash
ansible-vault create vault.yml
```
Once you have set a password on the vault, you will be presented with an editor. Add the following content:
```yaml
password: "p@ssword"
```
Then save and quit the editor. You now have a new vault file. Attempt to cat the contents:
```bash
cat vault.yml
```
You will see output similar to:
```
$ANSIBLE_VAULT;1.1;AES256
33313334323633626365616266313161636134343635313038396162666533376665666562323164
6361303938643739383338663631623538303933356630360a366666366661653866616537643761
66623737316632366435613435393666306661303536333236643335333062633063323531623533
3462653266643330370a656531326535616439633637666164376630646531366138623335663437
39333034343132326634376363363934323762316633393430383237363832626639
```
Demonstrating that the vault file has been encrypted.

### Update the Playbook
Edit playbook.yml again, so that the contents are as follows:
```yaml
---
- hosts: localhost
  connection: local
  name: Use Credentials
  vars_files: # added this line
  - vault.yml # and this line
  tasks:
  - name: Make API Call
    uri:
      url: "http://localhost:5000/auth/tokens"
      method: "POST"
      url_username: "learner"
      url_password: "{{ password }}" # edited this line to reference the password variable
      return_content: true
    register: result
  
  - name: print info
    debug:
      msg: "{{ result.content }}"
```
Now re-run the playbook, but this time add the `-J` flag, which instructs ansible to prompt for the vault password:
```bash
ansible-playbook playbook.yml -J
```
You should again expect to see a token returned, if the request was successful.

### Stretch Task
By consulting the [documentation](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/uri_module.html) for the uri module, and reviewing the source code of the API, attempt to add another task to the playbook which uses the token received from the initial request to create a new book object through the API. See the solution below if needed.  

### Stretch Task Solution

```yaml
---
- hosts: localhost
  connection: local
  name: Use Credentials
  vars_files: 
  - vault.yml
  tasks:
  - name: Make API Call
    uri:
      url: "http://localhost:5000/auth/tokens"
      method: "POST"
      url_username: "learner"
      url_password: "{{ password }}" 
      return_content: true
    register: result
  - name: Add book
    uri:
      url: "http://localhost:5000/api/books"
      method: "POST"
      headers:
        Authorization: "Bearer {{ result.content }}"
      body_format: json
      body:
        title: "Example"
        author: "John Smith"
        genre: "scifi"
        id: "0000012345"
      return_content: true
    register: result2
  - name: print info
    debug:
      msg: "{{ result2 }}"
```