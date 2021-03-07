#1.Create AZs 
data "aws_availability_zones" "available" {
  state = "available"
}
data "aws_availability_zones" "all" {}


#2.Create a VPC
resource "aws_vpc" "vpc" {
  cidr_block           = "172.17.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "first_vpc"

  }
}

#3.Create private subnets for RDC. in each different AZ
resource "aws_subnet" "DB_subnet_private" {
  count             = var.az_count
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "DB_subnet_private #${count.index}"
  }
}

#4.Create public subnets for EC2 each in different AZ.
resource "aws_subnet" "app_server" {
  count                   = var.az_count
  cidr_block              = cidrsubnet(aws_vpc.vpc.cidr_block, 8, var.az_count + count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = true

  tags = {
    Name = "EC2_public #${var.az_count + count.index}"
  }
}

#5.Create an Internet Gateway for public subnet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    "Name" = "IG_Public"
  }
}

#6.Route the public subnet traffic through the IGW
resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.vpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

#7. Create ALB
resource "aws_lb" "app_alb" {
  name               = "EC-app-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.app_server.*.id
  security_groups    = [aws_security_group.IG_to_ALB.id]

}

#8. Create the ALB target group for ECS
resource "aws_lb_target_group" "app_alb" {
  name        = "EC-app-alb"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id
  target_type = "ip"

  health_check {
    path    = "/healthz"
    matcher = "200"
  }
}

#9.Create the ALB listener
# resource "aws_alb_listener" "app_alb" {
#   load_balancer_arn = aws_lb.app_alb.id
#   port              = "443"
#   protocol          = "HTTPS"
#   certificate_arn   = "arn:aws:acm:us-east-2:416290965744:certificate/72fa8753-d7fd-4a46-bcaf-01a52560fd9c"

#   default_action {
#     target_group_arn = aws_lb_target_group.app_alb.arn
#     type             = "forward"
#   }
# }

resource "aws_lb_listener" "app_alb" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}


#10.Create Route 53 record to point to the ALB
# resource "aws_route53_record" "app_alb" {
#   zone_id = data.aws_route53_zone.app_alb.zone_id
#   name    = "EC2_Domain_Name"
#   type    = "A"

#   alias {
#     name                   = aws_alb.app_alb.dns_name
#     zone_id                = aws_alb.app_alb.zone_id
#     evaluate_target_health = true
#   }
# }


#11.create security groups from IG to ALB

