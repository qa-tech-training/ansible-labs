# Lab ANS00 - Setting up the Lab Environment

## Objective
Launch the lab environment and connect

## Steps
### Start the Lab
Log into your [qwiklabs](https://qa.qwiklabs.com) account, and click on the classroom tile. Click into the lab, and click the 'Start Lab' button. Once the lab has started, right click the 'console' button and click 'open in incognito/inprivate window'.

### Setup the Environment
Once logged into the cloud console, click the cloud shell icon in the top right. Wait for cloud shell to start, then open the cloud IDE editor as well. Pop the IDE out into a separate window so that you can navigate back and forth between the IDE and the console.

In a new terminal session in the IDE window, clone the lab files:
```bash
git clone --recurse-submodules https://github.com/qa-tech-training/ansible-labs.git
```
Open the explorer pane in the editor and ensure you can see the newly cloned files.

### Edit GCE Metadata
These labs will require SSH access to VMs using self-managed SSH keys. By default, the compute engine in the qwiklabs projects has _os-login_ enabled, which allows GCP to manage SSH access to VMs via IAM credentials. This will, however, block SSH using self-managed SSH keys, so we will need to disable it.  
From the cloud console, navigate to the _compute engine_ overview. Towards the bottom of the left-hand-side menu, click _compute engine metadata_. Edit the metadata and change the setting for os-login from true to false, leaving other settings as they are.