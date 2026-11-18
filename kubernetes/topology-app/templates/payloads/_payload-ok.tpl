{{- define "payload-ok" -}}
{
  "edge": {
    "labelCfg": {
      "autoRotate": true,
      "position": "center",
      "style": {
        "background": {
          "padding": [3, 6, 3, 6]
        },
        "opacity": 1
      }
    },
    "style": {
      "endArrow": false,
      "lineDash": [],
      "startArrow": false,
      "stroke": "#00cc00",
      "strokeOpacity": 1
    }
  },
  "node": {
    "img": "/public/router-big_ok.svg",
    "labelCfg": {
      "style": {
        "background": {
          "padding": [3, 6, 3, 6]
        },
        "fillOpacity": 0.8,
        "fontStyle": "bold",
        "opacity": 1
      }
    },
    "style": {
      "lineDash": []
    },
    "type": "image"
  }
}
{{- end }}
