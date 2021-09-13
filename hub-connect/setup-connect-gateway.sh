set -o errexit
set -o pipefail
set -o nounset
#replace user value with  proper LDAP or user name
USER=rickruguichen 
PROJECT_ID=$(gcloud config get-value project)
MEMBER=user:$USER@google.com
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member ${MEMBER} \
  --role roles/gkehub.gatewayAdmin
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member ${MEMBER} \
  --role roles/gkehub.viewer
gcloud services enable --project=$PROJECT_ID \
     connectgateway.googleapis.com \
     cloudresourcemanager.googleapis.com


# [USER_ACCOUNT] is an email, either USER_EMAIL_ADDRESS or GCPSA_EMAIL_ADDRESS
USER_ACCOUNT=$USER@google.com
cat <<EOF > impersonate.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: gateway-impersonate
rules:
- apiGroups:
  - ""
  resourceNames:
  - ${USER_ACCOUNT}
  resources:
  - users
  verbs:
  - impersonate
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: gateway-impersonate
roleRef:
  kind: ClusterRole
  name: gateway-impersonate
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: connect-agent-sa
  namespace: gke-connect
EOF
# Apply impersonation policy to the cluster.
kubectl apply -f impersonate.yaml
