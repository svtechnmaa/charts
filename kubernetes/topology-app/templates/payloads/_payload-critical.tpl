{{- define "payload-critical" -}}
{
  "edge": {
    "labelCfg": {
      "autoRotate": true,
      "style": {
        "background": {
          "padding": [3, 6, 3, 6]
        },
        "fontStyle": "bold"
      }
    },
    "style": {
      "endArrow": false,
      "lineDash": [],
      "startArrow": false,
      "stroke": "#ff0000"
    }
  },
  "node": {
    "img": "/public/router-big_critical.svg",
    "labelCfg": {
      "style": {
        "background": {
          "padding": [3, 6, 3, 6]
        },
        "fillOpacity": 1,
        "fontStyle": "bold",
        "opacity": 1
      }
    },
    "style": {
      "fillOpacity": 1,
      "lineDash": [],
      "opacity": 1,
      "strokeOpacity": 0.1
    },
    "type": "image"
  }
}
{{- end }}
