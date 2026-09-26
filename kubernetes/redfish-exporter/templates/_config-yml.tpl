{{- define "redfish-exporter.config.yml" -}}
Auth:
  Username: {{ .auth.username | default "" | quote }}
  Password: {{ .auth.password | default "" | quote }}
Metrics:
{{- with .extraMetrics }}
{{ toYaml . | indent 2 }}
{{- end }}
  - Name: PhysicalServer_State
    Description: 'physical server state status'
    Type: Gauge
    Label: ["ServerAddress","HostName","Model", "Manufacturer", "SerialNumber", "SKU", "TotalSystemMemoryGiB", "IndicatorLED", "BiosVersion", "PowerState"]
    Datapoint: Common
    Result: State
    StatusCode:
      ENABLED: 0
      WARNING: 1
      DISABLED: 2
      GOODINUSE: 0
      UNKNOWN: 99
  - Name: PhysicalServer_Health
    Description: 'physical server health status'
    Type: Gauge
    Label: ["ServerAddress","HostName","Model", "Manufacturer", "SerialNumber", "SKU", "TotalSystemMemoryGiB", "IndicatorLED", "BiosVersion"]
    Datapoint: Common
    Result: Health
    StatusCode:
      OK: 0
      WARNING: 1
      CRITICAL: 2
      UNKNOWN: 99
  - Name: PhysicalServer_PhysicalDriveStatus
    Description: 'physical server metal drive status'
    Type: Gauge
    Result: State
    Label: ["ServerAddress","HostName","Model", "MediaType", "SerialNumber","BlockSizeBytes","CapacityGB"]
    Datapoint: ArrayController.PhysicalDrive
    StatusCode:
      ENABLED: 0
      WARNING: 1
      DISABLED: 2
      GOODINUSE: 0
      UNKNOWN: 99
      ABSENT: 2
  - Name: PhysicalServer_PhysicalDriveHealth
    Description: 'physical server metal drive health'
    Type: Gauge
    Result: Health
    Label: ["ServerAddress","HostName","Model", "MediaType", "SerialNumber","BlockSizeBytes","CapacityGB"]
    Datapoint: ArrayController.PhysicalDrive
    StatusCode:
      OK: 0
      WARNING: 1
      CRITICAL: 2
      UNKNOWN: 99
  - Name: PhysicalServer_MemoryDIMMStatus
    Description: 'physical server memory dimm status'
    Type: Gauge
    Label: ["ServerAddress","HostName", "DeviceLocator", "MemoryType", "SerialNumber","ErrorCorrection","Manufacturer","CapacityMiB"]
    Datapoint: MemoryDIMM
    Result: State
    StatusCode:
      ENABLED: 0
      WARNING: 1
      DISABLED: 2
      GOODINUSE: 0
      UNKNOWN: 99
      ABSENT: 2
  - Name: PhysicalServer_MemoryDIMMHealth
    Description: 'physical server memory dimm health'
    Type: Gauge
    Label: ["ServerAddress","HostName", "DeviceLocator", "MemoryType", "SerialNumber","ErrorCorrection","Manufacturer","CapacityMiB"]
    Datapoint: MemoryDIMM
    Result: Health
    StatusCode:
      OK: 0
      WARNING: 1
      CRITICAL: 2
      UNKNOWN: 99
  - Name: PhysicalServer_EthernetInterfaceStatus
    Description: 'physical server interface network status'
    Type: Gauge
    Label: ["ServerAddress","HostName","MACAddress","SpeedMbps"]
    Datapoint: EthernetInterface
    Result: State
    StatusCode:
      ENABLED: 0
      WARNING: 1
      DISABLED: 2
      GOODINUSE: 0
      UNKNOWN: 99
      STANDBYOFFLINE: 2
      OFFLINE: 2
  - Name: PhysicalServer_EthernetInterfaceHealth
    Description: 'physical server interface network health'
    Type: Gauge
    Label: ["ServerAddress","HostName","MACAddress","SpeedMbps"]
    Datapoint: EthernetInterface
    Result: Health
    StatusCode:
      OK: 0
      WARNING: 1
      CRITICAL: 2
      UNKNOWN: 99
  - Name: PhysicalServer_processorStatus
    Description: 'physical server processor status'
    Type: Gauge
    Label: ["ServerAddress","HostName", "Model", "Socket", "MaxSpeedMHz", "TotalCores","TotalThreads","InstructionSet","Manufacturer"]
    Datapoint: Processor
    Result: State
    StatusCode:
      ENABLED: 0
      WARNING: 1
      DISABLED: 2
      GOODINUSE: 0
      UNKNOWN: 99
  - Name: PhysicalServer_processorHealth
    Description: 'physical server processor health'
    Type: Gauge
    Label: ["ServerAddress","HostName", "Model", "Socket", "MaxSpeedMHz", "TotalCores","TotalThreads","InstructionSet","Manufacturer"]
    Datapoint: Processor
    Result: Health
    StatusCode:
      OK: 0
      WARNING: 1
      CRITICAL: 2
      UNKNOWN: 99
  - Name: PhysicalServer_fanStatus
    Description: 'physical server fan status'
    Type: Gauge
    Label: ["ServerAddress","HostName","Name"]
    Datapoint: Thermal.Fans
    Result: State
    StatusCode:
      ENABLED: 0
      WARNING: 1
      DISABLED: 2
      GOODINUSE: 0
      UNKNOWN: 99
  - Name: PhysicalServer_fanReadingPercent
    Description: 'physical server fan reading percent'
    Type: Gauge
    Label: ["ServerAddress","HostName","Name"]
    Datapoint: Thermal.Fans
    Result: Reading
  - Name: PhysicalServer_temperatureReading
    Description: 'physical server temperature reading percent'
    Type: Gauge
    Label: ["ServerAddress","HostName","Name","PhysicalContext"]
    Datapoint: Thermal.Temperatures
    Result: ReadingCelsius
  - Name: PhysicalServer_powerSupplieStatus
    Description: 'physical server power supplie status'
    Type: Gauge
    Label: ["ServerAddress","HostName","Model","LineInputVoltage","LineInputVoltageType","PowerSupplyType","PowerOutputWatts","PowerCapacityWatts","Manufacturer","SerialNumber"]
    Datapoint: Power.PowerSupplies
    Result: State
    StatusCode:
      ENABLED: 0
      WARNING: 1
      DISABLED: 2
      GOODINUSE: 0
      UNKNOWN: 99
      ABSENT: 2
{{- end }}