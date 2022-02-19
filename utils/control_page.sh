#!/bin/sh

REFRESH_INTERVAL=3

PAGE_FILE_NAME=check.html

PAGE_LINE='<iframe src="%s.html"></iframe>'


PUBLIC_ALB_DNS_NAME=$(aws cloudformation describe-stacks --stack-name pipeline-ec2-spring-boot-global --query "Stacks[0].Outputs[?OutputKey=='LoadBalanderDNSName'].OutputValue" --output "text")

PIPELINE_NAME=$(aws cloudformation describe-stacks --stack-name pipeline-ec2-spring-boot-global --query "Stacks[0].Outputs[?OutputKey=='ProjectPipeline'].OutputValue" --output "text")

function get_ec2_targets(){
  local PUBLIC_EC2_DNS_NAMES=$(aws ec2 describe-instances \
    --filters Name=instance-state-name,Values=running \
    --query="Reservations[*].Instances[*].PublicDnsName" \
    --output text)
  echo $PUBLIC_EC2_DNS_NAMES
}

function create_page() {
  cat <<EOF > ${PAGE_FILE_NAME}
<!doctype html>
<html>
<head> <meta http-equiv="refresh" content="${REFRESH_INTERVAL}"> </head>
<body>
EOF
printf "<h2>${PIPELINE_NAME}</h2>\n" >> ${PAGE_FILE_NAME}
printf "<h1>ALB</h1>\n" >> ${PAGE_FILE_NAME}
printf "${PAGE_LINE}\n" "${PUBLIC_ALB_DNS_NAME}" >> ${PAGE_FILE_NAME}
printf "</br>" >> ${PAGE_FILE_NAME}
# EC2
printf "<h1>EC2</h1>\n" >> ${PAGE_FILE_NAME}
for PUBLIC_EC2_DNS_NAME in $(get_ec2_targets)
do
  printf "${PAGE_LINE}\n" "${PUBLIC_EC2_DNS_NAME}" >> ${PAGE_FILE_NAME}
done

cat <<EOF >> ${PAGE_FILE_NAME}
</body>
</html>
EOF
}

function refresh_page() {
  sleep 1
  while true
  curl -sq ${PUBLIC_ALB_DNS_NAME} > ${PUBLIC_ALB_DNS_NAME}.html
  do
    for PUBLIC_EC2_DNS_NAME in $(get_ec2_targets)
    do
        curl -sq ${PUBLIC_EC2_DNS_NAME}:8080 > ${PUBLIC_EC2_DNS_NAME}.html
    done
    sleep ${REFRESH_INTERVAL}
  done
}

function open_page() {
  open -a "Google Chrome" ${PAGE_FILE_NAME}
}

create_page
open_page &
refresh_page