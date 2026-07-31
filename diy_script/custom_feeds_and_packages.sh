#!/bin/bash

# feeds扩展内容
export repos=(
  "src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main"
  "src-git passwall https://github.com/Openwrt-Passwall/openwrt-passwall.git;main"
  "src-git passwall2 https://github.com/Openwrt-Passwall/openwrt-passwall2.git;main"
  "src-git helloworld https://github.com/fw876/helloworld;master"
  "src-git OpenClash https://github.com/vernesong/OpenClash;master"
  "src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki.git;main"
  "src-git ghfu https://github.com/smallprogram/openwrt-ghfu.git;main"
)

# 自定义软件包列表
clone_custom_packages () {
    local path="package/custom_packages/"

    if [ "$GITHUB_ACTIONS" = "true" ] && [ -n "$GITHUB_RUN_ID" ] && [ -n "$GITHUB_WORKFLOW" ]; then
        PATCHES_SRC_DIR="$GITHUB_WORKSPACE"
    else
        PATCHES_SRC_DIR="../OpenWrtAction"
    fi


    rm -rf ${path}
    mkdir -p ${path}

    # 主题
    git clone https://github.com/jerrykuku/luci-theme-argon.git ${path}luci-theme-argon
    git clone https://github.com/jerrykuku/luci-app-argon-config.git ${path}luci-app-argon-config
    git clone https://github.com/sirpdboy/luci-theme-kucat.git ${path}luci-theme-kucat
    git clone https://github.com/sirpdboy/luci-app-kucat-config.git ${path}luci-app-kucat-config
    git clone https://github.com/eamonxg/luci-theme-aurora.git ${path}luci-theme-aurora
    git clone https://github.com/derisamedia/luci-theme-arwi.git ${path}luci-theme-arwi
    git clone https://github.com/derisamedia/luci-theme-alpha.git ${path}luci-theme-alpha
    git clone https://github.com/animegasan/luci-app-alpha-config.git ${path}luci-app-alpha-config
    git clone https://github.com/AngelaCooljx/luci-theme-material3.git ${path}luci-theme-material3

    git clone https://github.com/sbwml/luci-app-mosdns -b v5 ${path}mosdns

    git clone https://github.com/sirpdboy/netspeedtest.git ${path}netspeedtest

    git clone https://github.com/pymumu/openwrt-smartdns.git ${path}openwrt-smartdns
    git clone https://github.com/pymumu/luci-app-smartdns.git ${path}luci-app-smartdns

    git clone https://github.com/timsaya/openwrt-bandix.git ${path}openwrt-bandix
    git clone https://github.com/timsaya/luci-app-bandix.git ${path}luci-app-bandix

    git clone https://github.com/timsaya/openwrt-bandix-plus.git ${path}openwrt-bandix-plus
    git clone https://github.com/timsaya/luci-app-bandix-plus.git ${path}luci-app-bandix-plus
    
    git clone https://github.com/destan19/OpenAppFilter.git ${path}OpenAppFilter

    

    # sed -i '/^[\t ]*PKG_VERSION:=/ s/\(PKG_VERSION:= *\)[^0-9.]*\([0-9.]*\)[^0-9.]*/\1\2/' "${path}luci-theme-alpha-reborn/Makefile"
    sed -i '/^[\t ]*PKG_VERSION:=/ s/\(PKG_VERSION:= *\)[^0-9.]*\([0-9.]*\)[^0-9.]*/\1\2/' "${path}luci-theme-alpha/Makefile"

    
    local target="luci.main.mediaurlbase="

    echo "开始全量扫描并注释目标字符串, 取消主题自动设置为默认主题..."
    # 1. 扫描所有 Makefile 文件
    # 2. 扫描所有 uci-defaults 目录下的文件
    find "$path" -type f \( -name "Makefile" -o -path "*/etc/uci-defaults/*" \) | while read -r file; do
        
        # 这里的 grep 需要更宽松，因为 Makefile 里的行首可能是 Tab 或者是脚本定义的起始
        if grep -q "$target" "$file"; then
            echo "命中目标: $file"
            
            # 针对 Makefile 的特殊处理：
            # Makefile 里的 postrm 脚本行首通常会有空格或 Tab
            # 我们直接匹配包含 target 的行，并在该行非空字符前加 #
            # 使用 [[:blank:]]* 兼容 Tab 和空格
            sed -i "/$target/s/^\([[:blank:]]*\)\([^#[:blank:]]\)/\1# \2/" "$file"
        fi
    done

    echo "注释处理完成。"
    #-------------------------------------------设置默认主题------------------------------------------
    # 1. 确保构建根目录下的自定义文件路径存在
    mkdir -p files/etc/uci-defaults
    # 2. 将主题设置脚本写入到 zz-set-default-theme 文件中
    # 这里的文本必须全部顶格写，防止 #!/bin/sh 前面产生空格
cat << "EOF" > files/etc/uci-defaults/zz-set-default-theme
#!/bin/sh

# 强制覆写节点，不判断任何条件
uci set luci.themes.Argon=/luci-static/argon
uci set luci.main.mediaurlbase=/luci-static/argon
uci commit luci

exit 0
EOF

    # 3. 赋予可执行权限（否则不会在开机执行）
    chmod +x files/etc/uci-defaults/zz-set-default-theme

    echo "默认主题设置已生成！"
    #-------------------------------------------end设置默认主题------------------------------------------
}


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