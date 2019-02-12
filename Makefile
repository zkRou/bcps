PROJECT_NAME = bcps
BASE_VERSION = 0.0.1
EXTRA_VERSION ?= $(shell git rev-parse --short HEAD)
BUILD_DIR ?= .build

DOCKER_NS = snlan
DOCKER_PREFIX = bcps
DOCKER_TAG=$(BASE_VERSION)-$(EXTRA_VERSION)

COMMANDS = peer dal ass
IMAGES = $(COMMANDS)

USERID = $(shell id -u)
DRUN = docker run -i --rm --user=$(USERID):$(USERID) \
	-v $(abspath .):/go/src/$(PROJECT_NAME) \
	-w /go/src/$(PROJECT_NAME)

all: help
help:
	@echo
	@echo "帮助文档："
	@echo "  - make help              查看可用脚本"
	@echo "  - make protos            编译 Protobuf 协议文件"
	@echo "  - make native            编译原生可执行文件"
	@echo "  - make docker            编译 Docker 镜像"
	@echo "  - make start             本地启动所有服务"
	@echo "  - make stop              本地终止所有服务"
	@echo "  - make clean             清理可执行文件和 Docker 镜像"
	@echo

protos: image/buildenv
	@$(DRUN) $(DOCKER_NS)/$(DOCKER_PREFIX)-buildenv:$(DOCKER_TAG) ./protos/compile_protos.sh
native: protos $(patsubst %,bin/%, $(COMMANDS))
docker: native $(patsubst %,image/%, $(IMAGES))
clean: stop $(patsubst %,clean/%, $(IMAGES)) clean/buildenv
	-@rm -rf $(BUILD_DIR)
start:
	docker-compose up -d
stop:
	docker-compose down

bin/%:
	$(DRUN) \
		$(DOCKER_NS)/$(DOCKER_PREFIX)-buildenv:$(DOCKER_TAG) \
		go build -o $(BUILD_DIR)/bin/$(@F) $(PROJECT_NAME)/$(@F)

image/%:
	@echo "Building docker image $(@F)"
	docker build -t $(DOCKER_NS)/$(DOCKER_PREFIX)-$(@F) -f ./images/$(@F)/Dockerfile .
	docker tag $(DOCKER_NS)/$(DOCKER_PREFIX)-$(@F) $(DOCKER_NS)/$(DOCKER_PREFIX)-$(@F):$(DOCKER_TAG)

clean/%:
	-docker images --quiet --filter=reference='$(DOCKER_NS)/$(DOCKER_PREFIX)-$(@F):$(DOCKER_TAG)' | xargs docker rmi -f
	-@rm -rf $(BUILD_DIR)/bin/$(@F)


