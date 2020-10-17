#!/bin/bash

kubectl get secret -n vault vault-tls -o jsonpath="{.data.ca\.crt}" | base64 --decode > ~/.vault-ca.crt
VAULT_TOKEN=$(kubectl get secrets -n vault vault-unseal-keys -o jsonpath={.data.vault-root} | base64 --decode)

echo "Your Vault root token is: $VAULT_TOKEN"
echo ""
echo "Run the following:"
echo "export VAULT_TOKEN=$VAULT_TOKEN"
echo "export VAULT_CACERT=$HOME/.vault-ca.crt"
echo "kubectl port-forward -n vault service/vault 8200 &"
echo ""
echo "You will then be able to access Vault in your browser at: https://localhost:8200"