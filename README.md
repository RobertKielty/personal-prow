# Personal Prow

Scripts to help you deploy a personal prow instance on your own devlopment machine that can react to bot commands on a Pull Request on a Github repo that you setup, just like on the kubernetes/kubernetes project.

This is still a work in progress but will form the basis for a workshop to be presented
at the Kubernetes Contributor Summit North America 2019 [Setting Up and Running Prow on Your Development Machine](https://kcsna2019.sched.com/speaker/robkielty)

Attendees are welcome to log (and fix) issues as I iron out the crinkles in the coming days!

## Bootstrapping kind with a prow deployment

./personal_prow.sh starts a kind cluster and uses [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) and  [kapp](https://get-kapp.io/) to deploy a cluster using the starter.yaml taken from test-infra

Then you can use the add_ngrok_hook.sh to create a public ngrok tunnel that allows you
to configure your github repo with a hook back to your personal prow instance

The personal personal_prow.sh is a scripted "manual" deployemnt as described here  
[getting_started_deploy.md](https://github.com/kubernetes/test-infra/blob/master/prow/getting_started_deploy.md)

## Setting up Github

You should create :

- your own Github Org
- a fork of kubernetes in that org
- a github robot account

## Boot up a personal prow instance

 ```./personal_prow.sh```

## Expose the service

[kwt Network commands](https://github.com/k14s/kwt/blob/master/docs/network.md)

 ```sudo -E kwt net start```

## Github repo Webhook configuration

add_ngrok_hook.sh creates a ngrok-based tunnel and adds that as a webhook on your repo to make your local prow instance reachable from github

 ```./add_ngrok_hook.sh```

## Go to the deck in your browserA

http://deck.default.svc.cluster.local/

