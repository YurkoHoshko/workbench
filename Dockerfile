FROM archlinux:latest

ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-256color
ENV COLORTERM=truecolor


# Install required packages
RUN pacman -Syu --noconfirm \
    git \
    tmux \
    fish \
    helix \
    zk \
    lazygit \
    fzf \
    ripgrep \
    bat \
    exa \
    jq \
    less \
    which \
    ansible \
    ansible-language-server \
    openssh \
    && echo "Done!"

# Set fish as the default shell
ENV SHELL=/usr/bin/fish

WORKDIR /home/yurko
COPY tmux/tmux.conf .tmux.conf
COPY helix/ ./.config/helix
COPY fish/ ./.config/fish

RUN useradd -rm -d /home/yurko -ms /bin/bash -g root yurko 
RUN chown -R yurko:root /home/yurko

USER yurko
RUN git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
RUN .tmux/plugins/tpm/bin/install_plugins


# Start fish shell
CMD ["fish"]
