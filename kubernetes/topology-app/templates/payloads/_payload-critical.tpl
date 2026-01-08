{{- define "payload-critical" -}}
{
  "edge": {
    "haloColor": "#ff0000",
    "labelCfg": {
      "autoRotate": true,
      "style": {
        "background": {
          "padding": [3, 6, 3, 6]
        },
        "fontSize": 14,
        "fontStyle": "bold"
      }
    },
    "style": {
      "endArrow": {
        "fill": "#ff0000",
        "path": "M 0,0 L 12,-4 L 12,4 Z",
        "stroke": "#ff0000"
      },
      "lineDash": [],
      "lineWidth": 5,
      "startArrow": {
        "fill": "#ff0000",
        "path": "M 0,0 L 12,-4 L 12,4 Z",
        "stroke": "#ff0000"
      },
      "stroke": "#ff0000"
    }
  },
  "node": {
    "clipCfg": {
      "r": 30,
      "show": true,
      "type": "circle",
      "x": 0,
      "y": -3
    },
    "haloColor": "#ff0000",
    "img": "/public/router-big_critical.svg",
    "labelCfg": {
      "offset": 12,
      "position": "bottom",
      "style": {
        "background": {
          "padding": [3, 6, 3, 6]
        },
        "fillOpacity": 1,
        "fontSize": 14,
        "fontStyle": "bold",
        "opacity": 1
      }
    },
    "size": [45, 30],
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