resource "aws_security_group" "IG_to_ALB" {
  name        = "IG_to_ALB"
  description = "Allow access on port 443 only to ALB"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#create SG from ALB to front server
resource "aws_security_group" "alb_to_server" {
  name        = "alb_to_server"
  description = "allow inbound access from the ALB only"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    protocol        = "tcp"
    from_port       = "8080"
    to_port         = "8080"
    security_groups = [aws_security_group.IG_to_ALB.id]
  }
  ingress {
    protocol        = "tcp"
    from_port       = "443"
    to_port         = "443"
    security_groups = [aws_security_group.IG_to_ALB.id]
  }
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#create SG from server to RDS DB.
resource "aws_security_group" "server_to_RDS" {
  name        = "server_to_RDS"
  description = "allow inbound access from the server"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    protocol        = "tcp"
    from_port       = "3306"
    to_port         = "3306"
    security_groups = [aws_security_group.alb_to_server.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}


#create front end in public subnet
resource "aws_instance" "my_instance" {
  count                  = var.az_count
  ami                    = "ami-0b7d7a0004178e677"
  instance_type          = "t2.micro"
  availability_zone      = data.aws_availability_zones.available.names[count.index]
  vpc_security_group_ids = [aws_security_group.alb_to_server.id]
  subnet_id              = aws_subnet.app_server.*.id[count.index]
  key_name               = "tes_key"

  user_data = <<-EOF

               #! /bin/bash

               sudo yum install httpd -y

               sudo systemctl start httpd

               sudo systemctl enable httpd

               echo "<h1>Sample Webserver" | sudo tee /var/www/html/index.html

 EOF

  tags = {
    Name = "my-instance-${count.index + 1}"
  }
}

resource "aws_ebs_volume" "test_ebs" {
  count             = 2
  availability_zone = data.aws_availability_zones.available.names[count.index]
  size              = 1
  type              = "gp2"
}

resource "aws_volume_attachment" "my-vol-attach" {
  count        = 2
  device_name  = "/dev/var/log"
  instance_id  = aws_instance.my_instance.*.id[count.index]
  volume_id    = aws_ebs_volume.test_ebs.*.id[count.index]
  force_detach = true
}

#Create RDS DB
resource "aws_db_subnet_group" "db_sg" {
  name       = "db_sg"
  subnet_ids = aws_subnet.DB_subnet_private.*.id
}

resource "aws_db_instance" "rds_db" {
  instance_class          = "db.t2.micro"
  allocated_storage       = 20
  name                    = "test_rds_db"
  engine                  = "mysql"
  multi_az                = true
  storage_type            = "gp2"
  port                    = "3006"
  username                = var.username
  password                = var.password
  apply_immediately       = true
  backup_retention_period = 2
  db_subnet_group_name    = aws_db_subnet_group.db_sg.name
  publicly_accessible     = false
  engine_version          = "5.7"
  vpc_security_group_ids  = [aws_security_group.server_to_RDS.id]
  skip_final_snapshot     = true
}



#create autoscaling group for public and private subnet.
resource "aws_launch_configuration" "launch_config" {
  image_id        = "ami-03d64741867e7bb94"
  
  instance_type   = "t2.micro"
  security_groups = [aws_db_subnet_group.db_sg.name, aws_security_group.IG_to_ALB.id, aws_security_group.alb_to_server.id, aws_security_group.server_to_RDS.id]
  key_name        = var.keyName
  user_data       = <<-EOF
              #!/bin/bash
              yum -y install httpd
              echo "Hey there! your autoscaling has started" > /var/www/html/index.html
              service httpd start
              chkconfig httpd on
              EOF

  lifecycle {
    create_before_destroy = true
  }
}

## Creating AutoScaling Group
resource "aws_autoscaling_group" "example" {
  count                = var.az_count
  launch_configuration = aws_launch_configuration.launch_config.name
  availability_zones   = data.aws_availability_zones.all.names
  min_size             = 2
  max_size             = 10
  #load_balancers       = aws_elb.asg-elb.name
  health_check_type = "ELB"
  tag {
    key                 = "Name"
    value               = "asg-example"
    propagate_at_launch = true
  }
}
## Security Group for ELB
resource "aws_security_group" "elb" {
  name = "terraform-example-elb"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
### Creating ELB
resource "aws_elb" "asg-elb" {
  count              = var.az_count
  name               = "asg-elb"
  security_groups    = [aws_security_group.elb.id]
  availability_zones = data.aws_availability_zones.all.names
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    target              = "HTTP:8080/"
  }
  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = "8080"
    instance_protocol = "http"
  }
}



#create cloud watch to alarm

resource "aws_sns_topic" "sns_topic" {
  name = "sns_topic"

  delivery_policy = <<EOF
{
  "http": {
    "defaultHealthyRetryPolicy": {
      "minDelayTarget": 20,
      "maxDelayTarget": 20,
      "numRetries": 3,
      "numMaxDelayRetries": 0,
      "numNoDelayRetries": 0,
      "numMinDelayRetries": 0,
      "backoffFunction": "linear"
    },
    "disableSubscriptionOverrides": false,
    "defaultThrottlePolicy": {
      "maxReceivesPerSecond": 1
    }
  }
}
EOF

  provisioner "local-exec" {
    command = "aws sns subscribe --topic-arn ${self.arn} --protocol email --notification-endpoint ${var.alarms_email}"
  }
}

resource "aws_sns_topic" "default" {
  name_prefix = "rds-threshold-alerts"
}

resource "aws_db_event_subscription" "DB_alerts" {
  name_prefix = "rds-event"
  sns_topic   = aws_sns_topic.default.arn

  source_type = "db_instance"
  source_ids  = [aws_db_instance.rds_db.id]

  event_categories = ["failover", "failure", "low storage", "maintenance", "notification", "recovery"]

  depends_on = [aws_sns_topic_policy.default]
}

resource "aws_sns_topic_policy" "default" {
  arn    = aws_sns_topic.default.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}
data "aws_caller_identity" "default" {}

# data "aws_iam_policy_document" "sns_topic_policy" {
#   policy_id = "__default_policy_ID"

#   statement {
#     sid = "__default_statement_ID"

#     actions = [
#       "SNS:Subscribe",
#       "SNS:SetTopicAttributes",
#       "SNS:RemovePermission",
#       "SNS:Receive",
#       "SNS:Publish",
#       "SNS:ListSubscriptionsByTopic",
#       "SNS:GetTopicAttributes",
#       "SNS:DeleteTopic",
#       "SNS:AddPermission",
#     ]

#     effect    = "Allow"
#     resources = ["${aws_sns_topic.default.arn}"]

#     principals {
#       type        = "AWS"
#       identifiers = ["*"]
#     }

#     condition {
#       test     = "StringEquals"
#       variable = "AWS:SourceOwner"

#       values = [
#         "${data.aws_caller_identity.default.account_id}",
#       ]
#     }
#   }

#   statement {
#     sid       = "Allow CloudwatchEvents"
#     actions   = ["sns:Publish"]
#     resources = ["${aws_sns_topic.default.arn}"]

#     principals {
#       type        = "Service"
#       identifiers = ["events.amazonaws.com"]
#     }
#   }

#   statement {
#     sid       = "Allow RDS Event Notification"
#     actions   = ["sns:Publish"]
#     resources = ["${aws_sns_topic.default.arn}"]

#     principals {
#       type        = "Service"
#       identifiers = ["rds.amazonaws.com"]
#     }
#   }
# }

locals {
  thresholds = {
    CPUUtilizationThreshold = "${min(max(var.cpu_utilization_threshold, 0), 100)}"
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_utilization_too_high" {
  alarm_name          = "cpu_utilization_too_high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "600"
  statistic           = "Average"
  threshold           = local.thresholds["CPUUtilizationThreshold"]
  alarm_description   = "Average database CPU utilization over last 10 minutes too high"
  alarm_actions       = ["${aws_sns_topic.default.arn}"]
  ok_actions          = ["${aws_sns_topic.default.arn}"]

  dimensions = {
    DBInstanceIdentifier = "${aws_db_instance.rds_db.id}"
  }
}
