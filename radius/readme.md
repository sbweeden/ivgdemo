This repo contains configuration setup for using IBM Verify Gateway RADIUS module in a container running RHEL8.

# Supporting configuration material

This readme should be read in conjunction with the [IBM Verify Gateway for RADIUS](https://www.ibm.com/docs/en/security-verify?topic=integrations-security-verify-gateway-radius) product documentation.

# ISV Tenant requirements

You need to configure an API client on your ISV tenant with at least permissions:
 - Authenticate any user
 - Read second-factor authentication enrollment for all users
 - Read users and groups

The API client id and secret are required later (see setup of the `.env` file).

To exercise the out-of-the-box configuration of the RADIUS server included in this environment, you need an IBM Verify cloud directory user configured with a password and TOTP. Of course you can reconfigure the radius server to perform other combinations of MFA, per the product documentation. The "password-then-totp" auth-method for [clients](https://www.ibm.com/docs/en/security-verify?topic=server-clients) (See Table 1) was chosen out of the box just to have something to start with.


# BEFORE building the docker image

You have to go to the IBM App Exchange and download the IBM Verify Gateway for Linux PAM module. See: [https://apps.xforce.ibmcloud.com/?br=IdentityandAccess](https://apps.xforce.ibmcloud.com/?br=IdentityandAccess)

Put the zip file in the resources subdirectory. For example I have:
 - `resources/ISVG_RADIUS_V1.0.12.1_250115.zip`

If you don't do this, the build step below will fail.

There is a .gitignore file which ignores all zip files in the resources subdirectory so it will not get checked in to git.

Inspect the `resources/setup_ivg_radius.sh` script - this performs all the fine-detailed config for the **IBM Verify Gateway for RADIUS** setup. 

There are plenty of options when configuring the RADIUS server - read [this doc](https://www.ibm.com/docs/en/security-verify?topic=radius-configuring-security-verify-gateway-server) for a list of all the options. Make changes to the `resources/setup_ivg_radius.sh` script if you want to alter any of the deployment characteristics, although it is highly recommended you start with the provided configuration and make that work first against your own tenant and user.


# Building the Docker image

Look at the `build.sh` script to see how to build the container, and the `Dockerfile` to see everything that is established. Note that the `resources/setup_ivg_radius.sh` script is set up as a one-shot service (called `very-last`) to be run when the container starts, which completes the installation and configuration of the RADIUS server. This is done as a runtime operation so that secrets, etc, can be read from environment variables rather than burned into an image instance.

# Deploying the image

After building it, you could run it directly with docker (see `rundocker.sh`), or (as I prefer) run it on a Kubernetes cluster as a POD/svc. A secret is used to hold all environment variables.

Ensure you have a kubernetes config set up, and kubectl is in your path and ready to run against your cluster.

Create a `.env` file in the same directory as the `deploy.sh` script with real values for the following (samples shown):

```
TENANT=YOURTENANT.verify.ibm.com
API_CLIENT_ID=YOUR_CLIENT_ID
API_CLIENT_SECRET=YOUR_CLIENT_SECRET
PORT=443
RADIUS_CLIENT_SECRET="passw0rd"
```

The `PORT` field is optional and is only really useful if testing against an ISVA instance configured for IBM Verify Gateway when the ISVA Web Reverse Proxy runs on a non-standard port.

You can use any value you like for the `RADIUS_CLIENT_SECRET` - this is a standard RADIUS concept. Obviously we have chosen something weak by default for this demo environment and you should change it to something different.

Edit the `radiusdemo.yaml` file, and update the image location to your own docker registry - somewhere you've made your built image available. 

Deploy the secret, pod, and NodePort service to kubernetes with:

```
./deploy.sh
```

Make sure the pod starts cleanly:

```
$ kubectl get pod        
NAME                                       READY   STATUS    RESTARTS       AGE
radiusdemo                                 1/1     Running   0              5m49s
```

There is a `cleanup.sh` script to remove all artifacts as well.

# Testing with pap_challenge_request.pl

After the container is running, exec a shell on the container. 

When running the image locally with docker, I use:
```
docker exec -it radiusdemo bash
```

In kubernetes I do this with:

```
kubectl exec -it radiusdemo -- bash
```

Next, change directory to the resources subdirectory, and run the RADIUS client script `pap_challenge_request.pl` as shown:
```
[root@fdb4947e8f58 resources]# ./pap_challenge_request.pl 
Enter username: jsmith
Enter password: 
<more trace here, but you should get the idea at this point>
```

Should the password authentication succeed, you should next be prompted for the TOTP of the user:
```
Received response with VALID RFC3579 Message-Authenticator.
server response type = Access-Challenge (11)
State -> {"method":"totp","user_id":"642003UTB2","totp_id":"ddb599e7-1c36-4060-9fdc-cbf554d32d3d"}
Reply-Message -> Enter OTP : 
Prompt -> 2
Proxy-State -> jsmith
Message-Authenticator -> 
Enter OTP :  865501
```

More trace follows at this point, but if successful you see:
```
Enter OTP :  865501
... trace redacted ...
Received response with VALID RFC3579 Message-Authenticator.
server response type = Access-Accept (2)
Reply-Message -> SUCCESS
Proxy-State -> jsmith
Message-Authenticator -> 
```

This demonstrates a successful challenge-response flow for the user with password, then TOTP.


# Debugging tips

Most of the trace of the RADIUS client will appear in the console as you run the `pap_challenge_request.pl` script. 

Specific trace of communications with your IBM Verify tenant can be seen in the `/tmp/ibm-auth-api.log` trace file:

```
cat /tmp/ibm-auth-api.log
```

If you ran the kubernetes setup, you should check that initialisation happened successfully:

```
kubectl exec -t radiusdemo -- systemctl status very-last
```
If for this last one you see `TENANT not defined` in the output, chances are you didn't create your `.env` file before running `deploy.sh`.

These generally are enough to find common problems.

## Running the test client against a remote RADIUS server

The standalone demo has been configured by default so that the test client `pap_challenge_request.pl` is run on the same localhost as the RADIUS server. 

If you're trying to use the `pap_challenge_request.pl` script from a client to connect to a remote deployment of the radius server, the main parameter to change is the line:
```
use constant RADIUS_HOST => '127.0.0.1';
```
Set this variable to contain the IP and optionally port of the target radius server, for example:
```
use constant RADIUS_HOST => '10.10.10.10:1812';
```

The `ncat` tool has also been installed on the image, such that you can test sending a UDP packet to a remote server and port, just to see if connectivity is possible. Here's an example:
```
echo "test" |  ncat  -u 10.10.10.10 1812
```
When sending a message like this to a remote radius server not yet configured for a remote client, the trace file `/tmp/ibm-auth-api.log` on the radius server should show an error when the packet arrives, similar to:
```
IA: 0x6849e695: 0x76249e000700: Discard: Unable to find client for packet from ::ffff:10.176.226.76
```
You can use this to determine the IP address of the client (in the example above it is 10.176.226.76), and add a clients entry to `/etc/IbmRadiusConfig.json` on the RADIUS server. For example after seeing the above error I added:
```
        ,{
            "name":"client2",
            "address":"10.0.0.0",
            "mask":"255.0.0.0",
            "obf-secret":"/rlKSHUt1rqcU08fSytjOoFu8j7Xeg9FGvNbbNXFH7Q=",
            "auth-method":"password-then-totp",
            "require-msg-auth": true
        }
```
Don't forget to restart the RADIUS server after editing the configuration file (see the end of `/root/resources/setup_ivg_radius.sh`):
```
systemctl restart ibm_radius_64
```

Next time I ran the ncat test from my remote client, I see this error in `/tmp/ibm-auth-api.log` at the RADIUS server:
```
IA: 0x6849e74a: 0x751cb2800700: Client for packet = 'client2' from ::ffff:10.176.226.76
IA: 0x6849e74a: 0x751cb2800700: Discard: Unable to parse packet from ::ffff:10.176.226.76
```

This at least tells you client matching is done, and now you can remotely try use the `pap_challenge_request.pl` script from the same machine as where `ncat` was running (after updating the value of `RADIUS_HOST`).
