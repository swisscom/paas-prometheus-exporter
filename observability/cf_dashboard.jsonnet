local g = import 'grafonnet/grafana.libsonnet';
local dashboard = g.dashboard;
local row = g.row;
local singlestat = g.singlestat;
local prometheus = g.prometheus;
local graphPanel = g.graphPanel;
local tablePanel = g.tablePanel;
local heatmapPanel = g.heatmapPanel;
local template = g.template;
local singlestatHeight = 30;

dashboard.new(
  'Cloud Foundry Space Summary',
  description='Summary metrics about containers/apps running on CF(iapc)',
  tags=['cloudfoundry'],
  time_from='now-12h',
  editable=true
)
// Variables Space, Org, AppName
.addTemplate(
  template.datasource(
    'datasource',
    'prometheus',
    '',
  )
)
.addTemplate(
  template.new(
    'Org',
    '$datasource',
    'label_values(cpu,organisation)',
    label='Org',
    refresh='time',
    sort=1,
  )
)
.addTemplate(
  template.new(
    'Space',
    '$datasource',
    'label_values(cpu{organisation="$Org"}, space)',
    label='Space',
    refresh='time',
    sort=1,
  )
)
.addTemplate(
  template.new(
    'AppName',
    '$datasource',
    'label_values(cpu{organisation="$Org",space="$Space"}, app)',
    label='AppName',
    refresh='time',
    sort=1,
  )
)
// Show general info/statistic about space
.addRow(
  row.new(
    title='Summary',
  )

  .addPanel(
    singlestat.new(
      'Total Number of app in $Org $Space',
      datasource='$datasource',
      height=singlestatHeight,
      span=2,
      sparklineShow=true,
    )
    .addTarget(
      prometheus.target(
        'count by (space,organisation) (cpu{space="$Space",organisation="$Org"})',
      )
    )
  )
  .addPanel(
    singlestat.new(
      'Total number of Crashed Apps in $Org $Space',
      datasource='$datasource',
      height=singlestatHeight,
      span=2,
      sparklineShow=true,
    )
    .addTarget(
      prometheus.target(
        'sum by (space, organisation) (crash{space="$Space",organisation="$Org"})',
      )
    )
  ).addPanel(
    singlestat.new(
      'Total Used Memory',
      datasource='$datasource',
      height=singlestatHeight,
      sparklineShow=true,
      span=2,
      format='bytes'
    )
    .addTarget(
       prometheus.target(
        'sum(memory_bytes{organisation="$Org",space="$Space"})',
      )
    )
  ).addPanel(
     singlestat.new(
      'Memory Utilisation',
      description='Used vs allocated/declared in %',
      datasource='$datasource',
      height=singlestatHeight,
      sparklineShow=true,
      span=2,
      format='percent'
    )
    .addTarget(
       prometheus.target(
        'sum(memory_utilization{organisation="$Org",space="$Space"}) / 100',
      )
    )
  ).addPanel(
     singlestat.new(
      'Total Disk',
      datasource='$datasource',
      height=singlestatHeight,
      sparklineShow=true,
      span=2,
      format='bytes'
    )
    .addTarget(
       prometheus.target(
        'sum(disk_bytes{organisation="$Org",space="$Space"})',
      )
    )
  ).addPanel(
     singlestat.new(
      'Disk Utilisation',
      description='Used vs allocated/declared in %',
      datasource='$datasource',
      height=singlestatHeight,
      sparklineShow=true,
      span=2,
      format='percent'
    )
    .addTarget(
       prometheus.target(
        'sum(disk_utilization{organisation="$Org",space="$Space"}) / 100',
      )
    )
  )
)
// show Utilisation per app
.addRow(
   row.new(
    title='Apps Utilisation'
  )
  .addPanel(
     graphPanel.new(
      'Top 10 apps by cpu utilisation in $Org $Space',
      datasource='$datasource',
      span=3,
    )
    .addTarget(
       prometheus.target(
        'topk(10,sum without (exported_instance) (cpu{organisation="$Org",space="$Space"}))',
        legendFormat='{{app}}'
      )
    )
  )
  .addPanel(
     graphPanel.new(
      'Top 10 apps by memory utilisation in $Org $Space',
      datasource='$datasource',
      span=3,
    )
    .addTarget(
       prometheus.target(
        'topk(10,sum without (exported_instance) (memory_utilization{organisation="$Org",space="$Space"}))',
        legendFormat='{{app}}'
      )
    )
  ).addPanel(
     graphPanel.new(
      'Bottom 10 apps by memory utilisation in $Org $Space',
      description='You may review the memory allocation in the cf manifests for those apps in order to reduce bill',
      datasource='$datasource',
      span=3,
    )
    .addTarget(
       prometheus.target(
        'bottomk(10,sum without (exported_instance) (memory_utilization{organisation="$Org",space="$Space"}))',
        legendFormat='{{app}}'
      )
    )
  )
  .addPanel(
     graphPanel.new(
      'Top 10 apps by disk utilisation in $Org $Space',
      description='You may review the disk allocation in cf manifests for those apps in order to reduce bill',
      datasource='$datasource',
      span=3,
    )
    .addTarget(
       prometheus.target(
        'bottomk(10,sum without (exported_instance) (disk_utilization{organisation="$Org",space="$Space"}))',
        legendFormat='{{app}}'
      )
    )
  )
)
//add row for single app performance
.addRow(
   row.new(
    title='Single App Overview'
  )

  .addPanel(
     graphPanel.new(
      '5m requests Rate $AppName',
      datasource='$datasource',
      span=12,
    )
    .addTarget(
       prometheus.target(
        'sum without (exported_instance) (rate(requests{space="$Space",organisation="$Org",app="$AppName",status_range!="0xx"}[5m]))',
        legendFormat='{{status_range}}'

      )
    )
  )
   .addPanel(
     graphPanel.new(
      'CPU,memory , disk utilisation for $AppName',
      datasource='$datasource',
      span=12,
    )
    .addTarget(
       prometheus.target(
        'rate(cpu{app="$AppName"}[5m])',
        legendFormat='cpu InstanceNum{{ exported_instance }}'
      )
    )
  .addTarget(
     prometheus.target(
      'rate(memory_utilization{app="$AppName"}[5m])',
      legendFormat='memory InstanceNum{{ exported_instance }}'
    )
  )
   .addTarget(
     prometheus.target(
      'rate(disk_utilization{app="$AppName"}[5m])',
      legendFormat='disk InstanceNum{{ exported_instance }}'
    )
  )

  )
  .addPanel(
     heatmapPanel.new(
      '90% latency',
      datasource='$datasource',
     span=12
    )
    .addTarget(
       prometheus.target(
        'histogram_quantile(0.9, sum  without (exported_instance) (rate(response_time_bucket{app="$AppName"}[5m])))'
      )
    )
  )
)

