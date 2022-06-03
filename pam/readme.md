This repo contains configuration setup for using IBM Verify Gateway PAM module in a container running sshd.

# ISV Tenant requirements

You need to configure an API client on your ISV tenant with at least permissions:
 - Authenticate any user
 - Read second-factor authentication enrollment for all users
 - Read users and groups

The API client id and secret are required later (see setup of the `.env` file).

You need an ISV user with MFA configured. The user's username is required later (see `MAPPED_USER` in the `.env` file). 

In this example the test user is assigned a separate Linux password, and can be mapped to any ISV user with a completely different username.

# BEFORE building the docker image

You have to go to the IBM App Exchange and download the IBM Verify Gateway for Linux PAM module. See: [https://exchange.xforce.ibmcloud.com/hub/IdentityandAccess](https://exchange.xforce.ibmcloud.com/hub/IdentityandAccess)

Put the zip file in the resources subdirectory. For example I have:
 - `resources/ISVGForLinuxPAM105.zip`

If you don't do this, the build step below will fail.

There is a .gitignore file which ignores all zip files in the resources subdirectory so it will not get checked in to git.

Inspect the `resources/setup_ivg_pam.sh` script - this performs all the fine-detailed config for the **IBM Verify Gateway for Linux PAM** setup. 

There are plenty of options when configuring the Linux PAM integration for mapping users, appending a suffix, etc - read [this doc](https://www.ibm.com/docs/en/security-verify?topic=configuration-pam-system-file) for a list of all the options. Make changes to the `resources/setup_ivg_pam.sh` script if you want to alter any of the deployment characteristics.


# Building the Docker image

Look at the `build.sh` script to see how to build the container, and the `Dockerfile` to see everything that is established. Note that the `resources/setup_ivg_pam.sh` script is set up as a one-shot service (called `very-last`) to be run when the container starts, which completes the configuration of the sshd and PAM settings. This is done as a runtime operation so that usernames and passwords, etc, can be read from environment variables rather than burned into an image instance.

# Deploying the image

After building it, you could run it directly with docker, or (as I prefer) run it on a Kubernetes cluster as a POD/svc. A secret is used to hold all environment variables.

Ensure you have a kubernetes config set up, and kubectl is in your path and ready to run against your cluster.

Create a `.env` file in the same directory as the `deploy.sh` script with real values for the following (samples shown):

```
TENANT=YOURTENANT.verify.ibm.com
API_CLIENT_ID=YOUR_CLIENT_ID
API_CLIENT_SECRET=YOUR_CLIENT_SECRET
USERNAME="testuser"
USERPWD="Passw0rd"
MAPPED_USER="testuser"
```

 Deploy the secret, pod, and NodePort service to kubernetes with:

```
./deploy.sh
```

Make sure the pod starts cleanly:

```
$ kubectl get pod        
NAME                                       READY   STATUS    RESTARTS       AGE
pamdemo                                    1/1     Running   0              5m49s
```

There is a `cleanup.sh` script to remove all artifacts as well.

# Testing ssh with MFA to the container

After the script is run, from an external shell try:

```
ssh -l <value_of_USERNAME> -p 30222 localhost
```

In this example I am using the kubernetes deployment and port 30222 is the NodePort service exposed (see `pamdemo.yaml`). I can use localhost because I am on the worker node where the pod is deployed. This would be a different IP/hostname if your kubectl client is remote from the cluster.

You should be prompted for a password, which will be the password you set in the variables in your `.env` file.
After that you should be prompted for MFA (for the MAPPED_USER in the tenant) and be required to complete it before successful login.

# Debugging tips

On a shell inside the container, you can see sshd logs with:
```
journalctl _COMM=sshd
```

You can also inspect the primary IVG trace file:

```
tail -F /tmp/pam_ibm_auth.log
```

If you ran the kubernetes setup, you should check that initialisation happened successfully:

```
kubectl exec -t pamdemo -- systemctl status very-last
```
If for this last one you see `TENANT not defined` in the output, chances are you didn't create your `.env` file before running `deploy.sh`.

These generally are enough to find common problems.