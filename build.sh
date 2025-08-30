#!/bin/bash

# 设置错误退出和详细输出
set -e
set -o pipefail

# 定义源码根目录（使用脚本所在目录）
AOSP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "当前工作目录: $AOSP_ROOT"
cd "$AOSP_ROOT"

# 增强版克隆函数：确保所有父目录存在，只在目标目录不存在时执行克隆
clone_if_missing() {
    local target_dir=$1
    local repo_url=$2
    
    # 确保所有父目录存在（包括多层嵌套）
    local parent_dir=$(dirname "$target_dir")
    if [ ! -d "$parent_dir" ]; then
        echo "创建多层父目录: $parent_dir"
        mkdir -p "$parent_dir"
        echo "已创建目录结构: $parent_dir"
    fi
    
    if [ ! -d "$target_dir" ]; then
        echo "克隆仓库到 $target_dir"
        # 添加重试机制，防止网络问题导致失败
        local max_attempts=3
        local attempt=1
        
        while [ $attempt -le $max_attempts ]; do
            echo "尝试 $attempt/$max_attempts: 克隆 $repo_url"
            if git clone "$repo_url" "$target_dir" --depth=1; then
                echo "成功克隆: $target_dir"
                break
            else
                echo "尝试 $attempt 失败"
                if [ $attempt -eq $max_attempts ]; then
                    echo "错误: 克隆 $repo_url 失败，已达到最大尝试次数"
                    exit 1
                fi
                # 等待一段时间后重试
                sleep 5
                # 如果目录已部分创建，清理它
                if [ -d "$target_dir" ]; then
                    rm -rf "$target_dir"
                fi
            fi
            attempt=$((attempt + 1))
        done
    else
        echo "目录已存在，跳过克隆: $target_dir"
        # 检查目录是否为空，如果是空的，重新克隆
        if [ -z "$(ls -A "$target_dir")" ]; then
            echo "警告: 目录存在但为空，重新克隆..."
            rm -rf "$target_dir"
            git clone "$repo_url" "$target_dir" --depth=1
            echo "重新克隆完成: $target_dir"
        fi
    fi
}

# 验证Git是否可用
if ! command -v git &> /dev/null; then
    echo "错误: Git未安装或不在PATH中"
    exit 1
fi

echo "开始克隆必要的仓库..."

# 克隆设备相关仓库
clone_if_missing "device/xiaomi/cannon" "https://github.com/lightshi233/android_device_xiaomi_cannon"
clone_if_missing "vendor/xiaomi/cannon" "https://github.com/xiaomi-mt6853-devs/android_vendor_xiaomi_cannon"
clone_if_missing "kernel/xiaomi/cannon" "https://github.com/lightshi233/android_kernel_xiaomi_cannon"

# 克隆 Mediatek 相关仓库
clone_if_missing "hardware/mediatek/wlan" "https://github.com/xiaomi-mt6853-devs/android_hardware_mediatek_wlan"
clone_if_missing "vendor/mediatek/ims" "https://github.com/xiaomi-mt6853-devs/ImsService"
clone_if_missing "vendor/mediatek/location/lppe" "https://github.com/xiaomi-mt6853-devs/LPPeService"
clone_if_missing "vendor/mediatek/telephony/base" "https://github.com/xiaomi-mt6853-devs/MediatekTelephonyBase"

echo "所有仓库克隆完成"

# 确保在源码根目录设置环境
cd "$AOSP_ROOT"
echo "设置构建环境..."

# 检查环境设置文件是否存在
if [ ! -f "build/envsetup.sh" ]; then
    echo "错误: 未找到 build/envsetup.sh，请确保在AOSP根目录运行此脚本"
    exit 1
fi

source build/envsetup.sh

# 使用正确的产品名称
echo "选择产品配置..."
if ! lunch arrow_cannon-userdebug; then
    echo "错误: lunch命令失败，请检查设备配置"
    exit 1
fi

# 编译 - 直接使用mka，它会自动处理并行优化
echo "开始编译..."
if ! mka bacon; then
    echo "错误: 编译失败"
    exit 1
fi

echo "编译完成!"