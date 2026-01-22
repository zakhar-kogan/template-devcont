FROM debian:bookworm-slim

# Build args - defaults are set in devcontainer.json (single source of truth)
# Python version is set in devcontainer.json features section
ARG TZ
ARG USER_UID
ARG USER_GID
ARG USERNAME=dev
ARG USE_BUN
ARG NODE_VERSION

ENV TZ="$TZ"
ENV DEBIAN_FRONTEND=noninteractive

# Install base packages
RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates curl wget sudo git vim nano zsh unzip \
  iptables ipset iproute2 dnsutils aggregate jq \
  ripgrep bat delta fzf sd miller \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install fnm (Fast Node Manager) - must be done before user creation for root install
ENV FNM_DIR="/usr/local/fnm"
ENV PATH="$FNM_DIR:$PATH"
RUN curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "$FNM_DIR" --skip-shell && \
    export PATH="$FNM_DIR:$PATH" && \
    fnm install ${NODE_VERSION} && \
    fnm default ${NODE_VERSION} && \
    export PATH="$FNM_DIR/aliases/default/bin:$PATH" && \
    corepack enable pnpm

# Install Bun (optional, alongside Node)
RUN if [ "$USE_BUN" = "true" ]; then \
      echo "Installing Bun..." && \
      curl -fsSL https://bun.sh/install | bash && \
      mv /root/.bun /usr/local/bun && \
      ln -s /usr/local/bun/bin/bun /usr/local/bin/bun && \
      ln -s /usr/local/bun/bin/bunx /usr/local/bin/bunx; \
    fi

# Install ast-grep
ENV PNPM_HOME="/usr/local/pnpm-global"
ENV PATH="$PNPM_HOME:$FNM_DIR/aliases/default/bin:$PATH"
RUN mkdir -p $PNPM_HOME && pnpm add -g @ast-grep/cli

# Runtime convenience: js-pm wrapper (uses pnpm by default, bun if USE_BUN=true)
COPY js-pm /usr/local/bin/js-pm
RUN chmod +x /usr/local/bin/js-pm

# Create non-root user (handle existing UID/GID from base image)
RUN if getent group $USER_GID >/dev/null; then groupmod -n $USERNAME $(getent group $USER_GID | cut -d: -f1); \
    else groupadd --gid $USER_GID $USERNAME; fi \
  && if getent passwd $USER_UID >/dev/null; then \
       usermod -l $USERNAME -d /home/$USERNAME -m $(getent passwd $USER_UID | cut -d: -f1); \
     else useradd --uid $USER_UID --gid $USER_GID -m $USERNAME; fi \
  && echo "$USERNAME ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
  && chmod 0440 /etc/sudoers.d/$USERNAME

# Create directories
RUN mkdir -p /workspace /home/$USERNAME/.claude /home/$USERNAME/.cache/uv /home/$USERNAME/.cache/pip /commandhistory \
  && chown -R $USERNAME:$USERNAME /workspace /home/$USERNAME /commandhistory

ENV DEVCONTAINER=true
WORKDIR /workspace
USER $USERNAME

ENV PATH="$PATH:/home/$USERNAME/.local/bin:/home/$USERNAME/.amp/bin"
ENV SHELL=/bin/zsh
ENV EDITOR=nano
ENV VISUAL=nano

# Configure zsh history and fnm
RUN echo 'export HISTFILE=/commandhistory/.zsh_history' >> /home/$USERNAME/.zshrc \
  && echo 'export HISTSIZE=10000' >> /home/$USERNAME/.zshrc \
  && echo 'export SAVEHIST=10000' >> /home/$USERNAME/.zshrc \
  && echo 'eval "$(fnm env --use-on-cd)"' >> /home/$USERNAME/.zshrc

# Firewall script
COPY init-firewall.sh /usr/local/bin/
USER root
RUN chmod +x /usr/local/bin/init-firewall.sh \
  && echo "$USERNAME ALL=(root) NOPASSWD:SETENV: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/$USERNAME-firewall \
  && chmod 0440 /etc/sudoers.d/$USERNAME-firewall

# AI proxy configuration script
COPY configure-ai-proxy.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/configure-ai-proxy.sh
USER $USERNAME

# Optional: Install CLI tools (unpinned - audit per org policy)
# Uncomment the ones you need:
# RUN curl -fsSL https://claude.ai/install.sh | bash
# RUN curl -fsSL https://opencode.ai/install | bash
RUN curl -fsSL https://ampcode.com/install.sh | bash
RUN curl -fsSL https://app.factory.ai/cli | sh
