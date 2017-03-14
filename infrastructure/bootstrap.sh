#!/bin/sh

STACK_NAME="lambda-pipeline"
TEMPLATE_URL="file://pipeline.yml"

aws cloudformation create-stack --stack-name $STACK_NAME --template-body $TEMPLATE_URL --capabilities CAPABILITY_IAM
aws cloudformation wait stack-create-complete --stack-name $STACK_NAME
aws cloudformation describe-stacks --stack-name $STACK_NAME
