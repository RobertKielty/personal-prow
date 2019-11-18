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

set -o nounset                              # Treat unset variables as an error
set -o errexit
set -o pipefail

user=robertkielty

#declare -r GITHUB_ORG="RokiTDSOrg" #declare -r GITHUB_USER="RobertKielty" #declare -r GITHUB_REPO="kubernetes"
declare -r CLUSTER_NAME="personal-prow-cluster"
declare SECRETS_DIR
SECRETS_DIR="$(pwd)/secrets"
declare -r OAUTH_TOKEN="${SECRETS_DIR}/gh-oauth-token"
declare -r HMAC_TOKEN="${SECRETS_DIR}/hmac-token"

# NOT USED, yet
function get-head-commit() {
  local repo="$1"
  local org="$2"
  if [ ! -d "${repo}" ] ; then
    git clone git@github.com:k14s/"${repo}".git && cd "${repo}"
  else
    cd "${repo}" && git pull git@github.com:"${org}"/"${repo}".git
  fi
  git log  --pretty=format:"%h%x09%an%x09%ad%x09%s" HEAD^..HEAD
}

# TODO Make generic to org
function fetch-k8s-repo-from-github () {
  mkdir -p "${GOPATH}"/src/k8s.io/ && cd "${GOPATH}"/src/k8s.io
  if [ ! -d "${repo}" ] ; then
    git clone git@github.com:k8s.io/"${repo}".git && cd "${repo}"
  else
    cd "${repo}" && git pull git@github.com:k8s.io/"${repo}".git
  fi
  git log  --pretty=format:"%h%x09%an%x09%ad%x09%s" HEAD^..HEAD
}

function install-k14s-from-github () {
  local tool="$1"
  echo "Installing ${tool}..."
  mkdir -p "${GOPATH}"/src/github.com/k14s && cd "${GOPATH}"/src/github.com/k14s
  if [ ! -d "${tool}" ] ; then
    git clone git@github.com:k14s/"${tool}".git && cd "${tool}"
  else
    cd "${tool}" && git pull git@github.com:k14s/"${tool}".git
  fi
  ./hack/build.sh
  echo "Installing ${tool}"
  if [  -f "${tool}" ]; then
    echo "Found ${tool}"
    cp "${tool}" "${GOPATH}"/bin/"${tool}"
    echo "Installed ?? ${tool}"
  else
    echo "Installation problem"
    exit 103
  fi
}

function install-tools() {
  # Install ytt
  if ! command -v ytt >/dev/null 2>&1; then
    install-k14s-from-github ytt
    ytt version
  fi

  # Install kapp
  if ! command -v kapp >/dev/null 2>&1; then
    install-k14s-from-github kapp
    kapp version
  fi

  # Install kwt`
  if ! command -v kwt >/dev/null 2>&1; then
    install-k14s-from-github kwt
    kwt version
  fi
}

function prowbot-oauth-setup(){
  printf "You need to create a bot account on Github.\n"
  printf "on that bot account goto, \n"
  printf "\thttps://github.com/settings/tokens\n"
  printf "Click on the Generate new token button\n"
  printf "\tThe a/c must have the public_repo and repo:status\n"
  printf "\tAdd the repo scope if you plan on handing private repos\n"
  printf "\tAdd the admin_org:hook scope if you plan on handling a github org\n\n"
  printf "\tPlace the generated oauth token in %s\n", "${OAUTH_TOKEN}"

  printf "For more details goto:\n"
  echo "https://github.com/kubernetes/test-infra/blob/master/prow/getting_started_deploy.md#github-bot-account"
}

function prowbot-hmac-setup() {
  printf "Creating a hmac token for Webhook\n"
  openssl rand -hex 20 > "${HMAC_TOKEN}"
  printf "Created %s\n", "${HMAC_TOKEN}"
}

