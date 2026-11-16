#!/usr/bin/env bash
# Zorme 浏览器（OpenHarmony）构建 + 签名脚本
#
# 用法：
#   ./build.sh              构建 release HAP 并签名，输出到 dist/
#   ./build.sh --skip-sign  只构建，不签名
#   ./build.sh --debug      以 debug 模式构建（保留 sourceMap，便于排查）
#
# 环境变量：
#   OHOS_SDK     OpenHarmony SDK 根目录（内部需有 26.0.0/ 组件目录）
#   API_VERSION  SDK 版本目录名，默认 26.0.0
#   NODE_PATH    hvigor 依赖模块路径，默认 <工程>/node_modules

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

BUILD_MODE="release"
DO_SIGN=1
for arg in "$@"; do
  case "$arg" in
    --skip-sign) DO_SIGN=0 ;;
    --debug) BUILD_MODE="debug" ;;
    --release) BUILD_MODE="release" ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "未知参数：$arg"; exit 1 ;;
  esac
done

API_VERSION="${API_VERSION:-26.0.0}"
APP_NAME="ZormeBrowser"

# ---------- 定位 SDK ----------
if [[ -z "${OHOS_SDK:-}" && -f local.properties ]]; then
  OHOS_SDK="$(grep -E '^sdk\.dir=' local.properties | head -1 | cut -d= -f2- | tr -d '[:space:]')"
fi
if [[ -z "${OHOS_SDK:-}" ]]; then
  echo "✗ 未找到 SDK：请设置 OHOS_SDK 或在 local.properties 中写入 sdk.dir="
  exit 1
fi

SDK_API_DIR="$OHOS_SDK/$API_VERSION"
SIGN_LIB="$SDK_API_DIR/toolchains/lib"
if [[ ! -d "$SDK_API_DIR" ]]; then
  echo "✗ SDK 目录不存在：$SDK_API_DIR"
  echo "  OpenHarmony SDK 需按 <sdk.dir>/$API_VERSION/<ets|js|native|toolchains|previewer> 组织"
  exit 1
fi

# ---------- 定位 hvigor ----------
export NODE_PATH="${NODE_PATH:-$ROOT/node_modules}"
HVIGOR_JS="$ROOT/node_modules/@ohos/hvigor/bin/hvigor.js"
if [[ -f "$HVIGOR_JS" ]]; then
  HVIGOR_CMD=(node "$HVIGOR_JS")
elif command -v hvigorw >/dev/null 2>&1; then
  HVIGOR_CMD=(hvigorw)
else
  echo "✗ 未找到 hvigor：请先执行 ohpm install（或 npm install）"
  exit 1
fi

# ---------- 构建 ----------
echo "▶ 构建（$BUILD_MODE / API $API_VERSION）"
"${HVIGOR_CMD[@]}" --mode module -p product=default -p "buildMode=$BUILD_MODE" \
  assembleHap --no-daemon

UNSIGNED="$ROOT/entry/build/default/outputs/default/entry-default-unsigned.hap"
if [[ ! -f "$UNSIGNED" ]]; then
  echo "✗ 未找到构建产物：$UNSIGNED"
  exit 1
fi
echo "✓ 未签名产物：$UNSIGNED"

if [[ "$DO_SIGN" -eq 0 ]]; then
  exit 0
fi

# ---------- 签名 ----------
VERSION_NAME="$(grep -oE '"versionName"[[:space:]]*:[[:space:]]*"[^"]+"' AppScope/app.json5 \
  | head -1 | sed -E 's/.*"([^"]+)"$/\1/')"
VERSION_NAME="${VERSION_NAME:-1.0.0}"

KEYSTORE="$SIGN_LIB/OpenHarmony.p12"
APP_CERT="$SIGN_LIB/OpenHarmonyApplication.pem"
PROFILE_CERT="$SIGN_LIB/OpenHarmonyProfileRelease.pem"
SIGN_TOOL="$SIGN_LIB/hap-sign-tool.jar"
STORE_PWD="${KEYSTORE_PWD:-123456}"

if [[ ! -f "$SIGN_TOOL" || ! -f "$KEYSTORE" ]]; then
  echo "✗ 缺少签名工具或测试证书：$SIGN_LIB"
  exit 1
fi

mkdir -p dist
PROFILE_P7B="$ROOT/signature/profile.p7b"
OUT_HAP="$ROOT/dist/${APP_NAME}-${VERSION_NAME}.hap"

echo "▶ 签名描述文件（profile.json → profile.p7b）"
java -jar "$SIGN_TOOL" sign-profile \
  -keyAlias "openharmony application profile release" \
  -signAlg "SHA256withECDSA" \
  -mode "localSign" \
  -profileCertFile "$PROFILE_CERT" \
  -inFile "$ROOT/signature/profile.json" \
  -keystoreFile "$KEYSTORE" \
  -outFile "$PROFILE_P7B" \
  -keyPwd "$STORE_PWD" -keystorePwd "$STORE_PWD"

echo "▶ 签名 HAP"
java -jar "$SIGN_TOOL" sign-app \
  -keyAlias "openharmony application release" \
  -signAlg "SHA256withECDSA" \
  -mode "localSign" \
  -appCertFile "$APP_CERT" \
  -profileFile "$PROFILE_P7B" \
  -inFile "$UNSIGNED" \
  -keystoreFile "$KEYSTORE" \
  -outFile "$OUT_HAP" \
  -keyPwd "$STORE_PWD" -keystorePwd "$STORE_PWD"

echo "▶ 校验签名"
java -jar "$SIGN_TOOL" verify-app \
  -inFile "$OUT_HAP" \
  -outCertChain "$ROOT/dist/${APP_NAME}.cer" \
  -outProfile "$ROOT/dist/${APP_NAME}.p7b"

echo
echo "✓ 完成：$OUT_HAP"
ls -lh "$OUT_HAP" | awk '{print "  大小：" $5}'
