packer {
  required_plugins {
    qemu = {
      version = "~> 1.1"
      source  = "github.com/hashicorp/qemu"
    }

    sshkey = {
      version = "~> 1.1"
      source  = "github.com/ivoronin/sshkey"
    }
  }
}

locals {
  guest_username = "cloud-user"
  guest_password = "password"
}

source "qemu" "ubuntu_26" {
  disk_size    = "5G"
  machine_type = "q35"
  memory       = 4096
  cpu_model    = "host"
  cpus         = 2

  # CD configuration

  cd_content = {
    "meta-data" = templatefile("${path.root}/templates/meta-data.pkrtpl.hcl", {
    })
    "user-data" = templatefile("${path.root}/templates/user-data.pkrtpl.hcl", {
      username              = local.guest_username
      password              = local.guest_password
      guest_timezone        = var.guest_timezone
      guest_locale          = var.guest_locale
    })
  }
  cd_label = "CIDATA"

  # Shutdown configuration

  shutdown_command = "echo ${local.guest_password} | sudo -S bash $XDG_RUNTIME_DIR/shutdown.sh"

  # Communicator configuration

  communicator = "ssh"
  ssh_username = local.guest_username
  ssh_password = local.guest_password
  ssh_timeout  = "60m"
}

build {
  source "source.qemu.ubuntu_26" {
    # ISO Configuration
    iso_url      = "https://releases.ubuntu.com/26.04/ubuntu-26.04-live-server-amd64.iso"
    iso_checksum = "file:https://releases.ubuntu.com/26.04/SHA256SUMS"

    # EFI Boot Configuration
    efi_boot = false

    # Boot Configuration
    boot_command = [
      "e<down><down><down><end>",
      " autoinstall 'net.ifnames=0;ds=NoCloud;'",
      "<F10>",
    ]
  }

  provisioner "shell" {
    execute_command = "echo '${local.guest_password}' | sudo -S bash -c '{{ .Vars }} {{ .Path }}'"
    inline_shebang  = "/bin/bash -e"
    inline = [
      "set -o pipefail",
      # The Ubuntu autoinstall process writes Cloud-init config that we don't
      # want to keep, so we need to delete it.
      "rm -rf /var/lib/cloud/*",
      "find /etc/cloud/cloud.cfg.d/ -type f -not -name README -not -name 05_logging.cfg -execdir rm {} \\;",
    ]
  }

  # We want to configure the None datasource to set a password on the default
  # cloud user account so that we can at least log into the console when we
  # manually create a VM from the temaplte.
  provisioner "file" {
    content     = templatefile("${path.root}/templates/datasources.cfg.pkrtpl.hcl", {})
    destination = "$XDG_RUNTIME_DIR/datasources.cfg"
  }

  provisioner "shell" {
    inline_shebang = "/bin/bash -e"
    inline = [
      "set -o pipefail",
      "echo '${local.guest_password}' | sudo -S cp $XDG_RUNTIME_DIR/datasources.cfg /etc/cloud/cloud.cfg.d/datasources.cfg",
    ]
  }

  # Finally, we drop the shutdown script into the XDG_RUNTIME_DIR so that it can
  # clean away accounts in preparation for use as a template, without being
  # included in the final image.
  provisioner "file" {
    source      = "${path.root}/scripts/shutdown.sh"
    destination = "$XDG_RUNTIME_DIR/shutdown.sh"
  }
}