function check-prowbot-config() {
  if [ ! -d "${SECRETS_DIR}" ]; then
    echo "Setting up a secrets dir to store your Github prow bot token"
    mkdir "${SECRETS_DIR}"
  else
    if [ ! -f "${HMAC_TOKEN}" ]; then
      echo "hmac-token is missing"
      prowbot-hmac-setup
      exit 101
    fi
    if [ ! -f "${OAUTH_TOKEN}" ]; then
      echo "${OAUTH_TOKEN} is missing"
      prowbot-oauth-setup
      exit 102
    fi
  fi
}

function check-prow-config() {
  rm -rf ./configured/
  ytt -f . --output-directory ./configured/
  checkconfig --plugin-config=./configured/plugins.yaml \
   --config-path=./configured/config.yaml \
   2>&1 >/dev/null | jq .
}

# TODO handle kind create failure ??
function start-personal-prow-cluster() {
  if kind create cluster --name="$CLUSTER_NAME"; then
    echo "$0: kind has brought up $CLUSTER_NAME"
    kubectl cluster-info --context kind-personal-prow-cluster

    CLUSTER_USER=$(kubectl config view -o jsonpath=\'\{.users[*].name\}\')
    # Configure cluster
    kubectl create clusterrolebinding cluster-admin-binding --clusterrole cluster-admin --user "$CLUSTER_USER"
    kubectl create secret generic hmac-token --from-file=hmac="$SECRETS_DIR"/hmac-token
    kubectl create secret generic oauth-token --from-file=oauth="${OAUTH_TOKEN}"
  fi
}

function add-prow-image-tag() {
  # TODO ask test-infra about picking these image refs up from github #prowconfiginception
  tag=$(kubectl get pod -o jsonpath='{.items[0].spec.containers[0].image}' | cut -d: -f2 )
  printf "#@data/values\n---\nprow-image:\"%s\"\n", $tag > values.yml
  ytt . | kubectl replace -f -
}

function kaap-deploy-prow() {
  if [ -f /home/robertkielty/go/src/k8s.io/test-infra/prow/cluster/starter.yaml ]; then
    echo "deploy starter"
    kapp deploy -a personal-prow-app -f /home/robertkielty/go/src/k8s.io/test-infra/prow/cluster/starter.yaml
    echo "deploy prow config"
    kapp deploy -a personal-prow-app -f ./configured/config.yaml
  else
    echo "deployment file not found!"
  fi
}

function kubectl-deploy-prow() {
  if [ -f /home/robertkielty/go/src/k8s.io/test-infra/prow/cluster/starter.yaml ]; then
    echo "deploy starter"
    kubectl --validate=false apply -f /home/robertkielty/go/src/k8s.io/test-infra/prow/cluster/starter.yaml
    echo "deploy prow config"
    kubectl apply -f ./configured/config.yaml
  else
    echo "deployment file not found!"
  fi
}

install-tools &&
check-prowbot-config &&
check-prow-config &&
# Start up a kind cluster for prow called personal-prow
if kind get clusters | grep "${CLUSTER_NAME}"; then
  echo "$0: delete old personal-prow"
  if kind delete cluster --name="$CLUSTER_NAME"; then
    start-personal-prow-cluster
    kubectl-deploy-prow

    kubectl -n test-pods create secret generic gcs-credentials --from-file=service-account.json
    kubectl create configmap plugins --from-file=plugins.yaml=./configured/plugins.yaml --dry-run -o yaml | kubectl replace configmap plugins -f -
    kubectl create configmap config --from-file=config.yaml=./configured/config.yaml --dry-run -o yaml | kubectl replace configmap config -f -
  else
    echo "$0 : could not delete personal prow"
    exit 1
  fi
else
  echo "$0 : creating personal prow for first time"
  start-personal-prow-cluster
  deploy-prow

  kubectl -n test-pods create secret generic gcs-credentials --from-file=service-account.json 
  kubectl create configmap plugins --from-file=plugins.yaml=./configured/plugins.yaml --dry-run -o yaml | kubectl replace configmap plugins -f -
  kubectl create configmap config --from-file=config.yaml=./configured/config.yaml --dry-run -o yaml | kubectl replace configmap config -f -
fi

echo "$0 : End of script"
exit 0
