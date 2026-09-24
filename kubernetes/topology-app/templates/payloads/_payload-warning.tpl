{{- define "payload-warning" -}}
{
  "edge": {
    "labelCfg": {
      "autoRotate": true,
      "position": "center",
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
      "endArrow": false,
      "lineDash": [],
      "startArrow": false,
      "stroke": "#f0f000",
      "strokeOpacity": 1
    }
  },
  "node": {
    "img": "/public/router-big_warning.svg",
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
      "lineDash": [],
      "opacity": 1
    },
    "type": "image"
  }
}
{{- end }}
