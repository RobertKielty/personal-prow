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
#       OPTIONS: ---
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
#set -o xtrace 

#declare -r GITHUB_ORG="RokiTDSOrg" #declare -r GITHUB_USER="RobertKielty" #declare -r GITHUB_REPO="kubernetes"
declare -r CLUSTER_NAME="personal-prow-cluster"
declare SECRETS_DIR
SECRETS_DIR="$(pwd)/secrets"
# Select the system version of go 
# shellcheck source=../../.gvm/scripts/gvm  
source  ~/.gvm/scripts/gvm # https://github.com/moovweb/gvm/issues/188
gvm use system > /dev/null
go version
checkconfig --plugin-config=/home/rkielty/gh/personal-prow/plugins.yaml \
	--config-path=/home/rkielty/gh/personal-prow/config.yaml && \
# Start up a kind cluster for prow called personal-prow
if result=$(kind get clusters | grep "$CLUSTER_NAME"); then
	echo "$0: delete old personal-prow"
	if kind delete cluster --name="$CLUSTER_NAME"; then 
		echo "$0: deleted $CLUSTER_NAME"
		echo "$0: creating new kind cluster $CLUSTER_NAME"
		if result=$(kind create cluster --name="$CLUSTER_NAME"); then
			echo "$0: kind has brought up $CLUSTER_NAME"
			KUBECONFIG="$(kind get kubeconfig-path --name="$CLUSTER_NAME")"
			export KUBECONFIG 
			kubectl cluster-info
			CLUSTER_USER=$(kubectl config view -o jsonpath=\'\{.users[*].name\}\')
			# Configure cluster
			kubectl create clusterrolebinding cluster-admin-binding --clusterrole cluster-admin --user "$CLUSTER_USER"
			kubectl create secret generic hmac-token --from-file=hmac="$SECRETS_DIR"/hmac-token 
			kubectl create secret generic oauth-token --from-file=oauth="$SECRETS_DIR"/oauth_secret_personal_access_token 
			kapp deploy -a personal-prow-app -f "$GOPATH"/src/github.com/RobertKielty/test-infra/prow/cluster/starter.yaml
			kubectl create configmap plugins --from-file=plugins.yaml=./plugins.yaml --dry-run -o yaml | kubectl replace configmap plugins -f -
			kubectl create configmap config --from-file=config.yaml=./config.yaml --dry-run -o yaml | kubectl replace configmap config -f -
		else
			echo "kind create cluster --name=\"personal-prow\" |$result| : Kubeston we have a problem.";
			exit 1 
		fi
	else
		echo "kind delete cluster --name=\"personal-prow\" |$result| : Kubeston we have a problem.";
		exit 1
	fi
fi
exit 0 

