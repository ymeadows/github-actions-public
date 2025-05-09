#!/usr/bin/env bash

function usage {
  echo "Usage: ${0} --command=[start|stop] <arguments>"
}

function safety_on {
  set -o errexit -o pipefail -o noclobber -o nounset
}

function safety_off {
  set +o errexit +o pipefail +o noclobber +o nounset
}

function start_vm {
  echo "Starting GCE VM ..."

  RUNNER_TOKEN=$(curl -v --show-error -XPOST \
      -H "authorization: Bearer ${token}" \
      https://api.github.com/repos/${GITHUB_REPOSITORY}/actions/runners/registration-token |\
      jq --exit-status -r .token)
  echo "✅ Successfully got the GitHub Runner registration token"
  echo "::add-mask::${RUNNER_TOKEN}"

  VM_ID="gce-gh-runner-${GITHUB_RUN_ID}-$(od -N4 -vAn -tu4 < /dev/urandom | sed 's/\s*//')"
  labels="${VM_ID}"
  if [ -n $runner_label ]; then
    labels="${VM_ID},$runner_label"
  fi
  service_account_flag=$([[ -z "${runner_service_account}" ]] || echo "--service-account=${runner_service_account}")
  image_project_flag=$([[ -z "${image_project}" ]] || echo "--image-project=${image_project}")
  image_flag=$([[ -z "${image}" ]] || echo "--image=${image}")
  image_family_flag=$([[ -z "${image_family}" ]] || echo "--image-family=${image_family}")
  disk_size_flag=$([[ -z "${disk_size}" ]] || echo "--boot-disk-size=${disk_size}")
  subnet_flag=$([[ -z "${subnet}" ]] || echo "--subnet=${subnet}")
  address_flag=$([[ "${external_network}" == "false" ]] && echo "--no-address" || echo "")
  preemptible_flag=$([[ "${preemptible}" == "true" ]] && echo "--preemptible" || echo "")
  local_ssd_flag=$([[ "${use_ssd}" == "true" ]] && echo "--local-ssd=interface=NVME" || echo "")

  echo "The new GCE VM will be ${VM_ID}"

  startup_script=$(mktemp -t startup-script-XXXXXX.sh)
  echo "#!/bin/bash" >> $startup_script

  if [ -n "$startup_prequel" ]; then
    echo "$startup_prequel" >> $startup_script
  fi

  if [ -n "$local_ssd_flag" ]; then
    cat <<'EOS' >>$startup_script
ssd_dev=$(lsblk | grep nvme | cut -d ' ' -f 1)
mkfs.ext4 -F "/dev/$ssd_dev"
ssd_mountpoint=/home/runner
mkdir -p "$ssh_mountpoint"
mount "/dev/$ssd_dev" "$ssd_mountpoint"
chmod a+rw "$ssd_mountpoint"
EOS
  fi

  if $actions_preinstalled ; then
    echo "✅ Startup script won't install GitHub Actions (pre-installed)"
    echo "cd /actions-runner" >> $startup_script
  else
    echo "✅ Startup script will install GitHub Actions"
    cat <<EOS >>$startup_script
cat /etc/group
addgroup google-sudoers
adduser runner
echo runner >> /etc/at.allow
usermod -aG google-sudoers runner
mkdir /actions-runner
cd /actions-runner
curl -o actions-runner-linux-x64-${runner_ver}.tar.gz -L https://github.com/actions/runner/releases/download/v${runner_ver}/actions-runner-linux-x64-${runner_ver}.tar.gz
tar xzf ./actions-runner-linux-x64-${runner_ver}.tar.gz
./bin/installdependencies.sh
EOS
  fi

  cat <<'EOSD' >>$startup_script
NAME=$(curl -S -s -X GET http://metadata.google.internal/computeMetadata/v1/instance/name -H 'Metadata-Flavor: Google')
ZONE=$(curl -S -s -X GET http://metadata.google.internal/computeMetadata/v1/instance/zone -H 'Metadata-Flavor: Google')
echo "echo $(which gcloud) --quiet compute instances delete $NAME --zone=$ZONE | at now + 2 minutes" >> /shutdown-vm.sh
echo "atq" >> /shutdown-vm.sh
echo "ACTIONS_RUNNER_HOOK_JOB_COMPLETED=/shutdown-vm.sh" >> /actions-runner/.env
EOSD
  cat <<EOS >>$startup_script
chown runner -RL /actions-runner
gcloud compute instances add-labels ${VM_ID} --zone=${machine_zone} --labels=gh_ready=0 && \\
su runner -c "./config.sh --url https://github.com/${GITHUB_REPOSITORY} --token ${RUNNER_TOKEN} --labels ${labels} --unattended --ephemeral --disableupdate" && \\
ls /home
cat /etc/passwd
./svc.sh install runner && \\
./svc.sh start && \\
rm -rf _diag _work && \\
gcloud compute instances add-labels ${VM_ID} --zone=${machine_zone} --labels=gh_ready=1
# 3 days represents the max workflow runtime. This will shutdown the instance if everything else fails.
echo \"gcloud --quiet compute instances delete ${VM_ID} --zone=${machine_zone}\" | at now + 3 days
EOS

  cat $startup_script
  echo

  gcloud compute instances create ${VM_ID} \
    --zone=${machine_zone} \
    ${disk_size_flag} \
    ${subnet_flag} \
    ${address_flag} \
    --machine-type=${machine_type} \
    --scopes=${scopes} \
    ${service_account_flag} \
    ${image_project_flag} \
    ${image_flag} \
    ${image_family_flag} \
    ${preemptible_flag} \
    ${local_ssd_flag} \
    --labels=gh_ready=0,vanta-description=kubernetes-cluster-node,vanta-owner=judson_dot_lester \
    --metadata-from-file=startup-script="$startup_script"
  echo "::set-output name=label::${VM_ID}"

  safety_off
  while (( i++ < 120 )); do
    GH_READY=$(gcloud compute instances describe ${VM_ID} --zone=${machine_zone} --format='json(labels)' | jq -r .labels.gh_ready)
    if [[ $GH_READY == 1 ]]; then
      break
    fi
    echo "${VM_ID} not ready yet, waiting 5 secs ..."
    sleep 5
  done
  if [[ $GH_READY == 1 ]]; then
    echo "✅ ${VM_ID} ready ..."
  else
    echo "Waited 2 minutes for ${VM_ID}, without luck, deleting ${VM_ID} ..."
    gcloud --quiet compute instances delete ${VM_ID} --zone=${machine_zone}
    exit 1
  fi
}

function stop_vm {
  # NOTE: this function runs on the GCE VM
  echo "Stopping GCE VM ..."
  # NOTE: it would be nice to gracefully shut down the runner, but we actually don't need
  #       to do that. We unconditionally register an ephemeral runner, so it will only ever get one job.
  if [ -n $token ]; then
    safety_off
    DEREG_TOKEN=$(curl -S -s -XPOST \
        -H "authorization: Bearer ${token}" \
        https://api.github.com/repos/${GITHUB_REPOSITORY}/actions/runners/registration-token |\
        jq -r .token)
    echo "::add-mask::${DEREG_TOKEN}"
    echo "✅ Successfully got the GitHub Runner deregistration token"
    sudo /actions-runner/svc.sh stop
    sudo /actions-runner/svc.sh uninstall
    RUNNER_ALLOW_RUNASROOT=1 /actions-runner/config.sh remove --token $DEREG_TOKEN
    safety_on
  fi
  NAME=$(curl -S -s -X GET http://metadata.google.internal/computeMetadata/v1/instance/name -H 'Metadata-Flavor: Google')
  ZONE=$(curl -S -s -X GET http://metadata.google.internal/computeMetadata/v1/instance/zone -H 'Metadata-Flavor: Google')
  echo "✅ Self deleting $NAME in $ZONE in ${shutdown_timeout} seconds ..."
  echo "sleep 30; $(which gcloud) --quiet compute instances delete $NAME --zone=$ZONE" | env at now
  at -l
}

function boot_logs {
  # NOTE: this function runs on the GCE VM
  echo "Capturing boot logs"
  NAME=$(curl -S -s -X GET http://metadata.google.internal/computeMetadata/v1/instance/name -H 'Metadata-Flavor: Google')
  ZONE=$(curl -S -s -X GET http://metadata.google.internal/computeMetadata/v1/instance/zone -H 'Metadata-Flavor: Google')
  gcloud compute instances get-serial-port-output $NAME --zone=$ZONE
}

echo "::add-mask::${token}"
set -x
ACTION_DIR="$( cd $( dirname "${BASH_SOURCE[0]}" ) >/dev/null 2>&1 && pwd )"
cat "${BASH_SOURCE[0]}"

safety_on
case "$command" in
  start)
    start_vm
    ;;
  stop)
    stop_vm
    ;;
  boot_logs)
    boot_logs
    ;;
  *)
    echo "Invalid command: \`${command}\`, valid values: start|stop" >&2
    usage
    exit 1
    ;;
esac
