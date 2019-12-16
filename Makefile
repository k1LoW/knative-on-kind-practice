export K8S_VERSION=v1.16.3
export METALLB_VERSION=v0.8.3
export ISTIO_VERSION=1.4.2
export KNATIVE_VERSION=v0.11.0

test_for_linux: install_requirements_for_linux create_cluster install_metallb install_istio install_knative_serving deploy_app port_forward hello_world
test_for_mac: install_requirements_for_mac create_cluster install_metallb install_istio install_knative_serving deploy_app port_forward hello_world

install_requirements_for_linux:
	curl -Lo ./kind https://github.com/kubernetes-sigs/kind/releases/download/v0.6.1/kind-$$(uname)-amd64
	chmod +x ./kind
	sudo mv ./kind /usr/local/bin/kind
	sudo apt-get update && sudo apt-get install -y apt-transport-https
	curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
	echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
	sudo apt-get update
	sudo apt-get install -y kubectl
	curl -LO https://git.io/get_helm.sh | bash

install_requirements_for_mac:
	brew install kind kubernetes-cli helm@2

create_cluster:
	docker ps
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
	(kubectl port-forward svc/istio-ingressgateway -n istio-system 38880:80 &)
	sleep 3

hello_world:
	curl -sL -H "Host: helloworld-go.default.example.com" http://127.0.0.1:38880 | grep Hello

destroy_cluster:
	kind delete cluster --name knative
