{#- Common functions for pre-check scripts -#}
#!/bin/bash
# OpenShift Pre-Check Script
# Generated for: {{ cluster.name }}.{{ network.domain }}

PASS=0; WARN=0; SECTION=""
pass() { echo -e "  \033[32m✓\033[0m $1"; ((PASS++)); }
warn() { echo -e "  \033[33m!\033[0m $1"; ((WARN++)); }
section() { [ -n "$SECTION" ] && echo ""; SECTION="$1"; echo "$1:"; }
summary() {
    echo ""
    echo "═══════════════════════════════════════"
    echo -e "  \033[32m✓\033[0m $PASS passed   \033[33m!\033[0m $WARN warnings"
    echo "═══════════════════════════════════════"
}

echo "═══════════════════════════════════════"
echo "  Pre-Check: {{ cluster.name }}.{{ network.domain }}"
echo "═══════════════════════════════════════"
