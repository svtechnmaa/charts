{{- define "payload-ok" -}}
{
  "edge": {
    "labelCfg": {
      "autoRotate": true,
      "position": "center",
      "style": {
        "background": {
          "padding": [3, 6, 3, 6],
          "radius": 0
        },
        "fontSize": 14,
        "fontStyle": "bold",
        "opacity": 1
      }
    },
    "style": {
      "endArrow": {
        "fill": "#00ff29",
        "path": "M 0,0 L 12,-4 L 12,4 Z",
        "stroke": "#00ff29"
      },
      "lineDash": [],
      "lineWidth": 5,
      "startArrow": false,
      "stroke": "#00ff29",
      "strokeOpacity": 1
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
    "img": "/public/router-big_ok.svg",
    "labelCfg": {
      "offset": 12,
      "position": "bottom",
      "style": {
        "background": {
          "padding": [3, 6, 3, 6],
          "radius": 0
        },
        "fillOpacity": 0.8,
        "fontSize": 14,
        "fontStyle": "bold",
        "opacity": 1
      }
    },
    "size": [45, 30],
    "style": {
      "lineDash": []
    },
    "type": "image"
  }
}
{{- end }}