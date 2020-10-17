## Demo App - ArgoCD Umbrella App

This repository contains the ArgoCD "App of Apps" GitOps pattern to automatically provision a cluster with the following resources:

* [Cert Manager](https://cert-manager.io/docs/): Allows a dynamic and automated way to provision and refresh SSL certificates using LetsEncrypt.
* [Rancher](https://rancher.com/docs/rancher/v2.x/en/): A cluster/Kubernetes resource and management tool. It gives you a visual UI into your cluster and workloads and allows access without a terminal.
* [Banzai Bank-Vault](https://github.com/banzaicloud/bank-vaults): Gives you a way to both store secrets encrypted and reference those encrypted secrets within Pods at run-time so applications have access to them.

### Prerequisites and Links

This repository assumes you already have the following installed:

* Kubernetes
* ArgoCD
* Kubectl CLI
* Vault CLI

Please reference the [aws-k8s-terraform](https://github.com/atoy3731/aws-k8s-terraform) project to spin up an entire functioning K3S cluster onto AWS with ArgoCD using Terraform.

### What is All This Stuff?

ArgoCD best-practices say to follow an "app-of-app" pattern to deploy your applications. If you look at the `umbrella-tools.yaml` file, this is your "parent" application that will host all other applications inside of it.

Within that file, you'll see this snippet:

```yaml
  source:
    path: resources/tools/
    repoURL: https://github.com/atoy3731/k8s-tools-app.git
    targetRevision: master
```

What this is telling ArgoCD is:

1. Use the `https://github.com/atoy3731/k8s-tools-app.git` git repository.
2. Check out the `master` branch.
3. Go to the `resources/tools` directory.

ArgoCD supports flat manifests, Kustomize, and Helm for manifest compilation. We utilize both Kustomize and Helm within this project.

If you look at the `resources/tools/resources` directory, you'll see a number of other Application custom resources that follow a similar pattern to the "parent" project. These follow the same workflows.

### Sync Waves

Another *awesome* feature of ArgoCD is Sync Waves. This allows you to synchronously deploy things in a specific order just by attaching an annotation. For instance, you need to deploy **Cert Manager** before you deploy **Rancher**, so you can set this annotation within your `cert-manager` Argo Application:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cert-manager
  namespace: kube-system
  annotations:
    argocd.argoproj.io/sync-wave: "-4"
```

And this annotation for Rancher:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: rancher
  namespace: kube-system
  annotations:
    argocd.argoproj.io/sync-wave: "-3"
```

Since cert-manager's sync wave (`-4`) is lesser than rancher's (`-3`), it will deploy first.

**NOTE:** Sync waves range from -5 to 5 and follow that order.

### So How Do I Deploy This?

This repo is set up for a demo, so you'll need to do the following to make it work for you:

1. If you've forked/cloned this repository, you'll need to do a global find/replace for `https://github.com/atoy3731/k8s-tools-app.git` and change it to your new repository.

2. If this is exposed to the world via a domain you own, you'll need to make a wildcard CNAME DNS entry to point to the AWS ELB hostname that was created from your `aws-k8s-terraform` cluster.

   For instance, I have `*.demo.atoy.dev` pointing to `a1ec6aaa9d97d4774975811481c12472-959947491.us-east-1.elb.amazonaws.com`. This will route all traffic to Kubernetes and let the Traefik ingress controller route based on the incoming hostname.
   
3. In `resources/tools/resources/other-resources.yaml`, change the `argoHost` and `issuerEmail` to your domain name and email.

4. In `resources/apps/resources/hello-world.yaml`, change the 2 references to `app.demo.atoy.dev` to your domain. 
    
Now you're ready to deploy! Run the following command:

```bash
kubectl apply -f umbrella-tools.yaml
```

And Ta-Da, your entire cluster should be provisioning.  It will take a minute or two for the ArgoCD ingress to provision, but assuming things are set up, you should be able to navigate to it. For me, I go to http://argo.demo.atoy.dev

**NOTE:** If you don't have a domain that you own and still want to see ArgoCD, you can run the following:

```$xslt
kubectl port-forward svc/argocd-server 8080:80 -n kube-system
```

Now you should be able to go to http://localhost:8080 in your browser and get to Argo.

**OTHER NOTE:** ArgoCD's username is `admin` and password is the name of the argocd-server pod running within kube-system. To get this, run the following:

```$xslt
kubectl get pods -n kube-system | grep argocd-server | awk '{ print $1 }'
```

### Creating Vault Secrets

For secrets within Vault, I prefer using the UI. To access to the UI, run the `tools/vault-config.sh` command once your vault is up and running. It'll output something similar:

```
Your Vault root token is: s.nSSIIdCRZE6wA4wAaRVWaq03

Run the following:
export VAULT_TOKEN=s.nSSIIdCRZE6wA4wAaRVWaq03
export VAULT_CACERT=/Users/adam.toy/.vault-ca.crt
kubectl port-forward -n vault service/vault 8200 &

You will then be able to access Vault in your browser at: http://localhost:8200

```

1. Navigate to [http://localhost:8200](http://localhost:8200) and enter your token.
2. Once you're logged in, click on the `secret/` engine and click `Create Secret` in the upper-right.
3. On the form, in the `Path for this secret` box, put `demo`.
4. Add a key/value under Version Data that matches: `DEMO_SECRET` = `vault-secured-secret-1234!`.
5. Click `Save`

Congrats, you've created an encrypted secret that is stored in Vault!

### Deploy the Demo App

Now we're going to deploy the Demo App. Run the following:

```
kubectl apply -f umbrella-apps.yaml
```

That should kick off another umbrella app that will contain a single sub-application. It is a Python application that will output the above Vault secret to its logs and show you the hostname/IP of the pod in the browser.

If you want to see the source of the application, it is [here](https://github.com/atoy3731/hello-world-app)

Its Kubernetes manifests are [here](https://github.com/atoy3731/hello-world-manifests)

### Anything Else?

These are on my road-map for other things to add to this:

* Istio Service Mesh
* ELK Stack

I'm open to suggestions!