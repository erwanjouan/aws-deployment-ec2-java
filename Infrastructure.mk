# In-place deployments:
# CodeDeployDefault.AllAtOnce : Attempts to deploy an application revision to as many instances as possible at once. The status of the overall deployment is displayed as Succeeded if the application revision is deployed to one or more of the instances. The status of the overall deployment is displayed as Failed if the application revision is not deployed to any of the instances. Using an example of nine instances, CodeDeployDefault.AllAtOnce attempts to deploy to all nine instances at once. The overall deployment succeeds if deployment to even a single instance is successful. It fails only if deployments to all nine instances fail.
# CodeDeployDefault.HalfAtATime : Deploys to up to half of the instances at a time (with fractions rounded down). The overall deployment succeeds if the application revision is deployed to at least half of the instances (with fractions rounded up). Otherwise, the deployment fails. In the example of nine instances, it deploys to up to four instances at a time. The overall deployment succeeds if deployment to five or more instances succeed. Otherwise, the deployment fails.
# CodeDeployDefault.OneAtATime	: Default method applied. Deploys the application revision to only one instance at a time. For deployment groups that contain more than one instance: The overall deployment succeeds if the application revision is deployed to all of the instances. The exception to this rule is that if deployment to the last instance fails, the overall deployment still succeeds. This is because CodeDeploy allows only one instance at a time to be taken offline with the CodeDeployDefault.OneAtATime configuration. The overall deployment fails as soon as the application revision fails to be deployed to any but the last instance. In an example using nine instances, it deploys to one instance at a time. The overall deployment succeeds if deployment to the first eight instances is successful. The overall deployment fails if deployment to any of the first eight instances fails. For deployment groups that contain only one instance, the overall deployment is successful only if deployment to the single instance is successful.

DeploymentConfigName:=CodeDeployDefault.OneAtATime
ASGMinSize:= 4
ASGMaxSize:= 8

init:
	PROJECT_NAME=$$(./infra/utils/get_mvn_project_name.sh) && \
	PROJECT_VERSION=$$(./infra/utils/get_mvn_project_version.sh) && \
	INIT_BUCKET_NAME=$${PROJECT_NAME}-init && \
	mvn clean && \
	zip -r $${PROJECT_NAME}.zip * && \
	aws s3 mb s3://$${INIT_BUCKET_NAME} &&\
	aws s3 cp $${PROJECT_NAME}.zip s3://$${INIT_BUCKET_NAME}/init/ && \
	aws cloudformation deploy \
		--capabilities CAPABILITY_NAMED_IAM \
		--template-file ./infra/pipeline/init.yml \
		--stack-name $${PROJECT_NAME}-init \
		--parameter-overrides \
			ProjectName=$${PROJECT_NAME} \
			ProjectVersion=$${PROJECT_VERSION} \
			ArtifactInputBucketName=$${INIT_BUCKET_NAME} && \
	aws s3 sync ./infra/pipeline/ s3://$${INIT_BUCKET_NAME}/cloudformation/ && \
	./infra/utils/git_init.sh $${PROJECT_NAME}

deploy:
	PROJECT_NAME=$$(./infra/utils/get_mvn_project_name.sh) && \
	PROJECT_VERSION=$$(./infra/utils/get_mvn_project_version.sh) && \
	INIT_BUCKET_NAME=$${PROJECT_NAME}-init && \
	aws s3 sync ./infra/pipeline/ s3://$${INIT_BUCKET_NAME}/cloudformation/ && \
    aws cloudformation deploy \
		--capabilities CAPABILITY_NAMED_IAM \
		--template-file ./infra/pipeline/_global.yml \
		--stack-name $${PROJECT_NAME}-global \
		--parameter-overrides \
			ProjectName=$${PROJECT_NAME} \
			ProjectVersion=$${PROJECT_VERSION} \
			ArtifactInitBucketName=$${INIT_BUCKET_NAME} \
			DeploymentConfigName=$(DeploymentConfigName) \
			ASGMinSize=$(ASGMinSize) \
			ASGMaxSize=$(ASGMaxSize)

destroy:
	@PROJECT_NAME=$$(./infra/utils/get_mvn_project_name.sh) && \
	INIT_BUCKET_NAME=$${PROJECT_NAME}-init && \
	aws s3 rm s3://$${PROJECT_NAME}-output --recursive || true && \
	aws s3 rm s3://$${INIT_BUCKET_NAME} --recursive || true && \
	aws s3 rb s3://$${INIT_BUCKET_NAME} && \
	aws cloudformation delete-stack --stack-name $${PROJECT_NAME}-global || true && \
	aws cloudformation delete-stack --stack-name $${PROJECT_NAME}-init || true

check:
	cd ./infra/utils/ && ./control_page.sh && cat control_page.html && cd -