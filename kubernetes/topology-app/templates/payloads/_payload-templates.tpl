{{- define "payload-templates" -}}
{
  "graphLevelStyle": {
    "node": {
      "manualStyle": {
        "size": [45, 30],
        "style": {
          "fillOpacity": 1,
          "lineDash": [],
          "strokeOpacity": 1,
          "lineWidth": 1,
          "opacity": 1
        },
        "type": "image",
        "img": "/public/router-big_ok.svg"
      },
      "manualLabelCfg": {
        "style": {
          "fontSize": 14,
          "fillOpacity": 1,
          "fontStyle": "bold",
          "opacity": 1,
          "background": {
            "padding": [3, 6, 3, 6]
          }
        },
        "offset": 12
      }
    },
    "edge": {
      "manualStyle": {
        "style": {
          "lineWidth": 5,
          "lineDash": [],
          "stroke": "#00ff29",
          "strokeOpacity": 1,
          "startArrow": false,
          "arrowOffset": 13,
          "endArrow": {
            "fill": "#00ff29",
            "stroke": "#00ff29",
            "path": "M 0,0 L 12,-4 L 12,4 Z"
          }
        }
      },
      "manualLabelCfg": {
        "style": {
          "fontSize": 14,
          "fillOpacity": 1,
          "fontStyle": "bold",
          "opacity": 1,
          "background": {
            "padding": [3, 6, 3, 6]
          }
        },
        "position": "center",
        "autoRotate": true
      }
    },
    "subMap": {
      "type": "cCircle",
      "fixCollapseSize": 10,
      "padding": 30,
      "style": {
        "fillOpacity": 0.1,
        "lineDash": [],
        "stroke": "#1400ff",
        "strokeOpacity": 1,
        "lineWidth": 5
      },
      "labelCfg": {
        "style": {
          "fontSize": 14,
          "fillOpacity": 1,
          "fontStyle": "bold",
          "background": {
            "padding": [6, 14, 4, 14],
            "radius": 0
          }
        },
        "position": "top"
      }
    }
  },
  "metaEdgeCfg": [
    {
      "queryId": "2",
      "queryFormat": "${source_hostname}|${source_address}|IfCheck-${physical_interface}",
      "alias": "redis_ifcheck_id"
    },
    {
      "queryId": "4",
      "queryFormat": "${redis_ifcheck_id}",
      "alias": "redis_ifcheck_state"
    },
    {
      "queryId": "5",
      "queryFormat": "${source_hostname}|IfCheck-${physical_interface}",
      "alias": "in_ultilization"
    },
    {
      "queryId": "6",
      "queryFormat": "${source_hostname}|IfCheck-${physical_interface}",
      "alias": "out_ultilization"
    },
    {
      "queryId": "9",
      "queryFormat": "${source_hostname}|IfCheck-${physical_interface}|OpticRX",
      "alias": "RX"
    },
    {
      "queryId": "10",
      "queryFormat": "${source_hostname}|IfCheck-${physical_interface}|OpticTX",
      "alias": "TX"
    }
  ],
  "nodeMetricConfigs": [
    {
      "url": "https://{{ .Values.global.frontendVip }}/grafana/d-solo/device-detail/device-detail?var-hostgroup=$__all&var-hostname={{`{{hostname}}`}}&orgId=1&from=now-24h&to=now&timezone=browser&var-interface=$__all&var-FPC=$__all&var-rp=six_months&var-service=$__all&panelId=2&__feature.dashboardSceneSolo",
      "{{`{{hostname}}`}}": "hostname"
    }
  ],
  "edgeMetricConfigs": [
    {
      "url": "https://{{ .Values.global.frontendVip }}/grafana/d-solo/aeivihvpya8lce/interface-detail?orgId=1&from=now-24h&to=now&timezone=browser&var-hostgroup=$__all&var-hostname={{`{{source_hostname}}`}}&var-service={{`{{interface_name}}`}}&var-command=Interface-check-command&var-perf=OpticRX&var-rp=six_months&panelId=3&__feature.dashboardSceneSolo",
      "{{`{{hostname}}`}}": "hostname",
      "{{`{{interface_name}}`}}": "physical_interface",
      "{{`{{source_hostname}}`}}": "source_hostname"
    }
  ],
  "metaNodeCfg": [
    {
      "queryId": "1",
      "queryFormat": "${hostname}|${address}",
      "alias": "redis_host_id"
    },
    {
      "queryId": "3",
      "queryFormat": "${redis_host_id}",
      "alias": "redis_host_state"
    },
    {
      "queryId": "11",
      "queryFormat": "${hostname}|${address}",
      "alias": "critical_service_count"
    },
    {
      "queryId": "12",
      "queryFormat": "${hostname}|${address}",
      "alias": "warning_service_count"
    },
    {
      "queryId": "13",
      "queryFormat": "${hostname}|${address}",
      "alias": "red_alarm_count"
    },
    {
      "queryId": "14",
      "alias": "yellow_alarm_count",
      "queryFormat": "${hostname}|${address}"
    }
  ],
  "nodeRuleCfg": [
    {
      "expression": "redis_host_state=1",
      "state": 4
    },
    {
      "expression": "critical_service_count.number_service_critical > 0 || red_alarm_count.number_red_alarm > 0",
      "state": 3
    },
    {
      "expression": "warning_service_count.number_service_warning > 0 || yellow_alarm_count.number_yellow_alarm > 0",
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
      "expression": "redis_ifcheck_state=2",
      "state": 3
    },
    {
      "expression": "redis_ifcheck_state=1",
      "state": 2
    },
    {
      "expression": "redis_ifcheck_state=0",
      "state": 1
    },
    {
      "expression": "id is defined",
      "state": 5
    }
  ]
}
{{- end }}