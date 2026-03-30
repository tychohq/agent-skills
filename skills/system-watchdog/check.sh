#!/usr/bin/env bash
# System Watchdog — check.sh (macOS)
# Delegates to Python for reliable JSON generation.
set -euo pipefail
export PATH="/usr/sbin:/sbin:$PATH"

python3 << 'PYEOF'
import subprocess, json, re

THRESH_RAM_MB = 4096
THRESH_CPU_PCT = 50
THRESH_STALE_DAYS = 2
THRESH_DISK_PCT = 80

SKIP = {"launchd","kernel_task","WindowServer","loginwindow","opendirectoryd",
    "mds_stores","mds","Finder","Dock","SystemUIServer","airportd","bluetoothd",
    "coreduetd","fseventsd","logd","notifyd","powerd","securityd","syslogd",
    "trustd","configd","distnoted","UserEventAgent","tailscaled","sshd","cron",
    "syncthing","coreaudiod","swd","remoted","symptomsd","watchdogd","sandboxd",
    "diskarbitrationd","timed","node","openclaw","bun","openclaw-gatewa",
    "containermanage","runningboardd","rapportd","sharingd","suggestd","nsurlsessiond"}

def parse_elapsed(s):
    """Parse ps etime like '2-03:15:30' or '03:15' to seconds."""
    s = s.strip()
    days = 0
    if '-' in s:
        d, s = s.split('-', 1)
        days = int(d)
    parts = s.split(':')
    parts = [int(p) for p in parts]
    if len(parts) == 3:
        return days*86400 + parts[0]*3600 + parts[1]*60 + parts[2]
    elif len(parts) == 2:
        return days*86400 + parts[0]*60 + parts[1]
    return days*86400 + parts[0]

def human_elapsed(secs):
    if secs >= 86400: return f"{secs//86400}d"
    if secs >= 3600: return f"{secs//3600}h"
    if secs >= 60: return f"{secs//60}m"
    return f"{secs}s"

# System stats
ram_total = int(subprocess.check_output(["sysctl", "-n", "hw.memsize"]).strip())
vm = subprocess.check_output(["vm_stat"]).decode()
page_size = int(re.search(r'(\d+)', vm.split('\n')[0]).group(1))
def vm_val(label):
    m = re.search(rf'{label}:\s+(\d+)', vm)
    return int(m.group(1)) if m else 0
ram_used = (vm_val("Pages active") + vm_val("Pages wired down") + vm_val("Pages occupied by compressor")) * page_size
ram_pct = round(ram_used * 100 / ram_total, 1)

swap = subprocess.check_output(["sysctl", "-n", "vm.swapusage"]).decode()
swap_total = float(re.search(r'total = ([\d.]+)M', swap).group(1)) if 'total' in swap else 0
swap_used = float(re.search(r'used = ([\d.]+)M', swap).group(1)) if 'used' in swap else 0

load = subprocess.check_output(["sysctl", "-n", "vm.loadavg"]).decode().strip().strip('{}').split()
cores = int(subprocess.check_output(["sysctl", "-n", "hw.ncpu"]).strip())

# Disk
df_out = subprocess.check_output(["df", "-g", "/"]).decode().split('\n')[1].split()
disk_total, disk_used = int(df_out[1]), int(df_out[2])
disk_pct = int(df_out[4].rstrip('%'))

# Processes
ps_out = subprocess.check_output(["ps", "axo", "pid=,pcpu=,rss=,etime=,ucomm=", "-r"]).decode()
all_procs = []
issues = []
top_procs = []

for i, line in enumerate(ps_out.strip().split('\n')):
    parts = line.split(None, 4)
    if len(parts) < 5: continue
    pid, cpu, rss, elapsed, name = int(parts[0]), float(parts[1]), int(parts[2]), parts[3], parts[4].strip()
    mem_mb = rss // 1024
    try:
        elapsed_secs = parse_elapsed(elapsed)
    except:
        elapsed_secs = 0
    elapsed_h = human_elapsed(elapsed_secs)
    
    proc = {"pid": pid, "name": name, "cpu_pct": cpu, "mem_mb": mem_mb, "elapsed": elapsed_h, "elapsed_secs": elapsed_secs}
    all_procs.append(proc)

