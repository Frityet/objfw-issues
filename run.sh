#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/common.sh"
REPO_ROOT="$(cd "$REPRO_ROOT/.." && pwd)"

build_repro() {
  local rel="$1"
  local src="$REPRO_ROOT/$rel"
  local out="$BUILD_DIR/$(basename "${rel%.m}")"
  compile_objfw "$src" "$out" >/dev/null
  echo "$out"
}

run_c1() {
  print_header "c1 stream SIZE_MAX overflow"
  local bin
  bin="$(build_repro confirmed/01_stream_size_max_overflow.m)"
  set +e
  "$bin"
  local code=$?
  set -e
  echo "exit_code=$code (expect non-zero / SIGSEGV)"
}

run_c2() {
  print_header "c2 ZIP mutableCopy fileComment mismatch"
  local bin
  bin="$(build_repro confirmed/02_zip_mutablecopy_comment.m)"
  "$bin"
}

run_c3() {
  print_header "c3 SOCKS5 host length truncation"
  local bin
  bin="$(build_repro confirmed/03_socks5_hostlen_trunc.m)"

  for len in 255 256; do
    local cap="$LOG_DIR/c3.proxy.$len.log"
    local client="$LOG_DIR/c3.client.$len.log"

    python3 "$REPRO_ROOT/helpers/socks5_capture.py" >"$cap" 2>&1 &
    local spid=$!
    for _ in $(seq 1 200); do
      [[ -s "$cap" ]] && break
      sleep 0.02
    done

    local port
    port="$(head -n1 "$cap" | tr -d '\r\n')"
    set +e
    "$bin" "$port" "$len" >"$client" 2>&1
    set -e
    wait "$spid" || true

    echo "-- len=$len client --"
    cat "$client"
    echo "-- len=$len proxy --"
    cat "$cap"
  done
}

run_c4() {
  print_header "c4 HTTP long-line memory growth"
  local bin
  bin="$(build_repro confirmed/04_http_line_server.m)"

  local server_log="$LOG_DIR/c4.server.log"
  : > "$server_log"
  "$bin" 18181 >"$server_log" 2>&1 &
  local spid=$!

  for _ in $(seq 1 200); do
    grep -q "LISTENING" "$server_log" && break
    sleep 0.05
  done

  local rss_before
  rss_before="$(awk '/VmRSS:/ {print $2}' "/proc/$spid/status")"

  python3 - <<'PY'
import socket, time
N = 16 * 1024 * 1024
s = socket.create_connection(("127.0.0.1", 18181), timeout=5)
s.sendall(b"GET /")
chunk = b"A" * 65536
remaining = N - 5
while remaining > 0:
    n = min(len(chunk), remaining)
    s.sendall(chunk[:n])
    remaining -= n
time.sleep(2)
s.close()
PY

  local rss_after
  rss_after="$(awk '/VmRSS:/ {print $2}' "/proc/$spid/status")"

  kill "$spid" >/dev/null 2>&1 || true
  wait "$spid" 2>/dev/null || true

  echo "rss_before_kb=$rss_before"
  echo "rss_after_kb=$rss_after"
  echo "rss_delta_kb=$((rss_after-rss_before))"
  echo "-- server log --"
  cat "$server_log"
}

run_c5() {
  print_header "c5 runtime class_addMethod/class_replaceMethod deinit leak"
  local bin
  bin="$(build_repro confirmed/05_runtime_methodlist_deinit_leak.m)"
  local log="$LOG_DIR/c5.valgrind.log"

  set +e
  valgrind --leak-check=full --show-leak-kinds=all \
    --errors-for-leak-kinds=definite --error-exitcode=99 \
    "$bin" >"$log" 2>&1
  local code=$?
  set -e

  echo "valgrind_exit_code=$code (99 expected when definite leaks found)"
  grep -nE "definitely lost|indirectly lost|ERROR SUMMARY" "$log" || true
}

run_c6() {
  print_header "c6 mutable array OOB exception leak"
  local bin
  bin="$(build_repro confirmed/06_mutable_array_oob_leak.m)"
  local log="$LOG_DIR/c6.valgrind.log"

  set +e
  valgrind --leak-check=full --show-leak-kinds=all \
    --errors-for-leak-kinds=definite --error-exitcode=99 \
    "$bin" >"$log" 2>&1
  local code=$?
  set -e

  echo "valgrind_exit_code=$code (99 expected when definite leaks found)"
  grep -nE "definitely lost|ERROR SUMMARY|removeObjectsAtIndexes" "$log" || true
}

