#!/bin/bash - 
#===============================================================================
#
#          FILE: personal_prow.sh
# 
#         USAGE: ./personal_prow.sh 
# 
#   DESCRIPTION: Deploy prow from head commit on test-infra on kind using kaap 
#                from k14s 
#                Destroys pre-existing prow on kind
#                Cluster name is personal-prow
# 
#       OPTIONS: user 
#  REQUIREMENTS: ./tools/ngrok, kind, kapp, kwt, docker, go
#          BUGS: 
#                      
#         NOTES: Run in personal-prow directory as it depends on and 
#                references github secret files that need to be stored here 
#        AUTHOR: Robert Kielty (robk), rob.kielty@gmail.com
#  ORGANIZATION: 
#       CREATED: 12/10/19 15:26:58
#===============================================================================

#set -o nounset                              # Treat unset variables as an error
set -o errexit
set -o pipefail

user=robertkielty

#declare -r GITHUB_ORG="RokiTDSOrg" #declare -r GITHUB_USER="RobertKielty" #declare -r GITHUB_REPO="kubernetes"
declare -r CLUSTER_NAME="personal-prow-cluster"
declare -r SECRETS_DIR="./secrets"
declare -r OAUTH_TOKEN="${SECRETS_DIR}/gh-oauth-token"
declare -r HMAC_TOKEN="${SECRETS_DIR}/hmac-token"
# Select the system version of go 
# shellcheck source=../../.gvm/scripts/gvm  

source  ~/.gvm/scripts/gvm # https://github.com/moovweb/gvm/issues/188
gvm use system > /dev/null 
function prowbot-oauth-setup(){
  printf "You need to create a bot account on Github.\n"
  printf "on that bot account goto, \n"
  printf "\thttps://github.com/settings/tokens\n"
  printf "Click on the Generate new token button\n"
  printf "\tThe a/c must have the public_repo and repo:status\n"
  printf "\tAdd the repo scope if you plan on handing private repos\n"
  printf "\tAdd the admin_org:hook scope if you plan on handling a github org\n\n"
  printf "\tPlace the generated oauth token in ${OAUTH_TOKEN}\n"

  printf "For more details goto:\n"
  echo "https://github.com/kubernetes/test-infra/blob/master/prow/getting_started_deploy.md#github-bot-account"
}

function prowbot-hmac-setup() {
  printf "Creating a hmac token for Webhook\n"
  openssl rand -hex 20 > "${HMAC_TOKEN}"
  printf "Created ${HMAC_TOKEN}\n"
}

function check-prowbot-config() {
if [ ! -d $SECRETS_DIR ]; then
  echo "Setting up a secrets dir to store your Github prow bot token"
  mkdir $SECRETS_DIR
else
  if [ ! -f "${HMAC_TOKEN}" ]; then
    echo "hmac-token is missing"
    prowbot-hmac-setup
    exit 101
  fi
  if [ ! -f ${OAUTH_TOKEN} ]; then
    echo "${OAUTH_TOKEN}is missing"
    prowbot-oauth-setup
    exit 102
  fi
fi
}

function check-prow-config() {
checkconfig --plugin-config=/home/${user}/gh/personal-prow/plugins.yaml \
  --config-path=/home/${user}/gh/personal-prow/config.yaml \
  2>&1 >/dev/null | jq . 
}

# TODO handle kind create failure 
function start-personal-prow() {
  if result=$(kind create cluster --name="$CLUSTER_NAME"); then
    echo "$0: kind has brought up $CLUSTER_NAME"
    kubectl cluster-info --context kind-personal-prow-cluster

    CLUSTER_USER=$(kubectl config view -o jsonpath=\'\{.users[*].name\}\')
    # Configure cluster
    kubectl create clusterrolebinding cluster-admin-binding --clusterrole cluster-admin --user "$CLUSTER_USER"
    kubectl create secret generic hmac-token --from-file=hmac="$SECRETS_DIR"/hmac-token 
    kubectl create secret generic oauth-token --from-file=oauth="${OAUTH_TOKEN}"
    kapp deploy -a personal-prow-app -f "$GOPATH"/src/github.com/RobertKielty/test-infra/prow/cluster/starter.yaml
    kubectl create configmap plugins --from-file=plugins.yaml=./plugins.yaml --dry-run -o yaml | kubectl replace configmap plugins -f -
    kubectl create configmap config --from-file=config.yaml=./config.yaml --dry-run -o yaml | kubectl replace configmap config -f -
  fi
}

check-prowbot-config &&
check-prow-config &&
# Start up a kind cluster for prow called personal-prow
if result=$(kind get clusters | grep "$CLUSTER_NAME"); then
  echo "$0: delete old personal-prow"
  if kind delete cluster --name="$CLUSTER_NAME"; then 
    start-personal-prow
  else
    echo "$0 : could not delete personal prow"
    exit 1 
  fi
else
  echo "$0 : creating persinal prow for first time"
  start-personal-prow
fi
echo "$0 : End of script"
exit 0 

