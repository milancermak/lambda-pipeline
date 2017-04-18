# lambda-pipeline

A continuous delivery pipeline for AWS Lambda, managed by AWS CloudFormation.

### What and why :pencil2:

I [built it](https://milancermak.wordpress.com/2017/03/15/aws-lambda-deployment-pipeline/) to automate a part of my process of developing Alexa skills, hence the AWS Lambda part. However it's easy to transform and extend. You can use it to create a CI/CD pipeline for any piece of your AWS infrastructure.

### How it works :wrench:

Besides a couple of necessary resources, like IAM roles, the core of the system is a combo of CodeCommit (code repository), CodeBuild (building, testing and packaging) and CodePipeline (deployment). It is the CodePipeline that ties it all together, where the magic happens.

The pipeline is defined in a couple of stages.

First stage is the `Source` stage. It listens to any changes made to the CodeCommit repository. A new commit on the `master` branch starts the pipeline.

The next stage, `CreateUpdatePipeline` is responsible for updating the pipeline itself. It takes the output of the `Source` stage as its input artifact and invokes CloudFormation to update itself :sparkles: If there is any updates (e.g. you add or remove a stage), the pipeline is restarted after successfully applying the changeset.

Following the pipeline update stage is the `BuildAndTest` stage. It utilizes CodeBuild to do the work. Whatever is defined in the `buildspec.yml` gets executed. If any of the [buildspec phases](http://docs.aws.amazon.com/codebuild/latest/userguide/build-spec-ref.html) fail, the whole pipeline will stop, yet it will still produce a `BuildOutput` artifact (handy for debugging, you can just download it from S3).

The last step is `CreateUpdateLambda`. It is similar to the second step, however uses a different CloudFormation template to manage the infrastructure. This is where things get a little tricky. I was hoping deploying a Lambda function would be as easy as having this in the pipeline step:
```
ActionTypeId:
  Category: Deploy
  Owner: AWS
  Provider: Lambda
  Version: 1
```
However, CodePipeline doesn't (yet?) support Lambda as a Provider for a Deploy stage. Because of that, the lambda function has to be defined in a separate CFN template (`infrastructure/lambda.yml`). This stage uses that template as its deployment target. It uses the [`ParameterOverrides`](http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/continuous-delivery-codepipeline-action-reference.html) to tell the lambda function where its deployment package (i.e. the ZIP file produced by CodeBuild during the `BuildAndTest` stage) is. However, we also need to tell the lambda function also about the `ArtifactsBucket` - that's why it is defined as an Output of the `pipeline.yml` template. These two values are then used in the `lambda.yml`, in the `Code` section of the function.

### Bootstrapping the stack :rocket:

Run the `infrastructure/bootstrap.sh` script. You must have [AWS command line tools](https://aws.amazon.com/cli/) installed and configured.

After successfully creating the stack, the script will print the outputs of the pipeline template, one of which is the `RepositoryURL`. Use that to add a new remote to your git repo: `git remote add aws [RepositoryURL]`. You'll need to [associate an SSH key with your AWS account](http://docs.aws.amazon.com/codecommit/latest/userguide/setting-up.html#setting-up-other). Afterwards, you can `git push aws` any changes of your code. This will get picked up by the pipeline and will trigger the whole build-test-deploy cycle :sparkles:

### Modifying the stack :art:

It's easy to modify the stack to your needs - you can add CodePipeline stages or a database for your Lambda function. Just modify the appropriate CFN templates and push your changes. As mentioned in the How it works section, CloudFormation is awesome in that way, that it recognizes the difference between the deployed infrastructure and the requested one and either creates, modifies or destroys the appropriate resources.

When modifying the templates, it's also easy to get it wrong. Here are some commands that will help you setting stuff up and debugging:

This catches some syntax and semantic errors even before the change is deployed, but it is far from perfect:
```aws cloudformation validate-template --template-body file://pipeline.yml```

To create the stack, use these two commands:
```
aws cloudformation create-stack --stack-name lambda-pipeline --template-body file://pipeline.yml --capabilities CAPABILITY_IAM
aws cloudformation wait stack-create-complete --stack-name lambda-pipeline
```
These are the same two commands the `bootstrap.sh` uses. First one triggers the creation, the second one waits until the stack is created or the creation faild. If you're creating any S3 buckets, set the `DeletionPolicy` to `Delete` instead of `Retain` during this experimentation phase. Once you're happy with your stack, you can change it back.

If the creation did fail, use:
```aws cloudformation describe-stack-events --stack-name lambda-pipeline```
to check what went wrong. Search for `"ResourceStatus": "CREATE_FAILED"` in the output. The error messages are usually fine to help you with debugging the issue.

When you found the culprit, you need to drop the already created resources:
```
aws cloudformation delete-stack --stack-name lambda-pipeline
aws cloudformation wait stack-delete-complete --stack-name lambda-pipeline
```
If the issue is in a dependent stack (due to cross-stack references), you need to drop the other stack first.

Now you can fix the issue in the CFN template and deploy again. :ship:

Also note that my setup is configured for python, but you can easily change it to your language of choice easily - [change](http://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref.html) the `Image` used for the build part, change the handler and runtime in `lambda.yml` and modify `buildspec.yml` to your needs.

You'll probably want to change some other values in the CFN templates as well, just so your Lambda function is not named `my-lambda-function` but something more appropriate for your project :grin:

##### What to change:
 * `PIPELINE_STACK_NAME` parameter in bootstrap.sh - I recommend keeping the same base as `ProjectName` and adding a `-pipeline` suffix
 * Parameters in both CFN templates
