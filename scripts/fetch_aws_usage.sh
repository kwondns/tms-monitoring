#!/bin/bash

############################
# 6개월 월별 사용량
############################

TEXTFILE_DIR="/opt/monitoring/node_exporter/textfile_collector"
TEMP_FILE_MONTHLY=$(mktemp)
OUTPUT_FILE="$TEXTFILE_DIR/aws_monthly_costs.prom"

# 6개월 전 월 시작일과 다음 월 시작일 설정
SIX_MONTHS_AGO_START=$(date +"%Y-%m-01" -d "6 months ago")
NEXT_MONTH_START=$(date +"%Y-%m-01" -d "$(date +%Y-%m-01) + 1 month")

# AWS Cost Explorer에서 6개월 비용 조회 - 올바른 메트릭 이름 사용
COST_DATA=$(aws ce get-cost-and-usage \
  --time-period "Start=$SIX_MONTHS_AGO_START,End=$NEXT_MONTH_START" \
  --metrics UNBLENDED_COST \
  --granularity MONTHLY \
  --output json 2>/dev/null)

if [ $? -eq 0 ]; then
  mkdir -p "$TEXTFILE_DIR"

  # Prometheus 메트릭 헤더 작성
  cat > "$TEMP_FILE_MONTHLY" << 'INNER_EOF'
# HELP aws_monthly_cost_usd AWS monthly costs in USD
# TYPE aws_monthly_cost_usd gauge
# HELP aws_current_month_cost_usd AWS current month cost to date in USD
# TYPE aws_current_month_cost_usd gauge
# HELP aws_cost_last_updated_timestamp Last time AWS cost data was updated
# TYPE aws_cost_last_updated_timestamp gauge
INNER_EOF

  # jq를 사용하여 월별 비용 메트릭 생성
  echo "$COST_DATA" | jq -r '
    .ResultsByTime[] |
    "aws_monthly_cost_usd{month=\"" + .TimePeriod.Start[0:7] + "\"} " + .Total.UnblendedCost.Amount
  ' >> "$TEMP_FILE_MONTHLY"

  # 현재 월 총 비용 메트릭 추가
  CURRENT_MONTH=$(date +"%Y-%m")
  CURRENT_COST=$(echo "$COST_DATA" | jq -r --arg m "$CURRENT_MONTH" '
    .ResultsByTime[] |
    select(.TimePeriod.Start | startswith($m)) |
    .Total.UnblendedCost.Amount // "0"
  ')
  echo "aws_current_month_cost_usd{month=\"$CURRENT_MONTH\"} $CURRENT_COST" >> "$TEMP_FILE_MONTHLY"

  # 업데이트 타임스탬프
  echo "aws_cost_last_updated_timestamp $(date +%s)" >> "$TEMP_FILE_MONTHLY"

  # 원자적 파일 이동
  mv "$TEMP_FILE_MONTHLY" "$OUTPUT_FILE"

  # 로깅: 각 월별 비용 출력
  echo "$COST_DATA" | jq -r '.ResultsByTime[] | .TimePeriod.Start[0:7] + ": $" + .Total.UnblendedCost.Amount'
else
  echo "Failed to retrieve AWS cost data" >&2
  rm -f "$TEMP_FILE_MONTHLY"
  exit 1
fi

############################
# 서비스 별 사용량 & 비용 (현재 월)
############################

TEMP_FILE_SERVICE=$(mktemp)
OUTPUT_FILE="$TEXTFILE_DIR/aws_current_cost_by_service.prom"

# 현재 월 시작일과 다음 월 시작일 설정
MONTH_START=$(date +"%Y-%m-01")
NEXT_MONTH_START=$(date +"%Y-%m-01" -d "$(date +%Y-%m-01) + 1 month")
CURRENT_MONTH=$(date +"%Y-%m")

# 서비스별 현재 월 비용(UNBLENDED_COST) 및 사용량(USAGE_QUANTITY) 조회 - 올바른 메트릭 이름 사용
COST_DATA=$(aws ce get-cost-and-usage \
  --time-period "Start=$MONTH_START,End=$NEXT_MONTH_START" \
  --metrics UNBLENDED_COST USAGE_QUANTITY \
  --granularity MONTHLY \
  --group-by Type=DIMENSION,Key=SERVICE \
  --output json 2>/dev/null)

if [ $? -eq 0 ]; then
  cat > "$TEMP_FILE_SERVICE" << 'INNER_EOF'
# HELP aws_service_monthly_cost_usd AWS service monthly cost in USD
# TYPE aws_service_monthly_cost_usd gauge
# HELP aws_service_monthly_usage AWS service monthly usage quantity
# TYPE aws_service_monthly_usage gauge
# HELP aws_current_month_total_cost_usd AWS current month total cost in USD
# TYPE aws_current_month_total_cost_usd gauge
INNER_EOF

  # jq를 사용하여 서비스별 비용·사용량 메트릭 생성 - 올바른 메트릭 이름 사용
  echo "$COST_DATA" | jq -r --arg m "$CURRENT_MONTH" '
    .ResultsByTime[0].Groups[] |
    "aws_service_monthly_cost_usd{service=\"\(.Keys[0])\",month=\"\($m)\"} \(.Metrics.UnblendedCost.Amount)",
    "aws_service_monthly_usage{service=\"\(.Keys[0])\",month=\"\($m)\"} \(.Metrics.UsageQuantity.Amount)"
  ' >> "$TEMP_FILE_SERVICE"

  # 총 비용 메트릭 추가 - Total에서 UNBLENDED_COST 가져오기
  TOTAL_COST=$(echo "$COST_DATA" | jq -r '
    .ResultsByTime[0].Groups[] | .Metrics.UnblendedCost.Amount | tonumber
  ' | awk '{sum += $1} END {print sum}')

  # TOTAL_COST가 비어있거나 null인 경우 0으로 설정
  if [ -z "$TOTAL_COST" ] || [ "$TOTAL_COST" = "null" ]; then
    TOTAL_COST="0"
  fi

  echo "aws_current_month_total_cost_usd{month=\"$CURRENT_MONTH\"} $TOTAL_COST" >> "$TEMP_FILE_SERVICE"

  # 원자적 파일 이동
  mv "$TEMP_FILE_SERVICE" "$OUTPUT_FILE"
else
  echo "Failed to retrieve AWS service cost data" >&2
  rm -f "$TEMP_FILE_SERVICE"
  exit 1
fi
