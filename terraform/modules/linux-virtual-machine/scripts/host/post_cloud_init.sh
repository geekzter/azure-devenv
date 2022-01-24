#!/usr/bin/env bash

# Wait for Cloud Init to complete
/usr/bin/cloud-init status --long --wait
systemctl status cloud-final.service --full --no-pager --wait

# # Remove Log Analytics if installed on the VM image, so we can install our own instead
# if [ -f /opt/microsoft/omsagent/bin/omsadmin.sh  ]; then
#     # https://docs.microsoft.com/en-us/azure/azure-monitor/agents/agent-manage#linux-agent
#     echo $'\nUnregistering Log Analytics workspace...'
#     /opt/microsoft/omsagent/bin/omsadmin.sh -X
# fi
# if [ -f /opt/microsoft/omsagent/bin/purge_omsagent.sh ]; then
#     echo $'\nRemoving Log Analytics agent present on the image...'
#     sudo sh /opt/microsoft/omsagent/bin/purge_omsagent.sh && sudo rm -rf /opt/microsoft/omsagent
#     # sudo systemctl restart walinuxagent.service && sleep 30
# fi

echo done