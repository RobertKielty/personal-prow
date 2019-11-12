#!/bin/bash - 
#===============================================================================
#
#          FILE: add_ngrok_hook.sh
# 
#         USAGE: ./add_ngrok_hook.sh 
# 
#   DESCRIPTION: For a personal_prow adds ngrok-created public URL that points
#                to hook running on port 8888 at hook.default.svc.cluster
# 
#       OPTIONS: none 
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Robert Kielty (robk), rob.kielty@gmail.com
#  ORGANIZATION: 
#       CREATED: 05/11/19 13:36:55
#      REVISION:  ---
#===============================================================================
# shellcheck source=../../.gvm/scripts/gvm
source  ~/.gvm/scripts/gvm # https://github.com/moovweb/gvm/issues/188                                                                 
#gvm use system > /dev/null
gvm use system > /dev/null

declare SECRETS_DIR
declare PUBLIC_URL
declare GITHUB_ORG="ROKITdsOrg"
declare GITHUB_REPO="kubernetes"
SECRETS_DIR="$(pwd)/secrets"
# Pre reqs
# TODO get ngrok if not present
function get_ngrok_if_needed() {
  if ! command -v ngrok >/dev/null 2>&1; then 
		echo "$0: visit https://ngrok.com/download and download ngrok for your platform"
		exit 1
	fi
}
function build_add_hook_if_needed() {
  if ! command -v add-hook >/dev/null 2>&1; then 
		echo "Installing add-hook"
		# TODO Github user is hard coded!!
    cd "${GOPATH}"/src/github.com/RobertKielty/test-infra/experiment/add-hook/ || echo "Cannot find local fork of test-infr" ; exit 2
		go install 
	fi
}

# adds a github webhook PUBLIC_URL to the GITHUB/GITHUB_REPO as
function add_hook() {                                                                                                                  
#  local ADD_HOOK_PATH="${GOPATH}"/src/github.com/RobertKielty/test-infra/experiment/add-hook 
#   "${ADD_HOOK_PATH}"/add-hook --confirm --hmac-path="${SECRETS_DIR}"/hmac-token \
   add-hook --confirm --hmac-path="${SECRETS_DIR}"/hmac-token \
		 --github-token-path="${SECRETS_DIR}"/oauth_secret_personal_access_token \
		 --hook-url "${PUBLIC_URL}"/hook \
		 --repo "${GITHUB_ORG}"/"${GITHUB_REPO}"                                                                                            
}

function get_prow_hook_ngrok_public_url() {
	PUBLIC_URL=$(curl -s http://127.0.0.1:4040/api/tunnels | jq -r .tunnels[0].public_url) 
  if [ -z "${PUBLIC_URL}" ]; then
		./tools/ngrok start -all -config=./tools/ngrok.yml &
		sleep 3
	fi
	PUBLIC_URL=$(curl -s http://127.0.0.1:4040/api/tunnels | jq -r .tunnels[0].public_url) 
}

get_prow_hook_ngrok_public_url
build_add_hook_if_needed
add_hook
echo "$0: your ngrok public url is $PUBLIC_URL"
echo "$0: inspect ngrok tunnel locally here http://localhost:4040/inspect/http"
echo "$0: and ./ngrok.log"
echo "$0: verify your github webhook settings here : https://github.com/${GITHUB_ORG}/${GITHUB_REPO}/settings/hooks"

