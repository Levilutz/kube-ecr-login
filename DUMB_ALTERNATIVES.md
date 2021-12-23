# Dumb Alternatives

I've seen quite a few suggestions for how to resolve this differently from how I've done it. Some are certainly valid, and some are certainly not. Here's a few of the ones I've seen more than once, and their respective shortcomings. 

* "_Just auth to ECR before every single image pull._" Firstly, I have yet to find a clean way to accomplish this in vanilla kubernetes. Secondly, this is likely to require throwing precious AWS credentials all over the cluster whenever any image needs to pull.

* "_Just give your EKS cluster permission to pull from your ECR repositories._" This only works if you're deployed on EKS. EKS is expensive ($72/cluster/month base + the cost of EC2 instances), so I avoid it for smaller projects.

* "_Just manually give the cluster ECR creds before you start deploying stuff._" What if the cluster has issues the next day and needs to pull new images? The creds you gave it when you initially deployed are long-expired, so your cluster is unable to recover from the failure without manual intervention. 

* "_Just pre-pull all images onto all nodes._" I'm surprised I've actually seen this recommended in several places. Firstly, this uses way more storage than is necessary. Secondly, you now have to continuously scan the ECR repos for new images. Thirdly, it doesn't even circumvent the basic issue of getting constantly-renewed ECR creds where they need to be.
