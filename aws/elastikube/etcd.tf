module "etcd" {
  source = "../../aws/kube-etcd"

  name       = "${var.name}"
  aws_region = "${var.aws_region}"

  ssh_key     = "${var.ssh_key}"
  etcd_config = "${var.etcd_config}"

  subnet_ids = ["${var.subnet_ids}"]
  zone_id    = "${aws_route53_zone.private.zone_id}"
  s3_bucket  = "${aws_s3_bucket.ignition.id}"

  extra_tags = "${var.extra_tags}"
}