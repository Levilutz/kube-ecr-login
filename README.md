# kube-ecrlogin

A minimal kubernetes CronJob that re-auths to AWS ECR and stores the credentials in a cluster Secret.

## Purpose

Let's say I want to deploy a containerized application of mine to a kubernetes cluster. For privacy, I keep the images in some private AWS ECR repositories.

Now my cluster needs to be able to pull from those repositories 24/7. Unfortunately, however, a login for ECR is only valid for 12 hours. How do I ensure my cluster can always pull images from the ECR repos? A few 'easy' solutions to this might come to mind at first, but [many of them have shortcomings](DUMB_ALTERNATIVES.md).

So what solution is implemented here? Run a cluster CronJob that pulls new ECR credentials every <12 hours and stores them in a cluster Secret. I chose every 4 hours to be safe, but this can easily be changed in `kube-ecrlogin.yaml`.

## Usage

### Requirements
* A running kubernetes cluster.
* At least one ECR repository to pull images from.
* AWS credentials with ECR Pull access.

### Steps
1. (Optional) Copy the `kube-ecrlogin.yaml` file wherever you want it.
2. Add cluster Secrets for AWS stuff:
  * `AWS_ACCESS_KEY_ID`: [As documented](https://docs.aws.amazon.com/sdkref/latest/guide/setting-global-aws_access_key_id.html)
  * `AWS_SECRET_ACCESS_KEY`: [As documented](https://docs.aws.amazon.com/sdkref/latest/guide/setting-global-aws_secret_access_key.html)
  * `AWS_DEFAULT_REGION`: [As documented](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html#cli-configure-quickstart-region)
  * `AWS_ECR_SERVER`: Eg. `12345678901234.dkr.ecr.us-east-1.amazonaws.com`
3. Just run `kubectl apply -f kube-ecrlogin.yaml`.

## Building yourself
Want to build this yourself? It's easy.

### Requirements
* A linux machine / VM (this won't build inside a container as-is).
* Installed `curl`, `unzip`, `buildah`.
  * These all come pre-installed on github actions ubuntu runners.

### Steps
1. Clone this repo into your linux machine.
2. Just run `./build_main.sh` and `./build_sidecar.sh`.
3. Feel free to `buildah tag` and `buildah push` the images wherever you want them.

For a reference on exactly what to do, this repo's github build action does everything automatically on every push.

## Methods
The CronJob spins up a pod with two containers:
* The main container, which runs `main_entrypoint.sh`.
* The sidecar container, which proxies the cluster's kubernetes API.

The sidecar enables our script to modify the cluster it lives in. `kubectl` can 'magically' configure itself for the cluster in this case, and `proxy` proxies the external cluster to port 8080 on the pod. Containers in a pod share a host IP and ports, so the other container can freely connect to `localhost:8080` (the default) and execute its actions.

The main container goes through four small steps:
1. Validates `kubectl` can connect to the cluster.
2. Get the ECR password from AWS.
3. Try to delete the old secret (if it exists).
4. Create a new secret with the ECR password from (2).

If any step except (3) fails, the CronJob fails.

## Limitations
1. This only authenticates to AWS ECR servers.
2. This currently only authenticates to a _single_ ECR server. Multiple of this CronJob would not enable multiple servers; the jobs would just overwrite each others' secrets.

## Future Work
* Modify the kube object configuration to ensure that the job runs at least once per cycle ([see kube docs here](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/#cron-job-limitations)).
* Package with Helm.
