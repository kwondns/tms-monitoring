#!/bin/bash
set -euo pipefail

# AWS CLI 호출
OUTPUT=$(aws freetier get-free-tier-usage)

# Textfile Collector 디렉터리 (node_exporter 설정에 맞게 조정)
COLLECTOR_DIR=/opt/monitoring/textfile_collector
TMPFILE=$(mktemp)

# JSON 파싱하여 Prometheus 포맷으로 변환
echo "$OUTPUT" | jq -r '.freeTierUsages[] |
  "aws_freetier_usage{service=\"\(.service)\",usageType=\"\(.usageType)\",region=\"\(.region)\",unit=\"\(.unit)\"} \(.actualUsageAmount)\naws_freetier_limit{service=\"\(.service)\",usageType=\"\(.usageType)\",region=\"\(.region)\"} \(.limit)",unit=\"\(.unit)\"' \
> "$TMPFILE"# 텍스트 파일로 이동

mkdir -r "$COLLECTOR_DIR"

mv "$TMPFILE" "$COLLECTOR_DIR/aws_freetier.prom"

chmod 644 $COLLECTOR_DIR/aws_freetier.prom
