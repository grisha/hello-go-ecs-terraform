
variable "environ" {default = "UNKNOWN" }
variable "appname" {default = "HelloGoEcsTerraform" }
variable "host_port" { default = 8080 }
variable "docker_port" { default = 8080 }
variable "lb_port" { default = 80 }
variable "aws_region" { default = "us-east-1" }
variable "key_name" {}
variable "dockerimg" {}

# From https://github.com/aws/amazon-ecs-cli/blob/d566823dc716a83cf97bf93490f6e5c3c757a98a/ecs-cli/modules/config/ami/ami.go#L31
variable "ami" {
  description = "AWS ECS AMI id"
  default = {
    us-east-1 = "ami-67a3a90d"
    us-west-1 = "ami-b7d5a8d7"
    us-west-2 = "ami-c7a451a7"
    eu-west-1 = "ami-9c9819ef"
    eu-central-1 =  "ami-9aeb0af5"
    ap-northeast-1 = "ami-7e4a5b10"
    ap-southeast-1 = "ami-be63a9dd"
    ap-southeast-2 = "ami-b8cbe8db"
  }
}

provider "aws" {
  region = "${var.aws_region}"
}

module "vpc" {
  source = "github.com/terraform-community-modules/tf_aws_vpc"
  name = "${var.appname}-${var.environ}-vpc"
  cidr = "10.100.0.0/16"
  public_subnets  = "10.100.101.0/24,10.100.102.0/24"
  azs = "us-east-1c,us-east-1b"
}

resource "aws_security_group" "allow_all_outbound" {
  name_prefix = "${var.appname}-${var.environ}-${module.vpc.vpc_id}-"
  description = "Allow all outbound traffic"
  vpc_id = "${module.vpc.vpc_id}"

  egress = {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_all_inbound" {
  name_prefix = "${var.appname}-${var.environ}-${module.vpc.vpc_id}-"
  description = "Allow all inbound traffic"
  vpc_id = "${module.vpc.vpc_id}"

  ingress = {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_cluster" {
  name_prefix = "${var.appname}-${var.environ}-${module.vpc.vpc_id}-"
  description = "Allow all traffic within cluster"
  vpc_id = "${module.vpc.vpc_id}"

  ingress = {
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    self = true
  }

  egress = {
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    self = true
  }
}

resource "aws_security_group" "allow_all_ssh" {
  name_prefix = "${var.appname}-${var.environ}-${module.vpc.vpc_id}-"
  description = "Allow all inbound SSH traffic"
  vpc_id = "${module.vpc.vpc_id}"

  ingress = {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# This role has a trust relationship which allows
# to assume the role of ec2
resource "aws_iam_role" "ecs" {
  name = "${var.appname}_ecs_${var.environ}"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOF
}

# This is a policy attachement for the "ecs" role, it provides access
# to the the ECS service.
resource "aws_iam_policy_attachment" "ecs_for_ec2" {
  name = "${var.appname}_${var.environ}"
  roles = ["${aws_iam_role.ecs.id}"]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# This is the role for the load balancer to have access to ECS.
resource "aws_iam_role" "ecs_elb" {
  name = "${var.appname}_ecs_elb_${var.environ}"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "",
        "Effect": "Allow",
        "Principal": {
          "Service": "ecs.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }
  EOF
}

# Attachment for the above IAM role.
resource "aws_iam_policy_attachment" "ecs_elb" {
  name = "${var.appname}_ecs_elb_${var.environ}"
  roles = ["${aws_iam_role.ecs_elb.id}"]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

# The ECS cluster
resource "aws_ecs_cluster" "cluster" {
    name = "${var.appname}_${var.environ}"
}

resource "template_file" "task_definition" {
  depends_on = ["null_resource.docker"]
  template = "${file("task-definition.json.tmpl")}"
  vars {
    name = "${var.appname}_${var.environ}"
    image = "${var.dockerimg}"
    docker_port = "${var.docker_port}"
    host_port = "${var.host_port}"
    # this is so that task is always deployed when the image changes
    _img_id = "${null_resource.docker.id}"
  }
}

resource "aws_ecs_task_definition" "ecs_task" {
  family = "${var.appname}_${var.environ}"
  container_definitions = "${template_file.task_definition.rendered}"
}

resource "aws_elb" "service_elb" {
  name = "${var.appname}-${var.environ}"
  subnets = ["${split(",", module.vpc.public_subnets)}"]
  connection_draining = true
  cross_zone_load_balancing = true
  security_groups = [
    "${aws_security_group.allow_cluster.id}",
    "${aws_security_group.allow_all_inbound.id}",
    "${aws_security_group.allow_all_outbound.id}"
  ]

  listener {
    instance_port = "${var.host_port}"
    instance_protocol = "http"
    lb_port = "${var.lb_port}"
    lb_protocol = "http"
  }

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 10
    target = "HTTP:${var.host_port}/"
    interval = 5
    timeout = 4
  }
}

resource "aws_ecs_service" "ecs_service" {
  name = "${var.appname}_${var.environ}"
  cluster = "${aws_ecs_cluster.cluster.id}"
  task_definition = "${aws_ecs_task_definition.ecs_task.arn}"
  desired_count = 3
  iam_role = "${aws_iam_role.ecs_elb.arn}"
  depends_on = ["aws_iam_policy_attachment.ecs_elb"]
  deployment_minimum_healthy_percent = 50

  load_balancer {
    elb_name = "${aws_elb.service_elb.id}"
    container_name = "${var.appname}_${var.environ}"
    container_port = "${var.docker_port}"
  }
}

resource "template_file" "user_data" {
  template = "ec2_user_data.tmpl"
  vars {
    cluster_name = "${var.appname}_${var.environ}"
  }
}

resource "aws_iam_instance_profile" "ecs" {
  name = "${var.appname}_${var.environ}"
  roles = ["${aws_iam_role.ecs.name}"]
}

resource "aws_launch_configuration" "ecs_cluster" {
  name = "${var.appname}_cluster_conf_${var.environ}"
  instance_type = "t2.micro"
  image_id = "${lookup(var.ami, var.aws_region)}"
  iam_instance_profile = "${aws_iam_instance_profile.ecs.id}"
  associate_public_ip_address = true
  security_groups = [
    "${aws_security_group.allow_all_ssh.id}",
    "${aws_security_group.allow_all_outbound.id}",
    "${aws_security_group.allow_cluster.id}",
  ]
  user_data = "${template_file.user_data.rendered}"
  key_name = "${var.key_name}"
}

resource "aws_autoscaling_group" "ecs_cluster" {
  name = "${var.appname}_${var.environ}"
  vpc_zone_identifier = ["${split(",", module.vpc.public_subnets)}"]
  min_size = 0
  max_size = 3
  desired_capacity = 3
  launch_configuration = "${aws_launch_configuration.ecs_cluster.name}"
  health_check_type = "EC2"
}

resource "null_resource" "docker" {
  triggers {
    # This is a lame hack but it works
    log_hash = "${base64sha256(file("${path.module}/../.git/logs/HEAD"))}"
  }
  provisioner "local-exec" {
    command = "cd .. && docker build -t ${var.dockerimg} . && docker push ${var.dockerimg}"
  }
}
