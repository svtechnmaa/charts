{{- define "seed-queries" -}}
{
  "Query": [
    {
      "ID": 1,
      "Name": "icingadb_host_id",
      "ParentDatasourceName": "Grafana",
      "DatasourceName": "IcingaDB",
      "Content": "SELECT name, address, LOWER(HEX(id)) FROM host;",
      "ResultMapper": "function(result) {\n  _.forEach(result.results.A.frames[0].data.values[0], function(hostname, index) {\n    var address = result.results.A.frames[0].data.values[1][index];\n    var host_id = result.results.A.frames[0].data.values[2][index];\n\n    emit([hostname, address].join('|'), host_id);\n    emit(hostname, host_id);\n  });\n}",
      "Schedule": "@every 2m"
    },
    {
      "ID": 2,
      "Name": "icingadb_service_id",
      "ParentDatasourceName": "Grafana",
      "DatasourceName": "IcingaDB",
      "Content": "SELECT t1.name AS hostname, t1.address, t2.name AS servicename, LOWER(HEX((t2.id))) as service_id FROM host t1 JOIN service t2 ON t1.id = t2.host_id",
      "ResultMapper": "function(result) {\n  _.forEach(result.results.A.frames[0].data.values[0], function(hostname, index) {\n    var address = result.results.A.frames[0].data.values[1][index];\n    var servicename = result.results.A.frames[0].data.values[2][index];\n    var service_id = result.results.A.frames[0].data.values[3][index];\n    emit([hostname, address, servicename].join('|'), service_id);\n    emit([hostname, servicename].join('/'), service_id);\n  });\n}",
      "Schedule": "@every 2m"
    },
    {
      "ID": 3,
      "Name": "default_host_state_from_redis",
      "DatasourceID": 4,
      "Content": "local ks = redis.call('HKEYS', 'icinga:host:state')\nlocal ts = redis.call('HVALS', 'icinga:host:state')\nreturn {ks, ts}",
      "ResultMapper": "function(result) {\n  result[0].forEach(function(k, i) {\n    var obj = JSON.parse(result[1][i])\n    emit(k, obj['hard_state'])\n  })\n}                                                                                  ",
      "Schedule": "@every 1m"
    },
    {
      "ID": 4,
      "Name": "default_service_state_from_redis",
      "DatasourceID": 4,
      "Content": "local ks = redis.call('HKEYS', 'icinga:service:state')\nlocal ts = redis.call('HVALS', 'icinga:service:state')\nreturn {ks, ts}",
      "ResultMapper": "function(result) {\n  result[0].forEach(function(k, i) {\n    var obj = JSON.parse(result[1][i])\n    emit(k, obj['hard_state'])\n  })\n}                                                                            ",
      "Schedule": "@every 5m"
    },
    {
      "ID": 5,
      "Name": "default_in_ult_from_redis",
      "DatasourceID": 4,
      "Content": "local ks = redis.call('HKEYS', 'icinga:service:state')\nlocal ts = redis.call('HVALS', 'icinga:service:state')\nreturn {ks, ts}",
      "ResultMapper": "function(result) {\n  result[0].forEach(function(k, i) {\n    var obj = JSON.parse(result[1][i])\n    var performanceData = typeof obj['performance_data'] === 'string' ? obj['performance_data'] : '';\n\n    // Extract in_ult value using regex\n    var inUltMatch = performanceData.match(/in_ult=(\\d+)%/);\n    var inUltInt = inUltMatch ? parseInt(inUltMatch[1], 10) : 0;\n\n    // Convert to formatted string: \"0 %\"\n    var inUltValue = inUltInt + \" %\";\n\n    emit(k, inUltValue);\n  })\n}",
      "Schedule": "@every 5m"
    },
    {
      "ID": 6,
      "Name": "default_out_ult_from_redis",
      "DatasourceID": 4,
      "Content": "local ks = redis.call('HKEYS', 'icinga:service:state')\nlocal ts = redis.call('HVALS', 'icinga:service:state')\nreturn {ks, ts}",
      "ResultMapper": "function(result) {\n  result[0].forEach(function(k, i) {\n    var obj = JSON.parse(result[1][i])\n    var performanceData = typeof obj['performance_data'] === 'string' ? obj['performance_data'] : '';\n\n    // Extract in_ult value using regex\n    var outUltMatch = performanceData.match(/out_ult=(\\d+)%/);\n    var outUltInt = outUltMatch ? parseInt(outUltMatch[1], 10) : 0;\n\n    // Convert to formatted string: \"0 %\"\n    var outUltValue = outUltInt + \" %\";\n    emit(k, outUltValue);\n  })\n}",
      "Schedule": "@every 5m"
    },
    {
      "ID": 7,
      "Name": "default_in_ult_from_influxdb",
      "ParentDatasourceName": "Grafana",
      "DatasourceName": "influxdb_nms",
      "Content": "SELECT last(value) from \"Interface-check-command\" WHERE (time > now() - 5m) AND metric = 'in_ult' GROUP BY hostname, metric, service;",
      "ResultMapper": "function(result) { _.forEach(result.results[0].series, function(obj, index) { emit([obj.tags.hostname, obj.tags.service, obj.tags.metric].join('|'), obj.values[0][1]) })}",
      "Schedule": "@every 15m"
    },
    {
      "ID": 8,
      "Name": "default_out_ult_from_influxdb",
      "ParentDatasourceName": "Grafana",
      "DatasourceName": "influxdb_nms",
      "Content": "SELECT last(value) from \"Interface-check-command\" WHERE (time > now() - 5m) AND metric = 'out_ult' GROUP BY hostname, metric, service;",
      "ResultMapper": "function(result) { _.forEach(result.results[0].series, function(obj, index) { emit([obj.tags.hostname, obj.tags.service, obj.tags.metric].join('|'), obj.values[0][1]) })}",
      "Schedule": "@every 15m"
    },
    {
      "ID": 9,
      "Name": "default_rx_from_influxdb",
      "ParentDatasourceName": "Grafana",
      "DatasourceName": "influxdb_nms",
      "Content": "SELECT last(value) from \"Interface-check-command\" WHERE (time > now() - 5m) AND metric = 'OpticRX' GROUP BY hostname, metric, service;",
      "ResultMapper": "function(result) { _.forEach(result.results[0].series, function(obj, index) { emit([obj.tags.hostname, obj.tags.service, obj.tags.metric].join('|'), obj.values[0][1]) })}",
      "Schedule": "@every 15m"
    },
    {
      "ID": 10,
      "Name": "default_tx_from_influxdb",
      "ParentDatasourceName": "Grafana",
      "DatasourceName": "influxdb_nms",
      "Content": "SELECT last(value) from \"Interface-check-command\" WHERE (time > now() - 5m) AND metric = 'OpticTX' GROUP BY hostname, metric, service;",
      "ResultMapper": "function(result) { _.forEach(result.results[0].series, function(obj, index) { emit([obj.tags.hostname, obj.tags.service, obj.tags.metric].join('|'), obj.values[0][1]) })}",
      "Schedule": "@every 15m"
    },
    {
      "ID": 11,
      "Name": "default_critical_service_count_from_icingadb",
      "ParentDatasourceName": "Grafana",
      "DatasourceName": "IcingaDB",
      "Content": "SELECT t1.name AS hostname,t1.address, t3.hard_state, COUNT(t3.hard_state) AS hard_state_count FROM host t1 JOIN service t2 ON t1.id = t2.host_id JOIN service_state t3 ON t2.id = t3.service_id WHERE t2.name NOT LIKE 'If%' GROUP BY t1.id, t1.name, t1.address, t3.hard_state;",
      "ResultMapper": "function(result) { _.forEach(result.results.A.frames[0].data.values[0], function(hostname, index) { var address = result.results.A.frames[0].data.values[1][index]; var hard_state_count = result.results.A.frames[0].data.values[2][index]; emit([hostname, address].join('|'), { number_service_critical: hard_state_count }) }) }",
      "Schedule": "@every 15m"
    },
    {
      "ID": 12,
      "Name": "default_warning_service_count_from_icingadb",
      "ParentDatasourceName": "Grafana",
      "DatasourceName": "IcingaDB",
      "Content": "SELECT t1.name AS hostname,t1.address, t3.hard_state, COUNT(t3.hard_state) AS hard_state_count FROM host t1 JOIN service t2 ON t1.id = t2.host_id JOIN service_state t3 ON t2.id = t3.service_id WHERE t2.name NOT LIKE 'If%' GROUP BY t1.id, t1.name, t1.address, t3.hard_state;",
      "ResultMapper": "function(result) { _.forEach(result.results.A.frames[0].data.values[0], function(hostname, index) { var address = result.results.A.frames[0].data.values[1][index]; var hard_state_count = result.results.A.frames[0].data.values[2][index]; emit([hostname, address].join('|'), { number_service_warning: hard_state_count }) }) }",
      "Schedule": "@every 15m"
    },
    {
      "ID": 13,
      "Name": "default_red_alarm_count_from_icingadb",
      "ParentDatasourceName": "Grafana",
      "DatasourceName": "IcingaDB",
      "Content": "SELECT t1.name AS hostname, t1.address, t2.name AS servicename, t3.hard_state AS red_alarm_count FROM host t1 JOIN service t2 ON t1.id = t2.host_id JOIN service_state t3 ON t2.id = t3.service_id WHERE t2.name = 'Juniper_RedAlarm';",
      "ResultMapper": "function(result) {\n  _.forEach(result.results.A.frames[0].data.values[0], function(hostname, index) {\n    var address = result.results.A.frames[0].data.values[1][index];\n    var red_alarm_status_raw = result.results.A.frames[0].data.values[3][index];\n\n    var red_alarm_status;\n\n    // Check null / undefined / empty\n    if (red_alarm_status_raw === null || red_alarm_status_raw === undefined || red_alarm_status_raw === '') {\n      red_alarm_status = \"Unknown\";\n    } else {\n      var state = parseInt(red_alarm_status_raw, 10);\n\n      if (state === 2) {\n        red_alarm_status = \"Yes\";        // CRITICAL → có alarm\n      } else if (state === 0) {\n        red_alarm_status = \"No\";         // OK → không alarm\n      } else {\n        red_alarm_status = \"Unknown\";    // UNKNOWN (3) hoặc giá trị khác\n      }\n    }\n    emit([hostname, address].join('|'),red_alarm_status);\n    emit(hostname,red_alarm_status);\n  });\n}",
      "Schedule": "@every 15m"
    },
    {
      "ID": 14,
      "Name": "default_yellow_alarm_count_from_icingadb",
      "ParentDatasourceName": "Grafana",
      "DatasourceName": "IcingaDB",
      "Content": "SELECT t1.name AS hostname, t1.address, t2.name AS service_name, t3.hard_state AS yellow_alarm_count FROM host t1 JOIN service t2 ON t1.id = t2.host_id JOIN service_state t3 ON t2.id = t3.service_id WHERE t2.name = 'Juniper_YellowAlarm';",
      "ResultMapper": "function(result) {\n  _.forEach(result.results.A.frames[0].data.values[0], function(hostname, index) {\n    var address = result.results.A.frames[0].data.values[1][index];\n    var yellow_alarm_status_raw = result.results.A.frames[0].data.values[3][index];\n\n    var yellow_alarm_status;\n\n    // Check null / undefined / empty\n    if (yellow_alarm_status_raw === null || yellow_alarm_status_raw === undefined || yellow_alarm_status_raw === '') {\n      yellow_alarm_status = \"Unknown\";\n    } else {\n      var state = parseInt(yellow_alarm_status_raw, 10);\n\n      if (state === 1) {\n        yellow_alarm_status = \"Yes\";       // WARNING → có alarm\n      } else if (state === 0) {\n        yellow_alarm_status = \"No\";        // OK → không alarm\n      } else {\n        yellow_alarm_status = \"Unknown\";   // UNKNOWN (3) hoặc giá trị khác\n      }\n    }\n    emit([hostname, address].join('|'),yellow_alarm_status);\n    emit(hostname,yellow_alarm_status);\n  });\n}",
      "Schedule": "@every 15m"
    },
    {
      "ID": 15,
      "Name": "default_performance_data",
      "DatasourceID": 4,
      "Content": "local ks = redis.call('HKEYS', 'icinga:service:state')\nlocal ts = redis.call('HVALS', 'icinga:service:state')\nreturn {ks, ts}",
      "ResultMapper": "function(result) {\n  result[0].forEach(function(k, i) {\n    var obj = JSON.parse(result[1][i] || '{}');\n\n    var hard_state = obj['hard_state'];\n    var performanceData = obj['output'] || '';\n\n    var status = hard_state;\n\n    if (performanceData.indexOf(', DOWN,') !== -1) {\n      status = 4;\n    } else if (performanceData.indexOf('has exceeded CRIT threshold') !== -1) {\n      status = 10;\n    } else if (performanceData.indexOf('has exceeded WARN threshold') !== -1) {\n      status = 7;\n    }\n\n    emit(k, {\n      status: status,\n      output: performanceData\n    });\n  });\n}",
      "Schedule": "@every 90s"
    }
  ]
}
{{- end -}}