#!/bin/sh

PIPELINE_STACK_NAME="my-lambda-project-pipeline"
TEMPLATE_URL="file://pipeline.yml"

aws cloudformation create-stack --stack-name $PIPELINE_STACK_NAME --template-body $TEMPLATE_URL --capabilities CAPABILITY_IAM
aws cloudformation wait stack-create-complete --stack-name $PIPELINE_STACK_NAME
aws cloudformation describe-stacks --stack-name $PIPELINE_STACK_NAME
