locals {
  cluster_dns_ip = "${cidrhost(var.kube_service_cidr, 10)}"
}

module "ignition_docker" {
  source = "../ignitions/docker"
}

module "ignition_locksmithd" {
  source          = "../ignitions/locksmithd"
  reboot_strategy = "${var.reboot_strategy}"
}

module "ignition_kube_config" {
  source = "../ignitions/kube-config"

  name                = "${var.name}"
  api_server_endpoint = "https://${aws_elb.master_internal.dns_name}"

  kube_certs = {
    ca_cert_pem      = "${module.kube_root_ca.cert_pem}"
    kubelet_key_pem  = "${module.kube_kubelet_cert.private_key_pem}"
    kubelet_cert_pem = "${module.kube_kubelet_cert.cert_pem}"
  }
}

data "ignition_config" "main" {
  files = ["${compact(concat(
    module.ignition_docker.files,
    module.ignition_node_exporter.files,
    module.ignition_locksmithd.files,
    module.ignition_kube_control_plane.files,
    module.ignition_kubelet.files,
    module.ignition_kube_config.files,
    module.ignition_kube_addon_flannel_vxlan.files,
    module.ignition_kube_addon_dns.files,
    module.ignition_kube_addon_proxy.files,
    module.ignition_kube_addon_manager.files,
    var.extra_ignition_file_ids,
  ))}"]

  systemd = ["${compact(concat(
    module.ignition_docker.systemd_units,
    module.ignition_node_exporter.systemd_units,
    module.ignition_locksmithd.systemd_units,
    module.ignition_kube_control_plane.systemd_units,
    module.ignition_kubelet.systemd_units,
    module.ignition_kube_config.systemd_units,
    module.ignition_kube_addon_flannel_vxlan.systemd_units,
    module.ignition_kube_addon_dns.systemd_units,
    module.ignition_kube_addon_proxy.systemd_units,
    module.ignition_kube_addon_manager.systemd_units,
    var.extra_ignition_systemd_unit_ids,
  ))}"]
}

resource "aws_s3_bucket_object" "ignition" {
  bucket  = "${var.s3_bucket}"
  key     = "ign-master-${var.name}.json"
  content = "${data.ignition_config.main.rendered}"
  acl     = "private"

  server_side_encryption = "AES256"

  tags = "${merge(map(
      "Name", "ign-master-${var.name}.json",
      "Role", "master",
      "kubernetes.io/cluster/${var.name}", "owned",
    ), var.extra_tags)}"
}

data "ignition_config" "s3" {
  replace {
    source       = "${format("s3://%s/%s", var.s3_bucket, aws_s3_bucket_object.ignition.key)}"
    verification = "sha512-${sha512(data.ignition_config.main.rendered)}"
  }
}
