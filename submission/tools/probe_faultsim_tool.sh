#!/bin/bash
# Probe the availability of Test-Fault / Test-Faultsim / TetraMAX tooling.
# This script is optional and must not fail the main VCS flow.

set +e

echo "=== Test-Fault / Test-Faultsim Tool Probe ==="
echo "Date: $(date)"
echo ""

for cmd in tmax tmax_shell tetramax testmax; do
    echo "--- which $cmd ---"
    which $cmd 2>&1 || true
    echo ""
done

echo "--- License status (Test-Fault) ---"
lmutil lmstat -f Test-Fault -c "${SNPSLMD_LICENSE_FILE:-$LM_LICENSE_FILE}" 2>&1 || true
echo ""

echo "--- License status (Test-Faultsim) ---"
lmutil lmstat -f Test-Faultsim -c "${SNPSLMD_LICENSE_FILE:-$LM_LICENSE_FILE}" 2>&1 || true
echo ""

echo "Probe complete."
