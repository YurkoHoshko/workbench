## Workbench

### Why?

- [ ] I want a one-stop shop environment that has all of my installations / configs on-demand, with no fuss.
- [ ] I want to be able to adjust programming languages / create problem-specific environments?
- [ ] I want to be able to burn it all to the ground in one command
- [ ] Run in Kubernetes (learning)
- [ ] Makefile?

### Tools


### Assumptions

- [ ] `~/Notes` is always mounted 

### How?


#### Toolbox

- [x] Base Docker image with all of the setup
  - [x] `tmux` + config
  - [x] `fish` + config 
  - [x] `helix` + config
  - [x] `git`
  - [x] `lazygit`
  - [x] `zk`
  - [x] `curl`
  - [x] `bat`
  - [x] `exa`
  - [x] `ripgrep`
  - [x] `fzf`
  - [x] `jq`
  - [x] `openssh`
  - [x] `ansible`
- [ ] Problem-specific Docker images with the necessary installations
  - [ ] Elixir / Gleam dev environment
  - [ ] C# learning environment

#### Workbench

- [ ] Terraform provisioning of infrastructure
- [ ] Ansible provisioning of k3s cluster
  - [x] Install k3s
  - [x] Export KUBECONFIG
  - [x] Install k9s
  - [ ] Setup ArgoCD
  - [ ] Provision via ArgoCD GitOps
    - [ ] Livebook
    - [ ] Toolbox
    - [ ] Blog
    - [ ] Certbot
    - [ ] VPN

### Commands

- Build a new workbench container `docker buildx build . --platform linux/amd64 -t workbench`
- Run a workbench container `docker run --platform linux/amd64 -it workbench "fish"`
