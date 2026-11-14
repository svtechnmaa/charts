{{- define "payload-down" -}}
{
  "edge": {
    "labelCfg": {
      "autoRotate": true,
      "position": "center",
      "style": {
        "background": {
          "padding": [3, 6, 3, 6]
        },
        "fill": "#000000",
        "fontStyle": "bold"
      }
    },
    "style": {
      "endArrow": false,
      "lineDash": [],
      "startArrow": false,
      "stroke": "#9ca3af"
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
        "fontStyle": "bold",
        "opacity": 1
      }
    },
    "style": {
      "lineDash": [],
      "strokeOpacity": 0.1
    },
    "type": "image"
  }
}
{{- end }}
