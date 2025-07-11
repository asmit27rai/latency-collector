## Steps

```base
kubectl --context "$wds_context" apply -f - <<EOF
apiVersion: control.kubestellar.io/v1alpha1
kind: BindingPolicy
metadata:
  name: nginx-singleton-bpolicy
spec:
  clusterSelectors:
    - matchLabels:
        name: cluster1
  downsync:
    - objectSelectors:
        - matchLabels:
            app.kubernetes.io/name: nginx-singleton
      wantSingletonReportedState: true
EOF

# 2) Namespace for latency-collector-system
kubectl --context "$wds_context" apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: latency-collector-system
  labels:
    app.kubernetes.io/name: nginx
EOF

kubectl --context "$wds_context" apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-singleton-deployment
  namespace: latency-collector-system
  labels:
    app.kubernetes.io/name: nginx-singleton
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: nginx-singleton
  template:
    metadata:
      labels:
        app.kubernetes.io/name: nginx-singleton
    spec:
      containers:
        - name: nginx
          image: nginx:alpine
          ports:
            - containerPort: 80
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 5
EOF
```

```bash
./setup-secrets.sh   --host-context kind-kubeflex   --wds wds1   --its its1   --wec-clusters cluster1,cluster2
make deploy       IMG=asmitk1927/ks-latency:v0.5.5
kubectl -n latency-collector-system get pods
```