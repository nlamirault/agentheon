#!/bin/bash
# SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>
# SPDX-License-Identifier: Apache-2.0

# Cardinality Analysis Script for Prometheus
# Analyzes metric cardinality and identifies high-cardinality metrics

set -euo pipefail

PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"
TOP_N="${TOP_N:-20}"

echo "🔍 Prometheus Cardinality Analysis"
echo "=================================="
echo "Prometheus URL: $PROMETHEUS_URL"
echo ""

# Check if Prometheus is reachable
if ! curl -s "${PROMETHEUS_URL}/-/healthy" > /dev/null; then
    echo "❌ Error: Cannot reach Prometheus at $PROMETHEUS_URL"
    echo "Set PROMETHEUS_URL environment variable to your Prometheus endpoint"
    exit 1
fi

echo "✅ Prometheus is reachable"
echo ""

# Total series count
echo "📊 Total Metrics Series"
echo "-----------------------"
TOTAL_SERIES=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=count({__name__=~\".%2B\"})" | \
    jq -r '.data.result[0].value[1] // "0"')
echo "Total active series: $(printf "%'d" "$TOTAL_SERIES")"
echo ""

# Check if approaching limits
if [ "$TOTAL_SERIES" -gt 1000000 ]; then
    echo "⚠️  WARNING: High series count (>1M) - cardinality issues likely"
elif [ "$TOTAL_SERIES" -gt 500000 ]; then
    echo "⚠️  WARNING: Elevated series count (>500K) - monitor cardinality"
else
    echo "✅ Series count is healthy (<500K)"
fi
echo ""

# Top metrics by series count
echo "📈 Top $TOP_N Metrics by Series Count"
echo "--------------------------------------"
curl -s "${PROMETHEUS_URL}/api/v1/query?query=topk($TOP_N,count%20by%20(__name__)%20({__name__=~\".%2B\"}))" | \
    jq -r '.data.result[] | "\(.value[1])\t\(.metric.__name__)"' | \
    sort -rn | \
    awk 'BEGIN {print "Series\tMetric Name"} {printf "%'"'"'d\t%s\n", $1, $2}'
echo ""

# Series count per job
echo "🏷️  Series Count by Job"
echo "-----------------------"
curl -s "${PROMETHEUS_URL}/api/v1/query?query=count%20by%20(job)%20({__name__=~\".%2B\"})" | \
    jq -r '.data.result[] | "\(.value[1])\t\(.metric.job)"' | \
    sort -rn | \
    awk 'BEGIN {print "Series\tJob"} {printf "%'"'"'d\t%s\n", $1, $2}'
echo ""

# High cardinality detection
echo "🚨 High Cardinality Metrics (>10K series)"
echo "------------------------------------------"
curl -s "${PROMETHEUS_URL}/api/v1/query?query=count%20by%20(__name__)%20({__name__=~\".%2B\"})%20>%2010000" | \
    jq -r '.data.result[] | "\(.value[1])\t\(.metric.__name__)"' | \
    sort -rn | \
    awk '{printf "%'"'"'d\t%s\n", $1, $2}'

HIGH_CARD_COUNT=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=count%20by%20(__name__)%20({__name__=~\".%2B\"})%20>%2010000" | \
    jq -r '.data.result | length')

if [ "$HIGH_CARD_COUNT" -gt 0 ]; then
    echo ""
    echo "⚠️  Found $HIGH_CARD_COUNT metrics with >10K series"
    echo "   Consider:"
    echo "   - Using recording rules to aggregate"
    echo "   - Dropping unnecessary labels with metric_relabel_configs"
    echo "   - Removing high-cardinality labels (user_id, session_id, etc.)"
else
    echo "✅ No high-cardinality metrics detected"
fi
echo ""

# Label cardinality analysis
echo "🏷️  Label Cardinality Analysis"
echo "------------------------------"
echo "Analyzing label value counts..."
echo ""

# This queries label cardinality for common problematic labels
for label in "instance" "pod" "container" "node" "service" "job"; do
    LABEL_CARD=$(curl -s "${PROMETHEUS_URL}/api/v1/label/${label}/values" | jq -r '.data | length')
    if [ "$LABEL_CARD" -gt 0 ]; then
        printf "%-15s %'d unique values\n" "${label}:" "$LABEL_CARD"
    fi
done
echo ""

# Memory usage estimation
echo "💾 Storage Estimation"
echo "---------------------"
# Rough estimate: ~1-3 bytes per sample, 1 sample per series per scrape interval
# Assuming 15s scrape interval, 15d retention
SAMPLES_PER_DAY=$((TOTAL_SERIES * 4 * 60 * 24))  # 4 samples per minute
SAMPLES_15D=$((SAMPLES_PER_DAY * 15))
STORAGE_GB=$((SAMPLES_15D * 2 / 1024 / 1024 / 1024))  # 2 bytes per sample avg

echo "Estimated storage (15d retention, 15s scrape):"
echo "  Daily samples: $(printf "%'d" "$SAMPLES_PER_DAY")"
echo "  15-day samples: $(printf "%'d" "$SAMPLES_15D")"
echo "  Storage needed: ~${STORAGE_GB}GB"
echo ""

# Recommendations
echo "💡 Recommendations"
echo "------------------"

if [ "$TOTAL_SERIES" -gt 1000000 ]; then
    echo "🔴 CRITICAL: Reduce cardinality immediately"
    echo "   1. Drop unnecessary metrics with metric_relabel_configs"
    echo "   2. Remove high-cardinality labels"
    echo "   3. Use recording rules to pre-aggregate"
    echo "   4. Consider VictoriaMetrics for better cardinality handling"
elif [ "$TOTAL_SERIES" -gt 500000 ]; then
    echo "🟡 WARNING: Monitor cardinality closely"
    echo "   1. Review high-cardinality metrics listed above"
    echo "   2. Plan to implement recording rules"
    echo "   3. Audit label usage"
elif [ "$TOTAL_SERIES" -gt 100000 ]; then
    echo "🟢 HEALTHY: Cardinality is acceptable"
    echo "   1. Continue monitoring growth"
    echo "   2. Implement cardinality budgets per service"
else
    echo "🟢 OPTIMAL: Low cardinality"
    echo "   1. Current setup is efficient"
    echo "   2. Monitor as you add new services"
fi
echo ""

echo "✅ Analysis complete!"
echo ""
echo "For more details, visit:"
echo "  Prometheus UI: ${PROMETHEUS_URL}/graph"
echo "  TSDB Status: ${PROMETHEUS_URL}/tsdb-status"
