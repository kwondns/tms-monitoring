#!/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${YELLOW}🏥 헬스 체크 중...${NC}"

services_healthy=true

# Prometheus 헬스 체크
if curl -s -f http://localhost:9090/-/healthy > /dev/null; then
    echo -e "${GREEN}✅ Prometheus: 정상${NC}"
else
    echo -e "${YELLOW}⚠️  Prometheus: 확인 불가${NC}"
fi

# Grafana 헬스 체크
if curl -s -f http://localhost:3000/api/health > /dev/null; then
    echo -e "${GREEN}✅ Grafana: 정상${NC}"
else
    echo -e "${YELLOW}⚠️  Grafana: 확인 불가${NC}"
fi

if $services_healthy; then
    echo -e "${GREEN}🎉 모든 핵심 서비스가 정상 작동 중입니다!${NC}"
    return 0
else
    echo -e "${RED}⚠️  일부 서비스에 문제가 있습니다.${NC}"
    return 1
fi
