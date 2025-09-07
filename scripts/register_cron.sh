#!/bin/bash
CRON_JOB="0 0 * * * /opt/monitoring/scripts/fetch_freetier.sh >> /var/log/fetch_freetier.log 2>&1"
# 이미 등록되어 있지 않을 경우에만 추가
( crontab -l | grep -F "$CRON_JOB" ) || ( crontab -l 2>/dev/null; echo "$CRON_JOB" ) | crontab -
