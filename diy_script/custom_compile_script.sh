#!/bin/bash
# 该脚本会在make defconfig之后执行


# =================================================================
# 函数: install_rustdesk_server
# 描述: 根据当前编译架构自动拉取最新版 RustDesk Server 二进制文件
#       并放置于 files/usr/bin 目录中以集成到固件。
# 注意: 默认调用此函数时，所处位置为 OpenWrt 编译源码根目录
# =================================================================
install_rustdesk_server() {
    echo "========== 开始集成最新版 RustDesk Server =========="

    # 1. 设置 files 目录和临时操作目录 (相对当前源码根目录)
    local FILES_DIR="./files"
    local TMP_DIR="/tmp/rustdesk_install"
    
    mkdir -p "${FILES_DIR}/usr/bin"
    mkdir -p "${TMP_DIR}"

    # 2. 获取最新 Release 下载链接
    echo "正在查询 RustDesk Server 最新版本..."
    local API_URL="https://api.github.com/repos/rustdesk/rustdesk-server/releases/latest"
    local DOWNLOAD_URLS
    DOWNLOAD_URLS=$(curl -s "$API_URL" | grep "browser_download_url" | cut -d '"' -f 4)

    # 3. 动态判断当前编译的架构
    local ARCH_KEYWORD=""
    local EXTRACT_DIR=""
    
    if grep -q "CONFIG_TARGET_x86_64=y" "./.config" 2>/dev/null; then
        echo "检测到目标架构为: x86_64"
        ARCH_KEYWORD="linux-amd64.zip"
        EXTRACT_DIR="amd64"
    elif grep -q "CONFIG_TARGET_rockchip=y" "./.config" 2>/dev/null; then
        echo "检测到目标架构为: rockchip (arm64)"
        ARCH_KEYWORD="linux-arm64v8.zip"
        EXTRACT_DIR="arm64"
    else
        echo "警告：无法在 ./.config 中自动检测到 X86_64 或 rockchip，默认回退使用 x86_64"
        ARCH_KEYWORD="linux-amd64.zip"
        EXTRACT_DIR="amd64"
    fi

    # 4. 匹配对应的下载链接
    local TARGET_URL
    TARGET_URL=$(echo "$DOWNLOAD_URLS" | grep "$ARCH_KEYWORD")

    if [ -z "$TARGET_URL" ]; then
        echo "错误：未找到架构 [$ARCH_KEYWORD] 的下载链接，请检查网络或 GitHub API 限制！"
        return 1 
    fi
    echo "匹配到下载链接: $TARGET_URL"

    # 5. 下载并解压到临时目录
    wget -qO "${TMP_DIR}/rustdesk-server.zip" "$TARGET_URL"
    unzip -q "${TMP_DIR}/rustdesk-server.zip" -d "${TMP_DIR}"

    # 6. 拷贝到固件 files 目录并赋权
    cp "${TMP_DIR}/${EXTRACT_DIR}/hbbs" "${FILES_DIR}/usr/bin/"
    cp "${TMP_DIR}/${EXTRACT_DIR}/hbbr" "${FILES_DIR}/usr/bin/"

    chmod +x "${FILES_DIR}/usr/bin/hbbs"
    chmod +x "${FILES_DIR}/usr/bin/hbbr"

    # 7. 清理临时文件
    rm -rf "${TMP_DIR}"

    echo "========== RustDesk Server 最新版 ($EXTRACT_DIR) 注入固件完成 =========="
}