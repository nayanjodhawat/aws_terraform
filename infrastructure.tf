provider "aws" {
  region  = "us-east-1"
  profile = "default"
}


resource "aws_security_group" "first-sc"{
  name = "first-sc"
  description = "Allow Port 80"


  ingress{
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress{
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress{
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "sc-group-first-tf"
  }
}




resource "aws_instance" "first-os" {
  ami           = "ami-0affd4508a5d2481b"
  instance_type = "t2.micro"
  key_name      = "ec2-demo"
  security_groups = ["${aws_security_group.first-sc.name}"]




  connection {
    type = "ssh"
    user = "centos"
    private_key = file("/home/Jodhawat/terra1/ec2-demo.pem")
    host = aws_instance.first-os.public_ip
  }


  provisioner "remote-exec"{
    inline = ["sudo yum install httpd git -y"," sudo systemctl enable httpd",
	"sudo systemctl start httpd"]
  }
}




resource "aws_ebs_volume" "first-volume"{
  availability_zone = aws_instance.first-os.availability_zone
  size = 2
  tags = {
    Name = "First Volume"
  }
}




resource "aws_volume_attachment" "first-ebs"{
  device_name = "/dev/sdb"
  volume_id = "${aws_ebs_volume.first-volume.id}"
  instance_id = "${aws_instance.first-os.id}"
  force_detach = true
}




resource "null_resource" "null_rc2"{
depends_on =  [aws_volume_attachment.first-ebs]


  connection {
    type = "ssh"
    user = "centos"
    private_key = file("/home/Jodhawat/terra1/ec2-demo.pem")
    host = aws_instance.first-os.public_ip
  }


  provisioner "remote-exec"{
    inline = ["sudo mkfs.ext4 /dev/xvdb","sudo rm -rf /var/www/html",
	"sudo mount /dev/xvdb /var/www/html",
	"sudo git clone https://github.com/nayanjodhawat/Project.git /var/www/html"]
  }
}




resource "aws_s3_bucket" "first-bucket"{
  bucket = "random100100"
  acl = "public-read"
  force_destroy = true


  provisioner "local-exec" {
    command = "sudo git clone https://github.com/nayanjodhawat/project2.git test"
  }
  provisioner "local-exec"{
    when = destroy
    command = "sudo rm -rf test"
  }
}




resource "aws_s3_bucket_object" "first-bucket-object"{
  key = "nayan.jpg"
  bucket = aws_s3_bucket.first-bucket.id
  source = "test/nayan.jpg"
  content_type = "images/jpg"
  acl = "public-read"
  depends_on =  [aws_s3_bucket.first-bucket]
}


locals {
  s3_origin_id = "first-bucket-origin"
}




resource "aws_cloudfront_distribution" "first-s3-cf" {
  origin {
    domain_name = "${aws_s3_bucket.first-bucket.bucket_regional_domain_name}"
    origin_id   = "${local.s3_origin_id}"
  }
  enabled = true


  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"


    forwarded_values {
      query_string = false


      cookies {
        forward = "none"
      }
    }
  viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }


  viewer_certificate {
    cloudfront_default_certificate = true
  }


  connection {
    type = "ssh"
    user = "centos"
    private_key = file("/home/Jodhawat/terra1/ec2-demo.pem")
    host = aws_instance.first-os.public_ip
  }
  provisioner "remote-exec"{
    inline = ["sudo -i <<EOF",
	"echo \"<img src='http://${self.domain_name}/${aws_s3_bucket_object.first-bucket-object.key}' width='336' height='448'>\" >> /var/www/html/index.html","EOF",]
  }
}
