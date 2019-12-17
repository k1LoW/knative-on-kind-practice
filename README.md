# Knative on kind practice

## Install requirements

**Knative on kind on Docker Desktop on Mac:**

``` console
$ brew install kind kubernetes-cli helm@2
```

**Knative on kind on Linux:**

``` console
$ export KIND_VERSION=v0.6.1
$ curl -Lo ./kind https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-$(uname)-amd64
$ chmod +x ./kind
$ sudo mv ./kind /usr/local/bin/kind
$ sudo apt-get update && sudo apt-get install -y apt-transport-https
$ curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
$ echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
$ sudo apt-get update
$ sudo apt-get install -y kubectl
$ curl -LO https://git.io/get_helm.sh | bash
```

## Create Kubernetes cluster on kind

``` console
$ export K8S_VERSION=v1.16.3
$ kind create cluster --name knative --image kindest/node:${K8S_VERSION} --config kind-config.yaml
Creating cluster "knative" ...
 ✓ Ensuring node image (kindest/node:v1.16.3) 🖼
 ✓ Preparing nodes 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
 ✓ Joining worker nodes 🚜
Set kubectl context to "kind-knative"
You can now use your cluster with:

kubectl cluster-info --context kind-knative

Have a question, bug, or feature request? Let us know! https://kind.sigs.k8s.io/#community 🙂
$ kubectl config use-context kind-knative
$ kubectl config current-context
kind-knative
$ kubectl cluster-info --context kind-knative
Kubernetes master is running at https://127.0.0.1:61330
KubeDNS is running at https://127.0.0.1:61330/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

## Install MetalLB

https://metallb.universe.tf/installation/#installation-with-kubernetes-manifests

``` console
$ export METALLB_VERSION=v0.8.3
$ kubectl apply -f https://raw.githubusercontent.com/google/metallb/${METALLB_VERSION}/manifests/metallb.yaml
$ kubectl apply -f metallb-config.yaml
```

## Install Istio for Knative

https://knative.dev/docs/install/installing-istio/

``` console
$ export ISTIO_VERSION=1.4.2
$ curl -L https://istio.io/downloadIstio | sh -
$ for i in istio-${ISTIO_VERSION}/install/kubernetes/helm/istio-init/files/crd*yaml; do kubectl apply -f $i; done
$ kubectl apply -f istio-namespace.yaml
$ helm template --namespace=istio-system \
  --set prometheus.enabled=false \
  --set mixer.enabled=false \
  --set mixer.policy.enabled=false \
  --set mixer.telemetry.enabled=false \
  --set pilot.sidecar=false \
  --set pilot.resources.requests.memory=128Mi \
  --set galley.enabled=false \
  --set global.useMCP=false \
  --set security.enabled=false \
  --set global.disablePolicyChecks=true \
  --set sidecarInjectorWebhook.enabled=false \
  --set global.proxy.autoInject=disabled \
  --set global.omitSidecarInjectorConfigMap=true \
  --set gateways.istio-ingressgateway.autoscaleMin=1 \
  --set gateways.istio-ingressgateway.autoscaleMax=2 \
  --set pilot.traceSampling=100 \
  istio-${ISTIO_VERSION}/install/kubernetes/helm/istio \
  > ./istio-lean.yaml
$ kubectl apply -f istio-lean.yaml
$ kubectl get pods -n istio-system
NAME                                    READY   STATUS    RESTARTS   AGE
istio-ingressgateway-6b699467f5-bxzjs   1/1     Running   0          42s
istio-pilot-7957c5468f-q67zl            1/1     Running   0          42s
$ kubectl get svc -n istio-system
NAME                   TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)
        AGE
istio-ingressgateway   LoadBalancer   10.99.44.136    192.168.1.240   15020:30715/TCP,80:31380/TCP,443:31390/TCP,31400:31400/TCP,15029:31512/TCP,15030:30136/TCP,15031:30290/TCP,15032:31941/TCP,15443:31026/TCP   45s
istio-pilot            ClusterIP      10.100.11.226   <none>          15010/TCP,15011/TCP,8080/TCP,15014/TCP
        45s
```

## Install Knative (Serving)

``` console
$ kubectl apply --filename https://github.com/knative/serving/releases/download/v0.11.0/serving.yaml
$ kubectl get pods -n knative-serving
NAME                                READY   STATUS    RESTARTS   AGE
activator-7db6679666-rm724          1/1     Running   0          41s
autoscaler-ffc9f79b4-nkd6n          1/1     Running   0          41s
autoscaler-hpa-5994dfdb67-j9vnv     1/1     Running   0          41s
controller-6797f99458-86vnl         1/1     Running   0          40s
networking-istio-85484dc749-qdcnh   1/1     Running   0          39s
webhook-6f97457cbf-wbzwq            1/1     Running   0          39s
```

## Deploy app

https://knative.dev/docs/serving/getting-started-knative-app/

``` console
$ kubectl apply -f service.yaml
$ kubectl get ksvc helloworld-go
NAME            URL                                        LATESTCREATED         LATESTREADY           READY   REASON
helloworld-go   http://helloworld-go.default.example.com   helloworld-go-k2c9b   helloworld-go-k2c9b   True
```

## Port forward

``` console
$ kubectl port-forward svc/istio-ingressgateway -n istio-system 8880:80
```

## Hello World

``` console
$ curl -H "Host: helloworld-go.default.example.com" http://127.0.0.1:8880
Hello Go Sample v1!
```
