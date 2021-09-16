CLUSTER_NAME=gke-1  
PROJECT_ID=$(gcloud config get-value project)
ZONE=$(gcloud config get-value compute/zone)
gcloud container clusters update $CLUSTER_NAME \
    --workload-pool=$PROJECT_ID.svc.id.goog

curl https://storage.googleapis.com/csm-artifacts/asm/install_asm_1.10 > install_asm

chmod +x install_asm

gcloud container hub memberships get-credentials $CLUSTER_NAME

./install_asm --mode install --managed \
      -p $PROJECT_ID \
      -l $LOCATION \
      -n $CLUSTER_NAME \
      --verbose \
      --output_dir $CLUSTER_NAME \
      --enable-all \
      --enable-registration \
      --option cni-managed

GATEWAY_NAMESPACE=istio-gateway
kubectl create ns $GATEWAY_NAMESPACE
kubectl label namespace $GATEWAY_NAMESPACE istio-injection- istio.io/rev=asm-managed-rapid --overwrite

kubectl apply -f - << EOF
apiVersion: v1
kind: Service
metadata:
  name: istio-ingressgateway
  namespace: $GATEWAY_NAMESPACE
spec:
  type: LoadBalancer
  selector:
    istio: ingressgateway
  ports:
  - port: 80
    name: http
  - port: 443
    name: https
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: istio-ingressgateway
  namespace: $GATEWAY_NAMESPACE
spec:
  selector:
    matchLabels:
      istio: ingressgateway
  template:
    metadata:
      annotations:
        # This is required to tell Anthos Service Mesh to inject the gateway with the
        # required configuration.
        inject.istio.io/templates: gateway
      labels:
        istio: ingressgateway
        istio.io/rev: asm-managed-rapid # This is required only if the namespace is not labeled.
    spec:
      containers:
      - name: istio-proxy
        image: auto # The image will automatically update each time the pod starts.
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: istio-ingressgateway-sds
  namespace: $GATEWAY_NAMESPACE
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "watch", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: istio-ingressgateway-sds
  namespace: $GATEWAY_NAMESPACE
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: istio-ingressgateway-sds
subjects:
- kind: ServiceAccount
  name: default
EOF

