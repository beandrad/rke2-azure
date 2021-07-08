#!/bin/bash

set -e

KV_NAME=$(terraform output -raw kv_name)

az keyvault secret show --name kubeconfig --vault-name $KV_NAME | jq -r '.value' > rke2.kubeconfig
