#!/usr/bin/env bash
# C4 conformance helper (Mac 端使用)
#
# 子命令：
#   prepare              在脚本同目录生成 bigfile.bin (4 GiB) + 写入 sha256.txt 上半
#   collect-recv         抓 macOS Engine/Connection 子系统最近 N 分钟 log → recv.log，
#                        对落盘文件 sha256sum → 追加 sha256.txt 下半，
#                        awk 出 chunk-size-histogram.txt
#   clean                删 bigfile.bin（4 GiB 不入 git）
#
# 真机跑测流程见同目录 RESULT.md。

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIGFILE="${HERE}/bigfile.bin"
SHA_FILE="${HERE}/sha256.txt"
SEND_LOG="${HERE}/send.log"
RECV_LOG="${HERE}/recv.log"
HISTO_FILE="${HERE}/chunk-size-histogram.txt"

FILE_BYTES=4294967296   # 4 GiB
CHUNK_DATA_MAX=4194304  # 4 MiB
FRAME_OVERHEAD=29       # length(4, not counted in length field) + type(1) + chunk header(28) -- but length field itself counts type+body, so on-wire frame.length = 1 + 28 + data
LOG_MINUTES="${LOG_MINUTES:-10}"

cmd_prepare() {
    if [[ -f "$BIGFILE" ]]; then
        echo "[prepare] $BIGFILE already exists ($(stat -f%z "$BIGFILE") B). Skip mkfile."
    else
        echo "[prepare] mkfile 4g $BIGFILE  (sparse 不会真占 4 GiB 物理空间，但发送时需读完整 4 GiB)"
        mkfile -n 4g "$BIGFILE"
    fi
    local sz
    sz=$(stat -f%z "$BIGFILE")
    if [[ "$sz" != "$FILE_BYTES" ]]; then
        echo "[prepare] ERROR: expected $FILE_BYTES bytes, got $sz" >&2
        exit 1
    fi
    echo "[prepare] sha256 (这步对 4 GiB 文件耗时 ~30s)..."
    local hash
    hash=$(shasum -a 256 "$BIGFILE" | awk '{print $1}')
    {
        echo "# C4 sha256.txt"
        echo "# 发送侧（iOS 读到的源文件 hash）："
        echo "$hash  bigfile.bin (sender)"
        echo
        echo "# 接收侧（Mac 落盘后的 hash，由 collect-recv 追加）："
    } > "$SHA_FILE"
    echo "[prepare] done. sender hash = $hash"
    echo "[prepare] 下一步：把 $BIGFILE 传入 iOS 端（Simulator: xcrun simctl push；真机: AirDrop）"
}

cmd_collect_recv() {
    local recv_url="${1:-}"
    if [[ -z "$recv_url" ]]; then
        # 默认查 ~/Documents/MeshDrop/*/bigfile.bin
        recv_url=$(/bin/ls -t "$HOME/Documents/MeshDrop/"*/bigfile.bin 2>/dev/null | head -n1 || true)
    fi
    if [[ -z "$recv_url" || ! -f "$recv_url" ]]; then
        echo "[collect-recv] ERROR: 找不到落盘 bigfile.bin。请显式传入路径：" >&2
        echo "  bash run-c4.sh collect-recv /path/to/received/bigfile.bin" >&2
        exit 1
    fi
    echo "[collect-recv] 接收文件: $recv_url"
    local sz
    sz=$(stat -f%z "$recv_url")
    echo "[collect-recv] 大小: $sz B (期望 $FILE_BYTES B, 一致=$([[ $sz == $FILE_BYTES ]] && echo YES || echo NO))"

    echo "[collect-recv] 抓最近 ${LOG_MINUTES} 分钟 com.welape.meshdrop 子系统 log..."
    log show --last "${LOG_MINUTES}m" \
        --predicate 'subsystem == "com.welape.meshdrop"' \
        --style compact 2>/dev/null > "$RECV_LOG" || true
    echo "[collect-recv] recv.log 行数: $(wc -l < "$RECV_LOG")"

    echo "[collect-recv] sha256 接收文件 (~30s)..."
    local hash
    hash=$(shasum -a 256 "$recv_url" | awk '{print $1}')
    if [[ ! -f "$SHA_FILE" ]]; then
        echo "# C4 sha256.txt (recv-only — 缺 sender 行，请先在 iOS 端跑 prepare)" > "$SHA_FILE"
    fi
    {
        echo "$hash  bigfile.bin (receiver, $recv_url)"
    } >> "$SHA_FILE"
    echo "[collect-recv] receiver hash = $hash"

    cmd_histogram
}

