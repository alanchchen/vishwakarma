data "aws_subnet" "subnet" {
  id = "${var.subnet_ids[0]}"
}

locals {
  cluster_id = "${aws_autoscaling_group.master.id}"
  vpc_id     = "${data.aws_subnet.subnet.vpc_id}"

  extra_tags_keys   = "${keys(var.extra_tags)}"
  extra_tags_values = "${values(var.extra_tags)}"
}

data "null_data_source" "tags" {
  count = "${length(keys(var.extra_tags))}"

  inputs = {
    key                 = "${local.extra_tags_keys[count.index]}"
    value               = "${local.extra_tags_values[count.index]}"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group" "master" {
  name                 = "${var.name}-master"
  desired_capacity     = "${var.master_config["instance_count"]}"
  max_size             = "${var.master_config["instance_count"] * 3}"
  min_size             = "${var.master_config["instance_count"]}"
  launch_configuration = "${aws_launch_configuration.master.id}"
  vpc_zone_identifier  = ["${var.subnet_ids}"]
  load_balancers       = ["${aws_elb.master_internal.id}"]

  tags = [
    {
      key                 = "Name"
      value               = "${var.name}-master"
      propagate_at_launch = true
    },
    {
      key                 = "kubernetes.io/cluster/${var.name}"
      value               = "owned"
      propagate_at_launch = true
    },
  ]

  tags = ["${data.null_data_source.tags.*.outputs}"]
}

resource "aws_launch_configuration" "master" {
  instance_type = "${var.master_config["ec2_type"]}"
  image_id      = "${data.aws_ami.coreos_ami.image_id}"
  name_prefix   = "${var.name}-master-"

  security_groups = [
    "${var.security_group_ids}",
    "${aws_security_group.master.id}",
  ]

  iam_instance_profile = "${aws_iam_instance_profile.master.id}"
  key_name             = "${var.ssh_key}"

  user_data = "${data.ignition_config.s3.rendered}"

  lifecycle {
    create_before_destroy = true

    # Ignore changes in the AMI which force recreation of the resource. This
    # avoids accidental deletion of nodes whenever a new CoreOS Release comes
    # out.
    ignore_changes = ["image_id"]
  }

  root_block_device {
    volume_type = "${var.master_config["root_volume_type"]}"
    volume_size = "${var.master_config["root_volume_size"]}"
    iops        = "${var.master_config["root_volume_type"] == "io1" ? var.master_config["root_volume_iops"] : var.master_config["root_volume_type"] == "gp2" ? 0 : min(10000, max(100, 3 * var.master_config["root_volume_size"]))}"
  }
}
