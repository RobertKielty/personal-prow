# personal-prow
Tools to help you deploy a personal prow instance on your own devlopment machine

# Pre reqs
go 
docker
kind
ngrok

your own Github Org
a fork of kubernetes in that org
a githuib robot account

## Boot up a personal prow instance
./personal_prow.sh 

## Automagical Ingress for your personal-prow-cluster
sudo -E kwt net start   

## Setup webhook repo to talk to your Personal Prow instance

Create a ngrok based tunnel and add that as a webhook to your repo to make your local prow instance reachable from github

./add_ngrok_hook.sh