cmd_histogram() {
    if [[ ! -f "$RECV_LOG" ]]; then
        echo "[histogram] ERROR: $RECV_LOG 不存在，先跑 collect-recv" >&2
        exit 1
    fi
    echo "[histogram] 统计 recv.log 中 'frame rx type=0x30 len=N' 行..."
    awk '
        # 匹配形如 ... frame rx type=0x30 len=12345 ...  (BSD awk 兼容)
        /frame rx type=0x30 len=/ {
            n = split($0, parts, "len=")
            if (n < 2) next
            len = parts[2] + 0
            if (len <= 0) next
            count++
            sum += len
            if (count == 1 || len > max) max = len
            if (count == 1 || len < min) min = len
            # bucket: <= 256K, 256K-1M, 1M-4M, 4M-4M+29, >4M+29
            if (len <= 262173)            b256k++
            else if (len <= 1048576)      b1m++
            else if (len <= 4194304)      b4m++
            else if (len <= 4194333)      bedge++
            else                          boverflow++
        }
        END {
            print "FILE_CHUNK (type=0x30) frame length 统计"
            print "------------------------------------------"
            printf "  样本数:      %d\n", count
            if (count == 0) {
                print "  (没有匹配行 — 确认 Connection.swift 已含 frame rx debug log，且 log level 抓到了 .debug)"
                exit 0
            }
            printf "  最小:        %d B\n", min
            printf "  最大:        %d B   (规范上限 4 MiB + 29 = 4194333)\n", max
            printf "  平均:        %.0f B\n", sum / count
            printf "  累计:        %d B\n", sum
            print  ""
            print "桶 (frame.length，含 type+chunk header+data):"
            printf "  ≤ 262173 (源码默认 256 KiB chunk):  %d\n", b256k + 0
            printf "  262174 – 1 MiB:                      %d\n", b1m + 0
            printf "  1 MiB – 4 MiB:                       %d\n", b4m + 0
            printf "  4 MiB – 4 MiB + 29:                  %d\n", bedge + 0
            printf "  > 4 MiB + 29  (规范违反!):           %d\n", boverflow + 0
            print ""
            if (max <= 4194333 && (boverflow + 0) == 0) {
                print "结论: chunk 大小合规 (PASS)"
            } else {
                print "结论: chunk 大小违规 (FAIL)"
            }
        }
    ' "$RECV_LOG" > "$HISTO_FILE"
    cat "$HISTO_FILE"
}

cmd_clean() {
    rm -f "$BIGFILE"
    echo "[clean] removed $BIGFILE"
}

usage() {
    cat <<EOF
用法: bash run-c4.sh <prepare|collect-recv [recv-path]|histogram|clean>

  prepare            生成 bigfile.bin (4 GiB sparse) + sender sha256 → sha256.txt
  collect-recv [p]   抓 Engine log + receiver sha256 + chunk histogram
                     不传 p 时默认查 ~/Documents/MeshDrop/*/bigfile.bin
  histogram          仅重跑 awk 统计 (已有 recv.log)
  clean              删 bigfile.bin
EOF
}

case "${1:-}" in
    prepare)      cmd_prepare ;;
    collect-recv) shift; cmd_collect_recv "${1:-}" ;;
    histogram)    cmd_histogram ;;
    clean)        cmd_clean ;;
    *)            usage; exit 1 ;;
esac
