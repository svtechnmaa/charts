{{- define "payload-templates" -}}
{
  "graphLevelStyle": {
    "edge": {
      "manualLabelCfg": {
        "autoRotate": true,
        "position": "center",
        "style": {
          "background": {
            "padding": [3, 6, 3, 6]
          },
          "fillOpacity": 1,
          "fontSize": 40,
          "fontStyle": "bold",
          "opacity": 1
        }
      },
      "manualStyle": {
        "style": {
          "arrowColor": "#00ff29",
          "arrowOffset": 13,
          "endArrow": {
            "fill": "#00ff29",
            "path": "M 26,0 L 38,-4 L 38,4 Z",
            "stroke": "#00ff29"
          },
          "lineDash": [],
          "lineWidth": 15,
          "startArrow": false,
          "stroke": "#00ff29",
          "strokeOpacity": 1
        }
      }
    },
    "node": {
      "manualLabelCfg": {
        "offset": 12,
        "style": {
          "background": {
            "padding": [3, 6, 3, 6]
          },
          "fillOpacity": 1,
          "fontSize": 50,
          "fontStyle": "bold",
          "opacity": 1
        }
      },
      "manualStyle": {
        "img": "/public/router-big_ok.svg",
        "size": [100, 85],
        "style": {
          "fillOpacity": 1,
          "lineDash": [],
          "lineWidth": 1,
          "opacity": 1,
          "strokeOpacity": 1
        },
        "type": "image"
      }
    },
    "subMap": {
      "fixCollapseSize": 100,
      "labelCfg": {
        "maxLength": 500,
        "position": "top",
        "style": {
          "background": {
            "padding": [6, 14, 4, 14],
            "radius": 0
          },
          "fill": "#ffffff",
          "fillOpacity": 1,
          "fontSize": 50,
          "fontStyle": "bold"
        }
      },
      "padding": 30,
      "style": {
        "fillOpacity": 0.1,
        "lineDash": [],
        "lineWidth": 5,
        "stroke": "#1400ff",
        "strokeOpacity": 1
      },
      "type": "cCircle"
    }
  },
  "nodeLoggingConfigs": [
    {
      "url": "https://{{ .Values.global.frontendVip }}/grafana/d-solo/syslog-overview/juniper-syslog-overview?orgId=1&from=now-30&to=now&timezone=browser&var-hostgroup=$__all&var-hostname={{`{{hostname}}`}}&var-facility=$__all&var-severity=$__all&var-rows=600&panelId=53&__feature.dashboardSceneSolo",
      "{{`{{hostname}}`}}": "hostname"
    }
  ],
  "edgeLoggingConfigs": [],
  "nodeMetricConfigs": [
    {
      "url": "https://{{ .Values.global.frontendVip }}/grafana/d-solo/device-detail/device-detail?var-hostgroup=$__all&var-hostname={{`{{hostname}}`}}&orgId=1&from=now-24h&to=now&timezone=browser&var-interface=$__all&var-FPC=$__all&var-rp=six_months&var-service=$__all&panelId=2&__feature.dashboardSceneSolo",
      "{{`{{hostname}}`}}": "hostname"
    },
    {
      "url": "https://{{ .Values.global.frontendVip }}/grafana/d-solo/device-detail/device-detail?var-hostgroup=$__all&var-hostname={{`{{hostname}}`}}&orgId=1&from=now-1h&to=now&timezone=browser&var-interface=$__all&var-rp=six_months&refresh=3m&panelId=129&__feature.dashboardSceneSolo",
      "{{`{{hostname}}`}}": "hostname"
    },
    {
      "url": "https://{{ .Values.global.frontendVip }}/grafana/d-solo/device-detail/device-detail?var-hostgroup=$__all&var-hostname={{`{{hostname}}`}}&orgId=1&from=now-1h&to=now&timezone=browser&var-interface=$__all&var-rp=six_months&refresh=3m&panelId=131&__feature.dashboardSceneSolo",
      "{{`{{hostname}}`}}": "hostname"
    },
    {
      "url": "https://{{ .Values.global.frontendVip }}/grafana/d-solo/device-detail/device-detail?var-hostgroup=$__all&var-hostname={{`{{hostname}}`}}&orgId=1&from=now-1h&to=now&timezone=browser&var-interface=$__all&var-rp=six_months&refresh=3m&panelId=130&__feature.dashboardSceneSolo",
      "{{`{{hostname}}`}}": "hostname"
    }
  ],
  "edgeMetricConfigs": [
    {
      "url": "https://{{ .Values.global.frontendVip }}/grafana/d-solo/interface-detail/interface-detail?orgId=1&from=now-6h&to=now&timezone=browser&var-hostgroup=$__all&var-hostname={{`{{source_hostname}}`}}&var-interface={{`{{physical_interface}}`}}&var-perf=in_bits&var-rp=six_months&panelId=6&__feature.dashboardSceneSolo",
      "{{`{{hostname}}`}}": "hostname",
      "{{`{{interface_name}}`}}": "physical_interface",
      "{{`{{physical_interface}}`}}": "physical_interface",
      "{{`{{source_hostname}}`}}": "source_hostname"
    }
  ],
  "metaNodeCfg": [
    {
      "alias": "redis_host_id",
      "queryFormat": "${hostname}|${address}",
      "queryId": "1"
    },
    {
      "alias": "redis_host_state",
      "queryFormat": "${redis_host_id}",
      "queryId": "3"
    },
    {
      "alias": "critical_service_count",
      "queryFormat": "${hostname}|${address}",
      "queryId": "11"
    },
    {
      "alias": "warning_service_count",
      "queryFormat": "${hostname}|${address}",
      "queryId": "12"
    },
    {
      "alias": "red_alarm_status",
      "queryFormat": "${hostname}|${address}",
      "queryId": "13"
    },
    {
      "alias": "yellow_alarm_status",
      "queryFormat": "${hostname}|${address}",
      "queryId": "14"
    }
  ],
  "metaEdgeCfg": [
    {
      "alias": "redis_ifcheck_id",
      "queryFormat": "${source_hostname}|${source_address}|IfCheck-${physical_interface}",
      "queryId": "2"
    },
    {
      "alias": "redis_ifcheck_state",
      "queryFormat": "${redis_ifcheck_id}",
      "queryId": "4"
    },
    {
      "alias": "info",
      "queryFormat": "${redis_ifcheck_id}",
      "queryId": "15"
    }
  ],
  "nodeRuleCfg": [
    {
      "expression": "redis_host_state=1",
      "state": 4
    },
    {
      "expression": "red_alarm_status=\"Yes\"",
      "state": 3
    },
    {
      "expression": "yellow_alarm_status=\"Yes\"",
      "state": 2
    },
    {
      "expression": "redis_host_state=0",
      "state": 1
    },
    {
      "expression": "id is defined",
      "state": 1
    }
  ],
  "edgeRuleCfg": [
    {
      "expression": "info.status=2",
      "state": 3
    },
    {
      "expression": "info.status=1",
      "state": 2
    },
    {
      "expression": "info.status=0",
      "state": 1
    },
    {
      "expression": "id is defined",
      "state": 5
    }
  ],
  "nodeBadgeFieldCfg": {},
  "edgeBadgeFieldCfg": {},
  "nodeLabelFieldCfg": {
    "availableFields": [
      {
        "fieldName": "address",
        "path": "address"
      },
      {
        "fieldName": "hostname",
        "path": "hostname"
      },
      {
        "fieldName": "id",
        "path": "id"
      },
      {
        "fieldName": "label",
        "path": "label"
      },
      {
        "fieldName": "operational_state",
        "path": "operational_state"
      },
      {
        "fieldName": "x",
        "path": "x"
      },
      {
        "fieldName": "y",
        "path": "y"
      },
      {
        "fieldName": "hardware_info",
        "path": "hardware_info"
      }
    ],
    "selectedField": "hostname"
  },
  "edgeLabelFieldCfg": {
    "availableFields": [
      {
        "fieldName": "dest_address",
        "path": "dest_address"
      },
      {
        "fieldName": "dest_hostname",
        "path": "dest_hostname"
      },
      {
        "fieldName": "id",
        "path": "id"
      },
      {
        "fieldName": "label",
        "path": "label"
      },
      {
        "fieldName": "neighbor_physical_interface",
        "path": "neighbor_physical_interface"
      },
      {
        "fieldName": "neighbor_physical_interface_name",
        "path": "neighbor_physical_interface_name"
      },
      {
        "fieldName": "operational_state",
        "path": "operational_state"
      },
      {
        "fieldName": "originalCurveOffset",
        "path": "originalCurveOffset"
      },
      {
        "fieldName": "pair_id",
        "path": "pair_id"
      },
      {
        "fieldName": "physical_interface",
        "path": "physical_interface"
      },
      {
        "fieldName": "physical_interface_name",
        "path": "physical_interface_name"
      },
      {
        "fieldName": "remote_ifindex",
        "path": "remote_ifindex"
      },
      {
        "fieldName": "runtime",
        "path": "runtime"
      },
      {
        "fieldName": "source",
        "path": "source"
      },
      {
        "fieldName": "source_address",
        "path": "source_address"
      },
      {
        "fieldName": "source_hostname",
        "path": "source_hostname"
      },
      {
        "fieldName": "target",
        "path": "target"
      }
    ],
    "selectedField": "physical_interface"
  },
  "nodeFieldViewCfg": {
    "availableFields": [
      {
        "fieldName": "address",
        "path": "address",
        "selected": true,
        "selectedForSidebar": true,
        "selectedForTooltip": false
      },
      {
        "fieldName": "depth",
        "path": "depth",
        "selected": false,
        "selectedForSidebar": false,
        "selectedForTooltip": false
      },
      {
        "fieldName": "hostname",
        "path": "hostname",
        "selected": true,
        "selectedForSidebar": true,
        "selectedForTooltip": false
      },
      {
        "fieldName": "id",
        "path": "id",
        "selected": true,
        "selectedForSidebar": true,
        "selectedForTooltip": true
      },
      {
        "fieldName": "label",
        "path": "label",
        "selected": false,
        "selectedForSidebar": false,
        "selectedForTooltip": false
      },
      {
        "fieldName": "lldp.router_id",
        "path": "lldp.router_id",
        "selected": false,
        "selectedForSidebar": false,
        "selectedForTooltip": false
      },
      {
        "fieldName": "operational_state",
        "path": "operational_state",
        "selected": true,
        "selectedForSidebar": true,
        "selectedForTooltip": true
      },
      {
        "fieldName": "redis_host_id",
        "path": "redis_host_id",
        "selected": true,
        "selectedForSidebar": true,
        "selectedForTooltip": false
      },
      {
        "fieldName": "x",
        "path": "x",
        "selected": false,
        "selectedForSidebar": false,
        "selectedForTooltip": false
      },
      {
        "fieldName": "y",
        "path": "y",
        "selected": false,
        "selectedForSidebar": false,
        "selectedForTooltip": false
      },
      {
        "fieldName": "hardware_info",
        "path": "hardware_info",
        "selected": true,
        "selectedForSidebar": true,
        "selectedForTooltip": true
      }
    ],
    "computedFields": []
  },
  "edgeFieldViewCfg": {
    "availableFields": [
      {
        "fieldName": "depth",
        "path": "depth",
        "selected": false
      },
      {
        "fieldName": "dest_address",
        "path": "dest_address",
        "selected": false
      },
      {
        "fieldName": "dest_hostname",
        "path": "dest_hostname",
        "selected": false
      },
      {
        "fieldName": "id",
        "path": "id",
        "selected": true
      },
      {
        "fieldName": "label",
        "path": "label",
        "selected": false
      },
      {
        "fieldName": "neighbor_physical_interface",
        "path": "neighbor_physical_interface",
        "selected": true
      },
      {
        "fieldName": "neighbor_physical_interface_name",
        "path": "neighbor_physical_interface_name",
        "selected": false
      },
      {
        "fieldName": "operational_state",
        "path": "operational_state",
        "selected": true
      },
      {
        "fieldName": "originalCurveOffset",
        "path": "originalCurveOffset",
        "selected": false
      },
      {
        "fieldName": "pair_id",
        "path": "pair_id",
        "selected": false
      },
      {
        "fieldName": "physical_interface",
        "path": "physical_interface",
        "selected": true
      },
      {
        "fieldName": "physical_interface_name",
        "path": "physical_interface_name",
        "selected": false
      },
      {
        "fieldName": "remote_ifindex",
        "path": "remote_ifindex",
        "selected": false
      },
      {
        "fieldName": "runtime",
        "path": "runtime",
        "selected": false
      },
      {
        "fieldName": "source",
        "path": "source",
        "selected": true
      },
      {
        "fieldName": "source_address",
        "path": "source_address",
        "selected": false
      },
      {
        "fieldName": "source_hostname",
        "path": "source_hostname",
        "selected": false
      },
      {
        "fieldName": "target",
        "path": "target",
        "selected": true
      },
      {
        "fieldName": "redis_ifcheck_id",
        "path": "redis_ifcheck_id",
        "selected": false
      },
      {
        "fieldName": "redis_ifcheck_state",
        "path": "redis_ifcheck_state",
        "selected": false
      },
      {
        "fieldName": "info",
        "path": "info",
        "selected": true
      },
      {
        "fieldName": "haloColor",
        "path": "haloColor",
        "selected": false
      }
    ],
    "computedFields": []
  },
  "nodeStatisticCfg": [
    {
      "description": "WARNING",
      "error": true,
      "expression": "operational_state = ''Warning''"
    },
    {
      "description": "No of red alarm",
      "error": true,
      "expression": "red_alarm_status=\"Yes\""
    },
    {
      "description": "No of Yellow alarm",
      "error": true,
      "expression": "yellow_alarm_status=\"Yes\""
    }
  ],
  "edgeStatisticCfg": []
}
{{- end }}
