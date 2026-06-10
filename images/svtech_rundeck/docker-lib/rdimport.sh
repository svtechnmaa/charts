#!/bin/bash
## script to import rundeck job manually
OVERRIDE_IMPORT_JOB=True
for dir in $(find /opt/SVTECH-Junos-Automation/rundeck-entities/projects/*/ -type d -not -empty); do
    folder=$(basename ${dir})
    mkdir -p /tmp/rundeck_import_job/${folder}
    cp -rf /opt/SVTECH-Junos-Automation/rundeck-entities/projects/${folder}/* /tmp/rundeck_import_job/${folder}
    if [ -n "${RUNDECK_OPTION_PROVIDER_URL}" ]; then
        sed -i 's,http://localhost:1111,'${RUNDECK_OPTION_PROVIDER_URL}',g' /tmp/rundeck_import_job/${folder}/*
    fi

    if [ -n "${ICINGA2_REPORT_URL}" ]; then
        sed -i 's,http://localhost/report,'${ICINGA2_REPORT_URL}',g' /tmp/rundeck_import_job/${folder}/*
        sed -i 's,http://localhost:8888,'${ICINGA2_REPORT_URL}',g' /tmp/rundeck_import_job/${folder}/*
    fi

    sed -i 's,filter:\ localhost,filter: rundeck,g' /tmp/rundeck_import_job/${folder}/*
    sed -i 's,venv: True,venv: False,g' /tmp/rundeck_import_job/${folder}/*
    echo "Import '${folder}' Project"
    ansible-playbook /opt/SVTECH-Junos-Automation/rundeck-entities/rundeck_import_job.yml --extra-vars "create_project=True override=${OVERRIDE_IMPORT_JOB} project_name=${folder} rundeck_job_path=/tmp/rundeck_import_job/${folder}" || true
done