# Get real physical footprint for top processes (macOS footprint command)
def get_phys_footprint(pid):
    """Get real physical memory footprint including GPU/Metal on macOS."""
    try:
        out = subprocess.run(["footprint", str(pid)], capture_output=True, text=True, timeout=5)
        if out.returncode != 0:
            return None
        for line in out.stdout.split('\n'):
            if 'phys_footprint:' in line:
                m = re.search(r'phys_footprint:\s+([\d.]+)\s*(GB|MB|KB|bytes)', line)
                if m:
                    val = float(m.group(1))
                    unit = m.group(2)
                    if unit == 'GB': return int(val * 1024)
                    if unit == 'MB': return int(val)
                    if unit == 'KB': return int(val / 1024)
                    return int(val / (1024*1024))
    except Exception:
        return None
    return None

# Footprint ALL non-trivial processes — including "ignored" ones.
# RSS is blind to GPU/Metal unified memory (e.g., an LM Studio node
# worker shows 11 MB RSS but 21 GB real footprint). The SKIP list gates
# anomaly alerts, NOT footprinting — hidden memory can live in any process.
for proc in all_procs:
    if proc["pid"] < 100:
        continue
    # Skip truly tiny processes to save time
    if proc["mem_mb"] < 5 and proc["cpu_pct"] < 5:
        continue
    footprint_mb = get_phys_footprint(proc["pid"])
    if footprint_mb is not None:
        proc["phys_footprint_mb"] = footprint_mb
        # Check for hidden memory (GPU/Metal) — >2x RSS and >1GB
        if footprint_mb > proc["mem_mb"] * 2 and footprint_mb > 1024:
            hidden_gb = (footprint_mb - proc["mem_mb"]) / 1024
            issues.append({
                "type": "hidden_memory",
                "description": f"{proc['name']} (PID {proc['pid']}) shows {proc['mem_mb']}MB RSS but {footprint_mb}MB real footprint — likely GPU/Metal model loaded in unified memory ({hidden_gb:.1f}GB hidden)",
                "details": proc
            })

# Build top_procs and check for issues
for i, proc in enumerate(sorted(all_procs, key=lambda p: (p.get("phys_footprint_mb", p["mem_mb"]), p["cpu_pct"]), reverse=True)):
    if i < 10:
        top_procs.append(proc)
    
    if proc["name"] in SKIP or proc["pid"] < 100:
        continue
    
    # Use phys_footprint if available, otherwise RSS
    effective_mem_mb = proc.get("phys_footprint_mb", proc["mem_mb"])
    
    if effective_mem_mb > THRESH_RAM_MB:
        mem_source = "phys footprint" if "phys_footprint_mb" in proc else "RSS"
        issues.append({"type": "high_ram", "description": f"{proc['name']} (PID {proc['pid']}) {effective_mem_mb}MB {mem_source}", "details": proc})
    
    if proc["cpu_pct"] > THRESH_CPU_PCT:
        issues.append({"type": "high_cpu", "description": f"{proc['name']} (PID {proc['pid']}) {proc['cpu_pct']}% CPU", "details": proc})
    if proc["elapsed_secs"] > THRESH_STALE_DAYS * 86400 and (effective_mem_mb > 100 or proc["cpu_pct"] > 1):
        issues.append({"type": "stale", "description": f"{proc['name']} (PID {proc['pid']}) running {proc['elapsed']}, {effective_mem_mb}MB", "details": proc})

if disk_pct > THRESH_DISK_PCT:
    issues.append({"type": "disk", "description": f"Root disk at {disk_pct}%", "details": {"mount": "/", "used_pct": disk_pct, "used_gb": disk_used, "total_gb": disk_total}})

result = {
    "suspicious": len(issues) > 0,
    "summary": {
        "ram": f"{ram_used/1073741824:.1f}/{ram_total/1073741824:.1f} GB ({ram_pct}%)",
        "swap": f"{swap_used/1024:.1f}/{swap_total/1024:.1f} GB ({swap_used*100/max(swap_total,1):.0f}%)",
        "load": f"{load[0]}/{load[1]}/{load[2]}",
        "cores": cores,
        "disk": f"{disk_used}/{disk_total} GB ({disk_pct}%)",
    },
    "issues": issues,
    "top_processes": top_procs,
}
print(json.dumps(result, indent=2))
PYEOF
