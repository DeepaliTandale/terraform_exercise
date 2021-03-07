variable "region" {
  default = "us-east-1"

}
variable "aws_access_key" {
 
}
variable "aws_secret_key" {
  
}
variable "ENV" {
  default = "DEV"
}
# variable "public_key_path" {}
# variable "private_key_path" {}

variable "aws_instance_name" {
  default = "ami-042e8287309f5df03"
}

variable "aws_instance_type" {
  default = "t2.micro"
}

variable "vpc-cidr" {
  default = "10.0.0.0/16"
}
variable "subnet-cidr-public" {
  #type    = list(string)
  #default = ["10.0.32.0/24", "10.0.48.0/24"]
  default = "10.0.32.0/24"
}
variable "subnet-cidr-private" {
  # type    = list(string)
  # default = ["10.0.64.0/24", "10.0.80.0/24"]
  default = "10.0.64.0/24"
}
variable "key_Name" {
  default = "test_06March21"
}
variable "subnet-cidr-public_1" {
  default = "10.0.48.0/24"
}
variable "subnet-cidr-private_1" {
  default = "10.0.80.0/24"
}
variable "subnet-cidr_3" {
  default = "10.0.96.0/24"
}
variable "subnet-cidr_4" {
  default = "10.0.112.0/24"
}
variable "subnet-cidr_5" {
  default = "10.0.128.0/24"
}

variable "az_count" {
  description = "How many AZ's to create in the VPC"
  default     = 2
}
variable "subnets" {

  default = 2
}

variable "alarms_email" {
  default = "tandaledeepali99@gmail.com"
}


variable "cpu_utilization_threshold" {
  description = "The maximum percentage of CPU utilization."
  type        = string
  default     = 80
}
variable "username" {
  default = "admin"
}
variable "password" {
  default = "admin123"
}

# variable "domain" {
#   description = "Domain name. Service will be deployed using the hasura_subdomain"
# }


# variable "target_group_arns" {
#   type        = list(string)
#   description = "A list of aws_alb_target_group ARNs, for use with Application Load Balancing"
#   default     = []
# }

variable "keyName" {
  
}




