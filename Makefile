
DIR := ${CURDIR}
CLUSTER_NAME = development
CLUSTER_CONFIG = $(DIR)/kind-config.yaml
INGRESS_CONFIG = $(DIR)/ingress-nginx/ingress-nginx.yaml
INGRESS_CONTROLLER_PATCH = $(DIR)/ingress-nginx/ingress-nginx-controller-patch.yaml
KUBECONFIG = $(DIR)/.kubeconfig
NAMESPACE = development

# Below should be the directory name where the value file resides.
POSTGRESQL = postgresql
REDIS = redis
MONGODB = mongodb


# Create a kind cluster.
.PHONY: create-cluster
create-cluster:
	kind create cluster --config $(CLUSTER_CONFIG) --name $(CLUSTER_NAME)
	kubectl create ns $(NAMESPACE) 
	make install-ingress


# Delete a kind cluster.
.PHONY: delete-cluster
delete-cluster:
	kind delete cluster --name $(CLUSTER_NAME)


# Get kubeconfig from kind cluster and save it under current project folder.
.PHONY: get-config
get-config:
	kind get kubeconfig --name $(CLUSTER_NAME) > $(KUBECONFIG)


# Install ingress in kind cluster.
.PHONY: install-ingress
install-ingress:
	kubectl apply -f $(INGRESS_CONFIG)


# Install helm repos in use. 
.PHONY: add-helm-repo
add-helm-repo:
	helm repo add bitnami https://charts.bitnami.com/bitnami


# Helper function to install helm chart into kind cluster.
# 1: Dir name where the value file lives in.
# 2: Chart name.
define install_helm
	helm install $(1) $(2) -n $(NAMESPACE) -f $(DIR)/$(1)/values.yaml
endef


# Helper function to uninstall helm chart in kind cluster.
# 1: Dir name where the value file lives in.
define uninstall_helm
	helm uninstall $(1) -n $(NAMESPACE)
endef

# Helper function to patch ingress controller.
# 1: Port number of the helm chart.
define patch_ingress_controller_port
	kubectl -n ingress-nginx patch deployment ingress-nginx-controller --patch \
	"$$(sed 's/##PORT##/$(1)/g' $(INGRESS_CONTROLLER_PATCH))" 
endef

# Helper function to setup ingress for helm chart.
# 1: Service name of the helm chart.
# 2: Port number of the helm chart.
define patch_tcp_ingress
	kubectl -n ingress-nginx patch configmap tcp-services  --patch '{"data":{"$(2)":"$(NAMESPACE)/$(1):$(2)"}}'
	$(call patch_ingress_controller_port,$(2))
endef


.PHONY: install-postgresql
install-postgresql:
	$(call install_helm,$(POSTGRESQL),"bitnami/postgresql")
	$(call patch_tcp_ingress,postgresql,5432)


.PHONY: uninstall-postgresql
uninstall-postgresql:
	$(call uninstall_helm,$(POSTGRESQL))


.PHONY: install-redis
install-redis:
	$(call install_helm,$(REDIS),"bitnami/redis")
	$(call patch_tcp_ingress,redis-master,6379)


.PHONY: uninstall-redis
uninstall-redis:
	$(call uninstall_helm,$(REDIS))


.PHONY: install-mongodb
install-mongodb:
	$(call install_helm,$(MONGODB),"bitnami/mongodb")
	$(call patch_tcp_ingress,mongodb,27017)


.PHONY: uninstall-mongodb
uninstall-mongodb:
	$(call uninstall_helm,$(MONGODB))
