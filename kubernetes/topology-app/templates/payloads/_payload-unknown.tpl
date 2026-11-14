{{- define "payload-unknown" -}}
{
  "edge": {
    "labelCfg": {
      "autoRotate": true,
      "position": "center",
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
      "stroke": "#8c00ff",
      "strokeOpacity": 1
    }
  },
  "node": {
    "img": "/public/router-big_unknown.svg",
    "labelCfg": {
      "style": {
        "background": {
          "padding": [3, 6, 3, 6]
        },
        "fillOpacity": 1,
        "fontStyle": "bold"
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
