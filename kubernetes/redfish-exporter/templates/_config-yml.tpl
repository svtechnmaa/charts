{{- define "redfish-exporter.config.yml" -}}
Auth:
  Username: {{ .auth.username | default "" | quote }}
  Password: {{ .auth.password | default "" | quote }}
Tuning:
  MaxParallelTargets: 50
  TargetConcurrency: 8             # process-wide
  MaxResponseBytes: 10485760       # process-wide
  Fast:
    TTLSeconds: 30
    DeadlineSeconds: 15
  Slow:
    TTLSeconds: 900
    DeadlineSeconds: 90
  Cycle:
    MaxDurationSeconds: 180
  Cache:
    MaxTargets: 500                        # process-wide
    IdleTargetTTLSeconds: 3600             # process-wide
    ResponseTTLSeconds: 180
    MaxEntries: 500                        # process-wide
    MaxTotalBytes: 52428800                # process-wide
    MaxSnapshotBytesPerLane: 10485760
    MaxTotalSnapshotBytes: 104857600
    MaxInFlightCandidateBytes: 104857600
  Overload:
    RetryAfterSeconds: 5                   # process-wide
  Refresh:
    MaxConcurrentRefreshes: 16             # process-wide
    MaxConcurrentCyclesPerBmc: 8
  Crawl:
    BatchSize: 8
    MaxQueuedRequestsPerLane: 64           # process-wide
    # Consecutive Fast admissions favored over Slow once a slot frees AND
    # both are already queued for it â�� distinct from (and on top of) the
    # one TargetConcurrency slot always reserved for Fast above.
    FastBatchLimit: 4                      # process-wide
    MaxDepth: 4
  IO:
    MaxInFlightResponseBytes: 67108864     # process-wide
  Login:
    TimeoutSeconds: 60
    MaxAttempts: 3
  Request:
    TimeoutSeconds: 30
    MaxAttempts: 5
    BackoffBaseSeconds: 0.5
    BackoffCapSeconds: 30
  Logout:
    TimeoutSeconds: 60
  Shutdown:
    GraceSeconds: 30
  Debug:
    RootDirectory: /tmp/redfish-data       # process-wide
    WriteRawData: false                    # process-wide
    WriteNormalizedData: false             # process-wide
    MaxFileBytes: 5242880                  # process-wide
    MaxFilesPerTarget: 4                   # process-wide
    MaxTotalBytes: 104857600               # process-wide
    RetentionSeconds: 3600                 # process-wide
  Telemetry:
    MaxFutureSkewSeconds: 300
    MaxAgeSeconds: 3600
    MaxValuesReadPerReport: 50000
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
  - Name: PhysicalServer_LastPowerOutputWatts
    Description: 'physical server power supplie status'
    Type: Gauge
    Label: ["ServerAddress","HostName","Model","LineInputVoltage","LineInputVoltageType","PowerSupplyType","PowerOutputWatts","PowerCapacityWatts","Manufacturer","SerialNumber"]
    Datapoint: Power.PowerSupplies
    Result: LastPowerOutputWatts
  - Name: PhysicalServer_CPUUtilizationPercent
    Description: 'physical server cpu utilization percent'
    Type: Gauge
    Label: ["ServerAddress","HostName"]
    Datapoint: Common
    Result: CPUUtil
  - Name: PhysicalServer_JitterCount
    Description: 'physical server jitter count'
    Type: Gauge
    Label: ["ServerAddress","HostName"]
    Datapoint: Common
    Result: JitterCount
  - Name: PhysicalServer_MemoryBusUtilPercent
    Description: 'physical server memory bus utilization percent'
    Type: Gauge
    Label: ["ServerAddress","HostName"]
    Datapoint: Common
    Result: MemoryBusUtil
{{- end }}