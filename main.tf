resource "null_resource" "sync_apt_repos" {
  provisioner "local-exec" {
    command = "sudo apt-get update && sudo apt-get -y upgrade"
  }
}

resource "null_resource" "install_htop" {
  provisioner "local-exec" {
    command = "sudo apt-get install -y htop"
  }
  depends_on = [null_resource.sync_apt_repos]
}

resource "null_resource" "install_curl" {
  provisioner "local-exec" {
    command = "sudo apt install -y curl"
  }
  depends_on = [null_resource.install_htop]
}

resource "null_resource" "install_gparted" {
  provisioner "local-exec" {
    command = "sudo apt install -y gparted"
  }
  depends_on = [null_resource.install_curl]
}

resource "null_resource" "install_tmate" {
  provisioner "local-exec" {
    command = "sudo apt install -y tmate"
  }
  depends_on = [null_resource.install_gparted]
}

resource "null_resource" "install_vim" {
  provisioner "local-exec" {
    command = "sudo apt install -y vim"
  }
  depends_on = [null_resource.install_tmate]
}

resource "null_resource" "install_pwgen" {
  provisioner "local-exec" {
    command = "sudo apt install -y pwgen"
  }
  depends_on = [null_resource.install_vim]
}

resource "null_resource" "install_kubectl" {
  provisioner "local-exec" {
    command = <<-EOT
      curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
      chmod +x kubectl
      sudo mv kubectl /usr/local/bin/
    EOT
  }
  depends_on = [null_resource.install_pwgen]
}

resource "null_resource" "write_username_to_file" {
  provisioner "local-exec" {
    command = "whoami > /tmp/current_user.txt"
  }
}


resource "null_resource" "install_docker" {
  provisioner "local-exec" {
    command = <<-EOT
      sudo apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
      sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
      sudo apt-get install -y docker-ce docker-ce-cli containerd.io
      sudo usermod -aG docker $(cat /tmp/current_user.txt)
    EOT
  }
  depends_on = [null_resource.write_username_to_file,null_resource.install_kubectl]
}

resource "null_resource" "openssh-server" {
  provisioner "local-exec" {
    command = "sudo apt install -y openssh-server"
  }
  depends_on = [null_resource.install_docker]
}

resource "null_resource" "install_kind" {
  provisioner "local-exec" {
    command = <<-EOT
      curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.12.0/kind-linux-amd64
      chmod +x ./kind
      sudo mv ./kind /usr/local/bin/kind
    EOT
  }
  depends_on = [null_resource.openssh-server]
}

resource "null_resource" "install_coder" {
  provisioner "local-exec" {
    command = <<EOT
      mkdir -p ~/.cache/coder &&
      curl -#fL -o ~/.cache/coder/coder_0.17.4_amd64.deb.incomplete -C - https://github.com/coder/coder/releases/download/v0.17.4/coder_0.17.4_linux_amd64.deb &&
      mv ~/.cache/coder/coder_0.17.4_amd64.deb.incomplete ~/.cache/coder/coder_0.17.4_amd64.deb &&
      sudo dpkg --force-confdef --force-confold -i ~/.cache/coder/coder_0.17.4_amd64.deb
    EOT
  }
  depends_on = [null_resource.install_kind, null_resource.install_docker]
}

resource "null_resource" "virtualbox_installation" {
  provisioner "local-exec" {
    command = "sudo apt-get update && sudo apt-get install -y virtualbox"
  }
  depends_on = [null_resource.install_coder]
}

resource "null_resource" "emacs_broadway_installation" {
   provisioner "local-exec" {
    command = "sudo apt-get update && sudo apt-get install -y emacs libgtk-3-0 xvfb && Xvfb :0 -screen 0 1024x768x24 & DISPLAY=:0 emacs --fg-daemon=broadway -f server-start && echo 'Emacs with Broadway support installed successfully.'"
   }
  depends_on = [null_resource.virtualbox_installation]
}

resource "null_resource" "tmux-ttyd-wiregaurd" {
  provisioner "local-exec" {
    command = <<EOT
      sudo apt-get install -y tmux ttyd wireguard-tools
      GO_VERSION=1.20.2
      curl -sSL https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz | sudo tar --directory /usr/local --extract --ungzip
      export PATH=~/go/bin:/usr/local/go/bin:$PATH
      go install github.com/coder/wgtunnel/cmd/tunnel@v0.1.5
    EOT
  }
  depends_on = [null_resource.emacs_broadway_installation]
}

resource "local_file" "tunnel-tmux.sh" {
  filename = "/home/test/tunnel-test.sh"
  content  = <<-EOT
   tmux -L ii new -d
   ttyd -p 7681 tmux -L ii at 2&>1 >> /home/test/tunnel-test.log &
   export TUNNEL_WIREGUARD_KEY=$(wg genkey)
   export TUNNEL_API_URL=https://try.ii.nz
   tunnel localhost:54321
  EOT
  perms    = "0755"
}
