#!/bin/bash - 
#===============================================================================
#
#          FILE: setup_storage.sh
# 
#         USAGE: ./setup_storage.sh 
# 
#   DESCRIPTION: Configures storage for personal prow instance 
#                Plank has a dependancy on Google Cloud Storage 
#          REFS: taken from getting_started_deploy.md#configure-cloud-storage
#                in test-infra repo
#        AUTHOR: Robert Kielty (robk), rob.kielty@gmail.com
#  ORGANIZATION: 
#       CREATED: 03/11/19 10:56:25
#===============================================================================

set -o nounset                              # Treat unset variables as an error
set -o errexit
declare PERSONAL_PROW_ARTEFACTS="robk-personal-prow-artifacts"

# TODO make idempotent if gcloud iam service-accounts list --filter='name:prow-gcs-publisher'
# TODO gcloud iam service-accounts create prow-gcs-publisher # step 1

identifier="$( gcloud iam service-accounts list --filter 'name:prow-gcs-publisher' --format 'value(email)' )"
#gsutil mb gs://"${PERSONAL_PROW_ARTEFACTS}"/ # step 2
# gsutil iam ch allUsers:objectViewer gs://"${PERSONAL_PROW_ARTIFACTS}"
# step 3
gsutil iam ch "serviceAccount:${identifier}:objectAdmin" gs://"${PERSONAL_PROW_ARTEFACTS}" # step 4
gcloud iam service-accounts keys create --iam-account "${identifier}" service-account.json # step 5

kubectl -n test-pods create secret generic gcs-credentials --from-file=service-account.json # step 6

