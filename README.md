
A "Hello World" in Golang deployed to AWS ECS (Docker) using Terraform

Big thanks to [Tadas Vilkeliskis](http://vilkeliskis.com/about/) for
[Bootstrapping Docker Infrastructure With Terraform](http://vilkeliskis.com/blog/2016/02/10/bootstrapping-docker-with-terraform.html)
write up.

# How to use this
1. Make sure you have the following installed and/or created/configured/working:
   * [Docker](http://www.docker.com)
   * [Docker Hub](https://hub.docker.com/) account
   * [Golang](https://golang.org/doc/install)
   * [Terraform](https://www.terraform.io/)
   * [AWS access](https://console.aws.amazon.com/) with admin priviliges and your [AWS CLI](http://docs.aws.amazon.com/cli/latest/userguide/installing.html) is working
   * [AWS Key Pair](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html)

1. Allow Terraform to use your credentials in `~/.aws/config` by symlinking it to `credentials`:

  ```sh
  ln -s ~/.aws/confic ~/.aws/credentials
  ```
1. Install this example:

  ```sh
  go get github.com/grisha/hello-go-ecs-terraform
  ```
1. Change into the project directory:

  ```sh
  cd $GOPATH/src/grisha/hello-go-ecs-terraform
  ```

1. Edit `tf/variables.tf` file so that it has the following:

  ```
  variable "key_name" { default = "YOUR-AWS-KEY-PAIR-NAME" }
  variable "dockerimg" { default = "YOUR-DOCKER-HUB-USERNAME/IMAGE-NAME" }
  ```
1. The docker hub username must be correct (though the actual image doesn not need to exist, it will be created for you), and you should be authenticated with:

  ```sh
  docker login
  ```
1. Check that terraform works with:
  ```sh
  make plan
  ```

1. If the above produces no errors, give it a try. Note that due to timing of AWS object creations sometimes you have to run this twice, it succeeds on the second try:
  ```sh
  make apply
  ```

1. You should now see a load balancer in the AWS console, where it should list its DNS name. You should also see an ECS service and its tasks and associated EC2 instances. The whole thing will take a few minutes to create.

1. Once it's all created, you should be able to hit the ELB DNS name with your browser and see the app in action.

1. In this set up Terraform uses the `.git/logs/HEAD` file as the indicator that code has changed, but this file only changes when you commit something (The idea being that your CI, e.g. Jenkins would actually perform the `make apply`). If you want to force deploy the code that you currently have, you can do this:
   ```sh
   make force_deploy
   ```
   Once you do this, you should see the ECS gradually replace your tasks with the new version.

1. When finished, you can destroy everything with:

  ```sh
  make destroy
  ```
