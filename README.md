# kube-ecr-login

![GitHub Workflow Status](https://img.shields.io/github/workflow/status/levilutz/kube-ecr-login/Build)
![Docker Pulls](https://img.shields.io/docker/pulls/levilutz/kube-ecr-login)


A minimal kubernetes CronJob that re-auths to AWS ECR and stores the credentials in a cluster Secret.

## Purpose

Let's say I want to deploy a containerized application of mine to a kubernetes cluster. For privacy, I keep the images in some private AWS ECR repositories.

Now my cluster needs to be able to pull from those repositories 24/7. Unfortunately, however, a login for ECR is only valid for 12 hours. How do I ensure my cluster can always pull images from the ECR repos? A few 'easy' solutions to this might come to mind at first, but [many of them have shortcomings](DUMB_ALTERNATIVES.md).

So what solution is implemented here? Run a cluster CronJob that pulls new ECR credentials every <12 hours and stores them in a cluster Secret. I chose every 4 hours to be safe, but this can easily be changed in `kube-ecr-login.yaml`.

## Usage

### Requirements
* A running kubernetes cluster.
* At least one ECR repository to pull images from.
* AWS credentials with ECR Pull access.

### Steps
1. Determine which manifest file is relevant to you. If your cluster has RBAC, you'll be using `deploy/kube-ecr-login-rbac.yaml`. If not, you'll be using `deploy/kube-ecr-login.yaml`.
    * You can check if RBAC is enabled with `kubectl api-versions | grep rbac`. If you get any results along the lines of `rbac.authorization.k8s.io/v1`, your cluster probably has it enabled.
2. Modify the manifest file by substituting values for the container's env vars appropriately. This step can be integrated into CI/CD by using `sed` to find-and-replace the placeholder text for each var.
    * `AWS_ACCESS_KEY_ID`: [As documented](https://docs.aws.amazon.com/sdkref/latest/guide/setting-global-aws_access_key_id.html)
    * `AWS_SECRET_ACCESS_KEY`: [As documented](https://docs.aws.amazon.com/sdkref/latest/guide/setting-global-aws_secret_access_key.html)
    * `AWS_DEFAULT_REGION`: [As documented](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html#cli-configure-quickstart-region)
    * `AWS_ECR_SERVER`: Eg. `12345678901234.dkr.ecr.us-east-1.amazonaws.com`
3. Prepare your local environment for `kubectl` on your cluster, through `KUBECONFIG` or however else you choose.
4. Run `kubectl apply --overwrite -f deploy/<file-from-earlier>`, with whichever file you selected in step 1. 
5. Add `imagePullSecrets` to the PodSpecs with ECR-stored images, [as described here](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/#create-a-pod-that-uses-your-secret). 

### Removing from Cluster
Don't want or need this anymore? Just run the provided script: `bash scripts/uninstall.sh`

## Building yourself
Want to build the images yourself? It's easy.

### Requirements
* A linux machine / VM (the build scripts won't run on a container as-is).
* Installed `curl`, `unzip`, `buildah`.
  * These all come pre-installed on github actions `ubuntu-latest` runners.

### Steps
1. Clone this repo into your linux machine.
2. Just run `./main/build.sh` and `./sidecar/build.sh`.
3. Feel free to `buildah tag` and `buildah push` the images wherever you want them.

For a reference on exactly what to do, this repo's github [build action](.github/workflows/build.yml) does everything automatically on every push.

## Methods
The CronJob spins up a pod with two containers:
* The main container, which runs `main/entrypoint.sh`.
* The sidecar container, which proxies the cluster's kubernetes API.

The sidecar enables our script to modify the cluster it lives in. `kubectl` can 'magically' configure itself for the cluster in this case, and `proxy` proxies the external cluster to port 8080 on the pod. Containers in a pod share a host IP and ports, so the main container can freely connect to `localhost:8080` (the default) and execute its actions.

The main container goes through four small steps:
1. Validates `kubectl` can connect to the cluster.
2. Get the ECR password from AWS.
3. Try to delete the old secret (if it exists).
4. Create a new secret with the ECR password from (2).

If any step except (3) fails, the CronJob fails.

The sidecar uses a little hackery to start and stop properly. This is necessary, as more native support for sidecar containers has unfortunately been pending for many years, as of December 2021 (see [this](https://github.com/kubernetes/enhancements/issues/753), [this](https://github.com/kubernetes/kubernetes/pull/75099), and [this](https://github.com/kubernetes/kubernetes/issues/25908)). 

The first requirement is for the main container to not start until the sidecar has started it's `kubectl proxy`. To ensure this, we take advantage of how kubernetes starts up containers in a pod. When provided a list of containers in a PodSpec, it starts them in sequence. However, it doesn't wait for a container to be fully alive before moving on to the next.

To hack the desired behavior in, we add a `wait_until_ready.sh` script to the sidecar's postStart lifecycle hooks. Kubernetes will be stuck in that lifecycle hook until the wait script exits. Technically, this script just repeatedly checks to see if anything is stening on localhost port 8080. If it sees something listening, it exits happily and kubernetes moves on to starting the main container. If nothing is found after 60 seconds, it fails.

The second requirement is for the sidecar container to exit once the main container finishes its tasks. Without any hacking, the main container will finish but the sidecar container will stay alive indefinitely. Since one of its containers is forever alive, the Pod will never think itself completed, thus the Job will never think itself done.

To resolve this, the sidecar starts its proxy in the background, then starts a netcat listener on port 54345. The netcat distribution on alpine linux allows a `-e` argument, which executes a program when a connection is received. An empty script is supplied, and the resulting behavior is that the netcat listener on the sidecar closes as soon as a connection is made to it. After the close, the sidecar finds its own `kubectl proxy` process and kills it, then happily exits. To trigger this behavior, the main container makes a netcat connection with a timeout of 1s, then happily exits itself.

## Limitations
1. This only authenticates to AWS ECR servers, not any other type of private docker server.
    * Most of the work here _should_ be re-usable for other providers though.
2. This currently only authenticates to a _single_ ECR server. Multiple of this CronJob would not enable multiple servers; the jobs would just overwrite each others' secrets.

## Future Work
* Modify the kube object configuration to ensure that the job runs at least once per cycle ([see kube docs here](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/#cron-job-limitations)).
* Package with Helm.
