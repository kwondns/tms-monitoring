#!/bin/bash
set -e

cd /opt/monitoring

echo -e "${YELLOW}🚀 서비스 배포 중...${NC}"

# ECR 로그인
echo "ECR 로그인 중..."
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=ap-northeast-2
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.ap-northeast-2.amazonaws.com

# 이전 컨테이너 정리
echo "이전 컨테이너 정리 중..."
docker-compose down --remove-orphans 2>/dev/null || true

# 최신 이미지 pull
echo "최신 이미지 다운로드 중..."
docker-compose pull

echo -e "${GREEN}✅ 이미지 업데이트 완료${NC}"
