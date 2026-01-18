#!/usr/bin/env bash
set -ex

echo "Current shell: $SHELL"

# 1. 安装 zsh（如需要）
if ! command -v zsh >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y zsh
fi

# 2. 设置默认 shell
case "$SHELL" in
  *zsh) ;;
  *)
    chsh -s "$(which zsh)"
    echo "Default shell set to zsh, please re-login after script finishes."
    ;;
esac

# 3. 安装 Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)" || true
fi

ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

# 4. 插件安装
# 添加自动补全
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git ${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-autosuggestions
# 语法高亮
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
# 高频目录统计和快速跳转(低频使用)
# git clone --depth=1 https://github.com/wting/autojump.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/autojump" \
# && pushd "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/autojump" \
# && ./install.py \
# && popd
# autojump install 结束后会提示内容到.zshrc中，照做即可

# 5. 修改 .zshrc
sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting autojump)/' ~/.zshrc || true
sed -i 's/^ZSH_THEME=.*/ZSH_THEME="rkj-repos"/' ~/.zshrc || true

echo "Setup finished. Please restart terminal or run: source ~/.zshrc"
