repo := "https://github.com/pbonh/ars-linux.git"

default:
    @just --list

sync:
    sudo ansible-pull -U {{repo}} -i inventory/hosts system.yml

sync-user:
    ansible-pull -U {{repo}} -i inventory/hosts user.yml

sync-flatpaks:
    sudo ansible-pull -U {{repo}} -i inventory/hosts system.yml --tags flatpaks

sync-tags TAGS:
    sudo ansible-pull -U {{repo}} -i inventory/hosts system.yml --tags {{TAGS}}

lint:
    yamllint .
    ansible-lint roles/ system.yml user.yml

test:
    pytest

vm-test BRANCH="main":
    @echo "Boot a Zirconium ISO in quickemu, then inside the guest:"
    @echo "  sudo dnf install -y ansible-core git"
    @echo "  sudo ansible-pull -U {{repo}} --checkout {{BRANCH}} -i inventory/hosts system.yml"
