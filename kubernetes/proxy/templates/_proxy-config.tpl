{{/* Define proxy.conf to enable/disable redirection on nginx proxy */}}
{{- define "proxy.proxy.conf" }}
server {
    listen 8080;
    {{- if and .Values.global.ci  .Values.global.proxy.enabled .Values.global.thruk.enabled }}
    location /thruk {
        proxy_pass http://thruk:80;
        proxy_set_header   Host   $host;
        proxy_set_header   X-Real-IP  $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    {{- end  }}

    {{- if and .Values.global.ci .Values.global.proxy.enabled .Values.global.icingaweb.enabled }}
    location /icingaweb/ {
        proxy_pass http://icingaweb:8080;
        proxy_set_header   Host   $host;
        proxy_set_header   X-Real-IP  $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    {{- end  }}

    {{- if and .Values.global.ci .Values.global.proxy.enabled .Values.global.gitlist.enabled }}
    location /gitlist {
        proxy_pass http://gitlist:80;
        proxy_set_header   Host   $host;
        proxy_set_header   X-Real-IP  $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    {{- end  }}

    {{- if and .Values.global.ci ( index .Values "global" "icinga2-report" "enabled" ) }}
    location /grafana/send_request {
        rewrite  ^/grafana/send_request/(.*)  /$1 break;
        proxy_pass http://icinga2-report:8888/;
        proxy_set_header X-Forwarded-Host $host:$server_port;
        proxy_set_header X-Forwarded-Server $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    {{- end  }}

    {{- if and .Values.global.ci .Values.global.proxy.enabled .Values.global.grafana.enabled }}
    location /grafana {
        rewrite  ^/grafana/(.*)  /$1 break;
        proxy_pass http://grafana:3000;
        proxy_set_header   Host   $host;
        proxy_set_header   X-Real-IP  $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    {{- end  }}

    {{- if and .Values.global.ci .Values.global.proxy.enabled .Values.global.nagvis.enabled }}
    location /nagvis {
        proxy_pass http://nagvis:80;
        proxy_set_header   Host   $host;
        proxy_set_header   X-Real-IP  $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    {{- end  }}

    {{- if and .Values.global.ci .Values.global.proxy.enabled .Values.global.rundeck.enabled }}
    location /rundeck {
        client_max_body_size 2G;
        proxy_pass http://rundeck:4440/rundeck;
        proxy_set_header   Host   $host;
        proxy_set_header   X-Real-IP  $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    {{- end  }}

    {{- if and .Values.global.ci .Values.global.proxy.enabled (hasKey .Values.global "report-ui") (index .Values "global" "report-ui" "enabled" ) }}
    location /report/ {
        rewrite  ^/report/(.*)  /$1 break;
        proxy_pass http://report-ui-frontend:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    {{- end  }}

    {{- if ( index .Values "global" "csv-view" "enabled" ) }}
    location /static_csv/ {
        alias /opt/SVTECH-Junos-Automation/addition_toolkit/csv-to-html-table/static/;
    }
    {{- if .Values.global.ci }}
    location /csv {
        rewrite /csv/(.*) /$1  break;
        proxy_pass http://csv-view:8000;
    }
    {{- end  }}
    {{- end  }}

    {{- if and .Values.global.ci .Values.global.proxy.enabled .Values.global.kibana.enabled }}
    location /kibana {
            proxy_pass http://{{- printf "%s-kb-http" .Values.global.elasticsearch.clusterName -}}:5601/kibana;
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    {{- end  }}
}
{{- end }}
