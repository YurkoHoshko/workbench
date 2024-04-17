DOCKERFILE_PATH = ./Dockerfile
IMAGE_NAME = workbench
PLATFORM = linux/amd64
TAG = latest

.DEFAULT_GOAL := default


build:
	docker buildx build -f $(DOCKERFILE_PATH) --platform $(PLATFORM) -t $(IMAGE_NAME):$(TAG) .

wb:
	docker run --platform linux/amd64  -v ./:/home/yurko/workbench ~/.ssh/:/home/yurko/.ssh -it workbench "tmux"

default:
	@echo "Available targets:"
	@echo "make build Builds the Docker image"
	@echo "make default Prints this message"
