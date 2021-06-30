### Variables defined on var-file
variables {
## Common on vmware-iso and virtualbox-iso
  rhel_mode = ""
  rhel_version = ""
  rhel_architechture = ""
  rhel_media = ""
  iso_checksum = ""
  http_bind_address = ""
  http_directory = ""
  boot_wait = ""
  headless = ""
  guest_os_type = ""
  ssh_username = ""
  ssh_password = ""
  ssh_timeout = ""
  cpus = ""
  core = ""
  memory = ""
  disk_size = ""
  disk_type_id = ""
  network = ""
  sound = ""
  usb = ""
  serial = ""
  parallel = ""
  vmx_remove_ethernet_interfaces = ""
  output_directory = ""
  output_box_directory = ""
  shutdown_command = ""
  post_vmware_compression_level = ""
#boot_command="defined in locals"
## virtualbox-iso specifics
  vb_http_bind_address = ""
  chipset=""
  firmware=""
  nested_virt=""
  rtc_time_base=""
  nic_type=""
  audio_controller=""
  gfx_controller=""
  gfx_vram_size=""
  gfx_accelerate_3d=""
  gfx_efi_resolution=""
  vb_guest_os_type = ""
  hard_drive_discard=""
  hard_drive_interface=""
  sata_port_count=""
  nvme_port_count=""
  hard_drive_nonrotational=""
  iso_interface=""
  bundle_iso=""
  guest_additions_mode=""
  guest_additions_interface=""
  guest_additions_path=""
  guest_additions_sha256=""
  guest_additions_url=""
  format=""
  vbsound =""
  skip_nat_mapping=""
  vb_shutdown_command = ""
  vb_network=""
}

## Local iso_url variable definition
locals {
  iso_url="file:///ISO/rhel-${var.rhel_version}-${var.rhel_architechture}${var.rhel_media}.iso"
  boot_command = [
    "<up><tab> ${var.rhel_mode}",
    " inst.ks=http://${var.http_bind_address}:{{ .HTTPPort }}/kickstart/ks-rhel-${var.rhel_mode}-vmware.cfg<enter> net.ifname=0<wait>"
  ]
  vb_boot_command = [
    "<up><tab> ${var.rhel_mode}",
    " inst.ks=http://${var.vb_http_bind_address}:{{ .HTTPPort }}/kickstart/ks-rhel-${var.rhel_mode}-virtualbox.cfg<enter><wait>"
  ]
  vm_name="rhel-${var.rhel_version}-${var.rhel_architechture}-${var.rhel_mode}"
}

### vmware-iso source
source "vmware-iso" "rhel"{
  vm_name="${local.vm_name}"
  iso_url = "${local.iso_url}"
  iso_checksum = "${var.iso_checksum}"
  ssh_username = "${var.ssh_username}"
  ssh_password = "${var.ssh_password}"
  ssh_timeout = "${var.ssh_timeout}"
  shutdown_command = "nmcli c a con-name ens32 type ethernet; ${var.shutdown_command}"
  boot_command = "${local.boot_command}"
  boot_wait = "${var.boot_wait}"
  http_directory = "${var.http_directory}"
  http_bind_address = "${var.http_bind_address}"
  guest_os_type = "${var.guest_os_type}"
  disk_size="${var.disk_size}"
  disk_type_id="${var.disk_type_id}"
  headless = "${var.headless}"
  cpus = "${var.cpus}"
  memory = "${var.memory}"
  cores = "${var.core}"
  network = "${var.network}"
  sound = "${var.sound}"
  usb = "${var.usb}"
  serial = "${var.serial}"
  parallel = "${var.parallel}"
  vmx_remove_ethernet_interfaces = "${var.vmx_remove_ethernet_interfaces}"
  output_directory = "${var.output_directory}"
  #keep_registered="false"
  #skip_export="false"
}