run_c7() {
  print_header "c7 test-scaffold leak in CustomData/CustomMutableData"
  local log="$LOG_DIR/c7.valgrind.ofdata.log"
  pushd "$REPO_ROOT/tests" >/dev/null
  set +e
  LD_LIBRARY_PATH="/workspaces/ObjFW/install/lib" \
  valgrind --leak-check=full --show-leak-kinds=all \
    --errors-for-leak-kinds=definite --error-exitcode=99 \
    ./tests OFDataTests >"$log" 2>&1
  local code=$?
  set -e
  popd >/dev/null

  echo "valgrind_exit_code=$code (99 expected when definite leaks found)"
  grep -nE "CustomData|definitely lost|ERROR SUMMARY" "$log" || true
}

run_l1() {
  print_header "l1 weak-reference race stress"
  local bin
  bin="$(build_repro likely/01_weak_race_arc.m)"

  local attempts=5
  local iter=300000
  local crashed=0

  for i in $(seq 1 "$attempts"); do
    set +e
    "$bin" "$iter" >"$LOG_DIR/l1.run.$i.log" 2>&1
    local code=$?
    set -e
    echo "attempt=$i exit_code=$code"
    if [[ $code -ne 0 ]]; then
      crashed=1
      echo "-- failing attempt log (tail) --"
      tail -n 40 "$LOG_DIR/l1.run.$i.log" || true
      break
    fi
  done

  if [[ $crashed -eq 0 ]]; then
    echo "No crash observed in $attempts attempts (nondeterministic race)."
  fi
}

run_l2() {
  print_header "l2 run-loop autorelease-pool lifecycle probe"
  local bin
  bin="$(build_repro likely/02_runloop_pool_probe.m)"
  "$bin"
  echo "Interpretation: if live remains large before second timer, pool draining is suspect."
}

run_l3() {
  print_header "l3 HTTP huge chunk size acceptance probe"
  local bin
  bin="$(build_repro likely/03_http_chunked_huge_server.m)"

  local server_log="$LOG_DIR/l3.server.log"
  : > "$server_log"
  "$bin" 18183 >"$server_log" 2>&1 &
  local spid=$!

  for _ in $(seq 1 200); do
    grep -q "LISTENING" "$server_log" && break
    sleep 0.05
  done

  python3 - <<'PY'
import socket, time
s = socket.create_connection(("127.0.0.1", 18183), timeout=5)
req = (
    b"POST / HTTP/1.1\r\n"
    b"Host: x\r\n"
    b"Transfer-Encoding: chunked\r\n"
    b"\r\n"
    b"7fffffffffffffff\r\n"
)
s.sendall(req)
time.sleep(1.5)
s.close()
PY

  wait "$spid" || true
  cat "$server_log"
  echo "Interpretation: receiving request without immediate 4xx/reject demonstrates no practical chunk-size cap here."
}

run_l4() {
  print_header "l4 OFStream unchecked _readBufferLength+bufferLength wrap (injected state)"
  local bin
  bin="$(build_repro likely/04_stream_readbuffer_wrap_injected.m)"

  set +e
  "$bin"
  local code=$?
  set -e
  echo "exit_code=$code (expect non-zero / SIGSEGV)"
}

run_all() {
  run_c1
  run_c2
  run_c3
  run_c4
  run_c5
  run_c6
  run_c7
  run_l1
  run_l2
  run_l3
  run_l4
}

main() {
  local target="${1:-all}"
  case "$target" in
    c1) run_c1 ;;
    c2) run_c2 ;;
    c3) run_c3 ;;
    c4) run_c4 ;;
    c5) run_c5 ;;
    c6) run_c6 ;;
    c7) run_c7 ;;
    l1) run_l1 ;;
    l2) run_l2 ;;
    l3) run_l3 ;;
    l4) run_l4 ;;
    all) run_all ;;
    *)
      echo "Usage: $0 {c1|c2|c3|c4|c5|c6|c7|l1|l2|l3|l4|all}" >&2
      exit 2
      ;;
  esac
}

main "$@"
