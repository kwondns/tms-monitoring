#!/bin/bash
set -euo pipefail

# AWS CLI 호출
OUTPUT=$(aws ce get-free-tier-usage)

# Textfile Collector 디렉터리 (node_exporter 설정에 맞게 조정)
COLLECTOR_DIR=/var/lib/node_exporter/textfile_collector
TMPFILE=$(mktemp)

# JSON 파싱하여 Prometheus 포맷으로 변환
echo "# HELP aws_freetier_usage 실제 프리티어 사용량" > "$TMPFILE"
echo "# TYPE aws_freetier_usage gauge" >> "$TMPFILE"
echo "# HELP aws_freetier_limit 프리티어 한도" >> "$TMPFILE"
echo "# TYPE aws_freetier_limit gauge" >> "$TMPFILE"

echo "$OUTPUT" \
  | jq -r '.freeTierUsages[] |
      "aws_freetier_usage{service=\"\(.service)\",usageType=\"\(.usageType)\",region=\"\(.region)\"} \(.actualUsageAmount)\n\
       aws_freetier_limit{service=\"\(.service)\",usageType=\"\(.usageType)\",region=\"\(.region)\"} \(.limit)"' \
  >> "$TMPFILE"

# 텍스트 파일로 이동
mv "$TMPFILE" "$COLLECTOR_DIR/aws_freetier.prom"
