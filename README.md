## Steps

```bash
make build
make docker-build IMG=asmitk1927/ks-latency:v0.2.2
make docker-push  IMG=asmitk1927/ks-latency:v0.2.2
make deploy       IMG=asmitk1927/ks-latency:v0.2.2
kubectl -n latency-collector-system get pods
```