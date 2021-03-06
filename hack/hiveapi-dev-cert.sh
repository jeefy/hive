#!/bin/bash
set -e

HIVE_NS="${HIVE_NS:-hive}"

mkdir hiveapi-certs
pushd hiveapi-certs

cat <<EOF | cfssl genkey - | cfssljson -bare server
{
  "hosts": [
    "hiveapi.${HIVE_NS}.svc",
    "hiveapi.${HIVE_NS}.svc.cluster.local"
  ],
  "CN": "hiveapi.${HIVE_NS}.svc",
  "key": {
    "algo": "ecdsa",
    "size": 256
  }
}
EOF


cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: hiveapi.${HIVE_NS}
spec:
  request: $(cat server.csr | base64 | tr -d '\n')
  usages:
  - digital signature
  - key encipherment
  - server auth
EOF

kubectl certificate approve hiveapi.${HIVE_NS}

sleep 5
kubectl get csr hiveapi.${HIVE_NS} -o jsonpath='{.status.certificate}' | base64 --decode > server.crt

cat server.crt

cat <<EOF | kubectl apply -f -
kind: Secret
apiVersion: v1
data:
  tls.crt: $(cat server.crt | base64 | tr -d '\n')
  tls.key: $(cat server-key.pem | base64 | tr -d '\n')
metadata:
  name: hiveapi-serving-cert
  namespace: ${HIVE_NS}
type: kubernetes.io/tls
EOF


popd

