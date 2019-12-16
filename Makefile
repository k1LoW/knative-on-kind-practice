export K8S_VERSION=v1.16.3
export METALLB_VERSION=v0.8.3
export ISTIO_VERSION=1.4.2
export KNATIVE_VERSION=v0.11.0

test_create_knative_cluster: install_requirements create_cluster install_metallb install_istio install_knative_serving deploy_app port_forward hello_world

install_requirements:
	brew install kind kubernetes-cli helm@2

create_cluster:
	kind create cluster --name knative --image kindest/node:${K8S_VERSION} --config kind-config.yaml
	kubectl config use-context kind-knative
	kubectl config current-context
	kubectl cluster-info --context kind-knative

install_metallb:
	kubectl apply -f https://raw.githubusercontent.com/google/metallb/${METALLB_VERSION}/manifests/metallb.yaml
	kubectl apply -f metallb-config.yaml --wait

install_istio:
	curl -sL https://istio.io/downloadIstio | sh -
	for i in istio-${ISTIO_VERSION}/install/kubernetes/helm/istio-init/files/crd*yaml; do kubectl apply -f $$i; done
	kubectl apply -f istio-namespace.yaml
	helm template --namespace=istio-system \
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
	kubectl apply -f istio-lean.yaml --wait
	@while kubectl get pods -n istio-system | grep -v NAME | grep -v Running -c >/dev/null; do sleep 5; echo "waiting"; done;

install_knative_serving:
	kubectl apply --filename https://github.com/knative/serving/releases/download/${KNATIVE_VERSION}/serving.yaml
	@while kubectl get pods -n knative-serving | grep -v NAME | grep -v Running -c >/dev/null; do sleep 5; echo "waiting"; done;

deploy_app:
	kubectl apply -f service.yaml
	@while kubectl get ksvc helloworld-go | grep -v NAME | grep -v True -c >/dev/null; do sleep 5; echo "waiting"; done;

port_forward:
	kubectl port-forward svc/istio-ingressgateway -n istio-system 8880:80 &

hello_world:
	curl -sL -H "Host: helloworld-go.default.example.com" http://127.0.0.1:8880 | grep Hello

destroy_cluster:
	kind delete cluster --name knative