### virtualbox-iso source
source "virtualbox-iso" "rhel" {
## Common with vmware-iso###
  http_directory = "${var.http_directory}"
  http_bind_address = "${var.vb_http_bind_address}"
  iso_url = "${local.iso_url}"
  iso_checksum = "${var.iso_checksum}"
  ssh_username = "${var.ssh_username}"
  ssh_password = "${var.ssh_password}"
  ssh_timeout = "${var.ssh_timeout}"
  boot_wait = "${var.boot_wait}"
  boot_command = "${local.vb_boot_command}"
  headless = "${var.headless}"
  cpus = "${var.cpus}"
  memory = "${var.memory}"
  disk_size="${var.disk_size}"
  usb = "${var.usb}"
  output_directory = "${var.output_directory}"
  vm_name="${local.vm_name}"
## End common ##

## virtualbox-iso specifics
  shutdown_command="${var.vb_shutdown_command}"
  guest_os_type = "${var.vb_guest_os_type}"
  hard_drive_discard="${var.hard_drive_discard}"
  hard_drive_interface="${var.hard_drive_interface}"
  sata_port_count="${var.sata_port_count}"
  nvme_port_count="${var.nvme_port_count}"
  hard_drive_nonrotational="${var.hard_drive_nonrotational}"
  iso_interface="${var.iso_interface}"
  bundle_iso="${var.bundle_iso}"
  guest_additions_mode="${var.guest_additions_mode}"
  guest_additions_interface="${var.guest_additions_interface}"
  guest_additions_path="${var.guest_additions_path}"
  guest_additions_sha256="${var.guest_additions_sha256}"
  guest_additions_url="${var.guest_additions_url}"
  format="${var.format}"
  sound = "${var.vbsound}"
#--
#  keep_registered="true"
#  skip_export="true"
#  skip_nat_mapping="${var.skip_nat_mapping}"
#  chipset="${var.chipset}"
#--
  vboxmanage=[
    ["modifyvm","{{.Name}}","--memory","${var.memory}"],
    ["modifyvm","{{.Name}}","--cpus","${var.cpus}"],
    ["modifyvm","{{.Name}}","--nic1","${var.vb_network}"],
    ["modifyvm","{{.Name}}","--nictype1","${var.nic_type}"],
    ["modifyvm","{{.Name}}","--audio","none"],
    ["modifyvm","{{.Name}}","--firmware","${var.firmware}"],
    ["modifyvm","{{.Name}}","--graphicscontroller","${var.gfx_controller}"],
    ["modifyvm","{{.Name}}","--vram","${var.gfx_vram_size}"],
    ["modifyvm","{{.Name}}","--rtcuseutc","${var.rtc_time_base}"],
    ["modifyvm","{{.Name}}","--nested-hw-virt","${var.nested_virt}"]
  ]
}

build {
  sources = [
    "sources.vmware-iso.rhel",
    "sources.virtualbox-iso.rhel"
  ]

  provisioner "shell" {
    scripts=[
      "scripts/packer_virtualbox.sh"
     ]
    only=["virtualbox-iso.rhel"]
  }

  provisioner "shell" {
    inline= [ 
      "touch /etc/virtualbox-iso.rhel"
    ]
    only=["virtualbox-iso.rhel"]
  }

  provisioner "shell" {
    inline= [ 
      "touch /etc/vmware-iso.rhel"
    ]
    only=["vmware-iso.rhel"]
  }

  post-processor "vagrant" {
    keep_input_artifact=false
    compression_level="${var.post_vmware_compression_level}"
    output="${var.output_box_directory}/rhel-${var.rhel_version}-${var.rhel_mode}-{{.Provider}}.box"
  }

  post-processor "shell-local" {
    environment_vars = ["BOX_NAME=rhel-${var.rhel_version}-${var.rhel_mode}"]
    execute_command = ["bash","-c","{{.Vars}} {{.Script}}"]
    scripts=["scripts/addbox.sh"]
  }
}

