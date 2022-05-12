local g = import 'grafonnet/grafana.libsonnet';
local u = import 'utils.libsonnet';
local c = (import '../mixin.libsonnet')._config;

{
  grafanaDashboards+:: {
    'osds-overview.json':
      local OsdOverviewStyle(alias, pattern, type, unit) =
        u.addStyle(alias, null, [
          'rgba(245, 54, 54, 0.9)',
          'rgba(237, 129, 40, 0.89)',
          'rgba(50, 172, 45, 0.97)',
        ], 'YYYY-MM-DD HH:mm:ss', 2, 1, pattern, [], type, unit, []);
      local OsdOverviewGraphPanel(alias,
                                  title,
                                  description,
                                  formatY1,
                                  labelY1,
                                  min,
                                  expr,
                                  legendFormat1,
                                  x,
                                  y,
                                  w,
                                  h) =
        u.graphPanelSchema(alias,
                           title,
                           description,
                           'null',
                           false,
                           formatY1,
                           'short',
                           labelY1,
                           null,
                           min,
                           1,
                           '$datasource')
        .addTargets(
          [u.addTargetSchema(expr, legendFormat1)]
        ) + { gridPos: { x: x, y: y, w: w, h: h } };
      local OsdOverviewPieChartPanel(alias, description, title) =
        u.addPieChartSchema(alias,
                            '$datasource',
                            description,
                            'Under graph',
                            'pie',
                            title,
                            'current');
      local OsdOverviewSingleStatPanel(colors,
                                       format,
                                       title,
                                       description,
                                       valueName,
                                       colorValue,
                                       gaugeMaxValue,
                                       gaugeShow,
                                       sparkLineShow,
                                       thresholds,
                                       expr,
                                       x,
                                       y,
                                       w,
                                       h) =
        u.addSingleStatSchema(
          colors,
          '$datasource',
          format,
          title,
          description,
          valueName,
          colorValue,
          gaugeMaxValue,
          gaugeShow,
          sparkLineShow,
          thresholds
        )
        .addTarget(
          u.addTargetSchema(expr)
        ) + { gridPos: { x: x, y: y, w: w, h: h } };

      u.dashboardSchema(
        'OSD Overview',
        '',
        'lo02I1Aiz',
        'now-1h',
        '10s',
        16,
        c.dashboardTags,
        '',
        {
          refresh_intervals: ['5s', '10s', '30s', '1m', '5m', '15m', '30m', '1h', '2h', '1d'],
          time_options: ['5m', '15m', '1h', '6h', '12h', '24h', '2d', '7d', '30d'],
        }
      )
      .addAnnotation(
        u.addAnnotationSchema(
          1,
          '-- Grafana --',
          true,
          true,
          'rgba(0, 211, 255, 1)',
          'Annotations & Alerts',
          'dashboard'
        )
      )
      .addRequired(
        type='grafana', id='grafana', name='Grafana', version='5.0.0'
      )
      .addRequired(
        type='panel', id='grafana-piechart-panel', name='Pie Chart', version='1.3.3'
      )
      .addRequired(
        type='panel', id='graph', name='Graph', version='5.0.0'
      )
      .addRequired(
        type='panel', id='table', name='Table', version='5.0.0'
      )
      .addTemplate(
        g.template.datasource('datasource', 'prometheus', 'default', label='Data Source')
      )
      .addTemplate(
        u.addClusterTemplate()
      )
      .addTemplate(
        u.addJobTemplate()
      )
      .addPanels([
        OsdOverviewGraphPanel(
          { '@95%ile': '#e0752d' },
          'OSD Read Latencies',
          '',
          'ms',
          null,
          '0',
          |||
            avg (
              rate(ceph_osd_op_r_latency_sum{%(matchers)s}[$__rate_interval]) /
                on (ceph_daemon) rate(ceph_osd_op_r_latency_count{%(matchers)s}[$__rate_interval]) * 1000
            )
          ||| % u.matchers(),
          'AVG read',
          0,
          0,
          8,
          8
        )
        .addTargets(
          [
            u.addTargetSchema(
              |||
                max(
                  rate(ceph_osd_op_r_latency_sum{%(matchers)s}[$__rate_interval]) /
                  on (ceph_daemon) rate(ceph_osd_op_r_latency_count{%(matchers)s}[$__rate_interval]) * 1000
                )
              ||| % u.matchers(),
              'MAX read'
            ),
            u.addTargetSchema(
              |||
                quantile(0.95,
                  (
                    rate(ceph_osd_op_r_latency_sum{%(matchers)s}[$__rate_interval]) /
                      on (ceph_daemon) rate(ceph_osd_op_r_latency_count{%(matchers)s}[$__rate_interval])
                      * 1000
                  )
                )
              ||| % u.matchers(),
              '@95%ile'
            ),
          ],
        ),
        u.addTableSchema(
          '$datasource',
          "This table shows the osd's that are delivering the 10 highest read latencies within the cluster",
          { col: 2, desc: true },
          [
            OsdOverviewStyle('OSD ID', 'ceph_daemon', 'string', 'short'),
            OsdOverviewStyle('Latency (ms)', 'Value', 'number', 'none'),
            OsdOverviewStyle('', '/.*/', 'hidden', 'short'),
          ],
          'Highest READ Latencies',
          'table'
        )
        .addTarget(
          u.addTargetSchema(
            |||
              topk(10,
                (sort(
                  (
                    rate(ceph_osd_op_r_latency_sum{%(matchers)s}[$__rate_interval]) /
                      on (ceph_daemon) rate(ceph_osd_op_r_latency_count{%(matchers)s}[$__rate_interval]) *
                      1000
                  )
                ))
              )
            ||| % u.matchers(),
            '',
            'table',
            1,
            true
          )
        ) + { gridPos: { x: 8, y: 0, w: 4, h: 8 } },
        OsdOverviewGraphPanel(
          {
            '@95%ile write': '#e0752d',
          },
          'OSD Write Latencies',
          '',
          'ms',
          null,
          '0',
          |||
            avg(
              rate(ceph_osd_op_w_latency_sum{%(matchers)s}[$__rate_interval]) /
                on (ceph_daemon) rate(ceph_osd_op_w_latency_count{%(matchers)s}[$__rate_interval])
                * 1000
            )
          ||| % u.matchers(),
          'AVG write',
          12,
          0,
          8,
          8
        )
        .addTargets(
          [
            u.addTargetSchema(
              |||
                max(
                  rate(ceph_osd_op_w_latency_sum{%(matchers)s}[$__rate_interval]) /
                    on (ceph_daemon) rate(ceph_osd_op_w_latency_count{%(matchers)s}[$__rate_interval]) *
                    1000
                )
              ||| % u.matchers(), 'MAX write'
            ),
            u.addTargetSchema(
              |||
                quantile(0.95, (
                  rate(ceph_osd_op_w_latency_sum{%(matchers)s}[$__rate_interval]) /
                    on (ceph_daemon) rate(ceph_osd_op_w_latency_count{%(matchers)s}[$__rate_interval]) *
                    1000
                ))
              ||| % u.matchers(), '@95%ile write'
            ),
          ],
        ),
        u.addTableSchema(
          '$datasource',
          "This table shows the osd's that are delivering the 10 highest write latencies within the cluster",
          { col: 2, desc: true },
          [
            OsdOverviewStyle(
              'OSD ID', 'ceph_daemon', 'string', 'short'
            ),
            OsdOverviewStyle('Latency (ms)', 'Value', 'number', 'none'),
            OsdOverviewStyle('', '/.*/', 'hidden', 'short'),
          ],
          'Highest WRITE Latencies',
          'table'
        )
        .addTarget(
          u.addTargetSchema(
            |||
              topk(10,
                (sort(
                  (rate(ceph_osd_op_w_latency_sum{%(matchers)s}[$__rate_interval]) /
                    on (ceph_daemon) rate(ceph_osd_op_w_latency_count{%(matchers)s}[$__rate_interval]) *
                    1000)
                ))
              )
            ||| % u.matchers(),
            '',
            'table',
            1,
            true
          )
        ) + { gridPos: { x: 20, y: 0, w: 4, h: 8 } },
        OsdOverviewPieChartPanel(
          {}, '', 'OSD Types Summary'
        )
        .addTarget(
          u.addTargetSchema('count by (device_class) (ceph_osd_metadata{%(matchers)s})' % u.matchers(), '{{device_class}}')
        ) + { gridPos: { x: 0, y: 8, w: 4, h: 8 } },
        OsdOverviewPieChartPanel(
          { 'Non-Encrypted': '#E5AC0E' }, '', 'OSD Objectstore Types'
        )
        .addTarget(
          u.addTargetSchema(
            'count(ceph_bluefs_wal_total_bytes{%(matchers)s})' % u.matchers(), 'bluestore', 'time_series', 2
          )
        )
        .addTarget(
          u.addTargetSchema(
            'absent(ceph_bluefs_wal_total_bytes%(matchers)s) * count(ceph_osd_metadata{%(matchers)s})' % u.matchers(), 'filestore', 'time_series', 2
          )
        ) + { gridPos: { x: 4, y: 8, w: 4, h: 8 } },
        OsdOverviewPieChartPanel(
          {}, 'The pie chart shows the various OSD sizes used within the cluster', 'OSD Size Summary'
        )
        .addTarget(u.addTargetSchema(
          'count(ceph_osd_stat_bytes{%(matchers)s} < 1099511627776)' % u.matchers(), '<1TB', 'time_series', 2
        ))
        .addTarget(u.addTargetSchema(
          'count(ceph_osd_stat_bytes{%(matchers)s} >= 1099511627776 < 2199023255552)' % u.matchers(), '<2TB', 'time_series', 2
        ))
        .addTarget(u.addTargetSchema(
          'count(ceph_osd_stat_bytes{%(matchers)s} >= 2199023255552 < 3298534883328)' % u.matchers(), '<3TB', 'time_series', 2
        ))
        .addTarget(u.addTargetSchema(
          'count(ceph_osd_stat_bytes{%(matchers)s} >= 3298534883328 < 4398046511104)' % u.matchers(), '<4TB', 'time_series', 2
        ))
        .addTarget(u.addTargetSchema(
          'count(ceph_osd_stat_bytes{%(matchers)s} >= 4398046511104 < 6597069766656)' % u.matchers(), '<6TB', 'time_series', 2
        ))
        .addTarget(u.addTargetSchema(
          'count(ceph_osd_stat_bytes{%(matchers)s} >= 6597069766656 < 8796093022208)' % u.matchers(), '<8TB', 'time_series', 2
        ))
        .addTarget(u.addTargetSchema(
          'count(ceph_osd_stat_bytes{%(matchers)s} >= 8796093022208 < 10995116277760)' % u.matchers(), '<10TB', 'time_series', 2
        ))
        .addTarget(u.addTargetSchema(
          'count(ceph_osd_stat_bytes{%(matchers)s} >= 10995116277760 < 13194139533312)' % u.matchers(), '<12TB', 'time_series', 2
        ))
        .addTarget(u.addTargetSchema(
          'count(ceph_osd_stat_bytes{%(matchers)s} >= 13194139533312)' % u.matchers(), '<12TB+', 'time_series', 2
        )) + { gridPos: { x: 8, y: 8, w: 4, h: 8 } },
        g.graphPanel.new(bars=true,
                         datasource='$datasource',
                         title='Distribution of PGs per OSD',
                         x_axis_buckets=20,
                         x_axis_mode='histogram',
                         x_axis_values=['total'],
                         formatY1='short',
                         formatY2='short',
                         labelY1='# of OSDs',
                         min='0',
                         nullPointMode='null')
        .addTarget(u.addTargetSchema(
          'ceph_osd_numpg{%(matchers)s}' % u.matchers(), 'PGs per OSD', 'time_series', 1, true
        )) + { gridPos: { x: 12, y: 8, w: 8, h: 8 } },
        OsdOverviewSingleStatPanel(
          ['#d44a3a', '#299c46'],
          'percentunit',
          'OSD onode Hits Ratio',
          'This gauge panel shows onode Hits ratio to help determine if increasing RAM per OSD could help improve the performance of the cluster',
          'current',
          true,
          1,
          true,
          false,
          '.75',
          |||
            sum(ceph_bluestore_onode_hits{%(matchers)s}) / (
              sum(ceph_bluestore_onode_hits{%(matchers)s}) +
              sum(ceph_bluestore_onode_misses{%(matchers)s})
            )
          ||| % u.matchers(),
          20,
          8,
          4,
          8
        ),
        u.addRowSchema(false,
                       true,
                       'R/W Profile') + { gridPos: { x: 0, y: 16, w: 24, h: 1 } },
        OsdOverviewGraphPanel(
          {},
          'Read/Write Profile',
          'Show the read/write workload profile overtime',
          'short',
          null,
          null,
          'round(sum(rate(ceph_pool_rd{%(matchers)s}[$__rate_interval])))' % u.matchers(),
          'Reads',
          0,
          17,
          24,
          8
        )
        .addTargets([u.addTargetSchema(
          'round(sum(rate(ceph_pool_wr{%(matchers)s}[$__rate_interval])))' % u.matchers(), 'Writes'
        )]),
      ]),
    'osd-device-details.json':
      local OsdDeviceDetailsPanel(title,
                                  description,
                                  formatY1,
                                  labelY1,
                                  expr1,
                                  expr2,
                                  legendFormat1,
                                  legendFormat2,
                                  x,
                                  y,
                                  w,
                                  h) =
        u.graphPanelSchema({},
                           title,
                           description,
                           'null',
                           false,
                           formatY1,
                           'short',
                           labelY1,
                           null,
                           null,
                           1,
                           '$datasource')
        .addTargets(
          [
            u.addTargetSchema(expr1,
                              legendFormat1),
            u.addTargetSchema(expr2, legendFormat2),
          ]
        ) + { gridPos: { x: x, y: y, w: w, h: h } };

      u.dashboardSchema(
        'OSD device details',
        '',
        'CrAHE0iZz',
        'now-3h',
        '',
        16,
        c.dashboardTags,
        '',
        {
          refresh_intervals: ['5s', '10s', '30s', '1m', '5m', '15m', '30m', '1h', '2h', '1d'],
          time_options: ['5m', '15m', '1h', '6h', '12h', '24h', '2d', '7d', '30d'],
        }
      )
      .addAnnotation(
        u.addAnnotationSchema(
          1,
          '-- Grafana --',
          true,
          true,
          'rgba(0, 211, 255, 1)',
          'Annotations & Alerts',
          'dashboard'
        )
      )
      .addRequired(
        type='grafana', id='grafana', name='Grafana', version='5.3.2'
      )
      .addRequired(
        type='panel', id='graph', name='Graph', version='5.0.0'
      )
      .addTemplate(
        g.template.datasource('datasource',
                              'prometheus',
                              'default',
                              label='Data Source')
      )
      .addTemplate(
        u.addClusterTemplate()
      )
      .addTemplate(
        u.addJobTemplate()
      )
      .addTemplate(
        u.addTemplateSchema('osd',
                            '$datasource',
                            'label_values(ceph_osd_metadata{%(matchers)s}, ceph_daemon)' % u.matchers(),
                            1,
                            false,
                            1,
                            'OSD',
                            '(.*)')
      )
      .addPanels([
        u.addRowSchema(
          false, true, 'OSD Performance'
        ) + { gridPos: { x: 0, y: 0, w: 24, h: 1 } },
        OsdDeviceDetailsPanel(
          '$osd Latency',
          '',
          's',
          'Read (-) / Write (+)',
          |||
            rate(ceph_osd_op_r_latency_sum{%(matchers)s, ceph_daemon=~"$osd"}[$__rate_interval]) /
              on (ceph_daemon) rate(ceph_osd_op_r_latency_count{%(matchers)s}[$__rate_interval])
          ||| % u.matchers(),
          |||
            rate(ceph_osd_op_w_latency_sum{%(matchers)s, ceph_daemon=~"$osd"}[$__rate_interval]) /
              on (ceph_daemon) rate(ceph_osd_op_w_latency_count{%(matchers)s}[$__rate_interval])
          ||| % u.matchers(),
          'read',
          'write',
          0,
          1,
          6,
          9
        )
        .addSeriesOverride(
          {
            alias: 'read',
            transform: 'negative-Y',
          }
        ),
        OsdDeviceDetailsPanel(
          '$osd R/W IOPS',
          '',
          'short',
          'Read (-) / Write (+)',
          'rate(ceph_osd_op_r{%(matchers)s, ceph_daemon=~"$osd"}[$__rate_interval])' % u.matchers(),
          'rate(ceph_osd_op_w{%(matchers)s, ceph_daemon=~"$osd"}[$__rate_interval])' % u.matchers(),
          'Reads',
          'Writes',
          6,
          1,
          6,
          9
        )
        .addSeriesOverride(
          { alias: 'Reads', transform: 'negative-Y' }
        ),
        OsdDeviceDetailsPanel(
          '$osd R/W Bytes',
          '',
          'bytes',
          'Read (-) / Write (+)',
          'rate(ceph_osd_op_r_out_bytes{%(matchers)s, ceph_daemon=~"$osd"}[$__rate_interval])' % u.matchers(),
          'rate(ceph_osd_op_w_in_bytes{%(matchers)s, ceph_daemon=~"$osd"}[$__rate_interval])' % u.matchers(),
          'Read Bytes',
          'Write Bytes',
          12,
          1,
          6,
          9
        )
        .addSeriesOverride({ alias: 'Read Bytes', transform: 'negative-Y' }),
        u.addRowSchema(
          false, true, 'Physical Device Performance'
        ) + { gridPos: { x: 0, y: 10, w: 24, h: 1 } },
        OsdDeviceDetailsPanel(
          'Physical Device Latency for $osd',
          '',
          's',
          'Read (-) / Write (+)',
          |||
            (
              label_replace(
                rate(node_disk_read_time_seconds_total{%(clusterMatcher)s}[$__rate_interval]) /
                  rate(node_disk_reads_completed_total{%(clusterMatcher)s}[$__rate_interval]),
                "instance", "$1", "instance", "([^:.]*).*"
              ) and on (instance, device) label_replace(
                label_replace(
                  ceph_disk_occupation_human{%(matchers)s, ceph_daemon=~"$osd"},
                  "device", "$1", "device", "/dev/(.*)"
                ), "instance", "$1", "instance", "([^:.]*).*"
              )
            )
          ||| % u.matchers(),
          |||
            (
              label_replace(
                rate(node_disk_write_time_seconds_total{%(clusterMatcher)s}[$__rate_interval]) /
                  rate(node_disk_writes_completed_total{%(clusterMatcher)s}[$__rate_interval]),
                "instance", "$1", "instance", "([^:.]*).*") and on (instance, device)
                label_replace(
                  label_replace(
                    ceph_disk_occupation_human{%(matchers)s, ceph_daemon=~"$osd"}, "device", "$1", "device", "/dev/(.*)"
                  ), "instance", "$1", "instance", "([^:.]*).*"
                )
              )
          ||| % u.matchers(),
          '{{instance}}/{{device}} Reads',
          '{{instance}}/{{device}} Writes',
          0,
          11,
          6,
          9
        )
        .addSeriesOverride(
          { alias: '/.*Reads/', transform: 'negative-Y' }
        ),
        OsdDeviceDetailsPanel(
          'Physical Device R/W IOPS for $osd',
          '',
          'short',
          'Read (-) / Write (+)',
          |||
            label_replace(
              rate(node_disk_writes_completed_total{%(clusterMatcher)s}[$__rate_interval]),
              "instance", "$1", "instance", "([^:.]*).*"
            ) and on (instance, device) label_replace(
              label_replace(
                ceph_disk_occupation_human{%(matchers)s, ceph_daemon=~"$osd"},
                "device", "$1", "device", "/dev/(.*)"
              ), "instance", "$1", "instance", "([^:.]*).*"
            )
          ||| % u.matchers(),
          |||
            label_replace(
              rate(node_disk_reads_completed_total{%(clusterMatcher)s}[$__rate_interval]),
              "instance", "$1", "instance", "([^:.]*).*"
            ) and on (instance, device) label_replace(
              label_replace(
                ceph_disk_occupation_human{%(matchers)s, ceph_daemon=~"$osd"},
                "device", "$1", "device", "/dev/(.*)"
              ), "instance", "$1", "instance", "([^:.]*).*"
            )
          ||| % u.matchers(),
          '{{device}} on {{instance}} Writes',
          '{{device}} on {{instance}} Reads',
          6,
          11,
          6,
          9
        )
        .addSeriesOverride(
          { alias: '/.*Reads/', transform: 'negative-Y' }
        ),
        OsdDeviceDetailsPanel(
          'Physical Device R/W Bytes for $osd',
          '',
          'Bps',
          'Read (-) / Write (+)',
          |||
            label_replace(
              rate(node_disk_read_bytes_total{%(clusterMatcher)s}[$__rate_interval]), "instance", "$1", "instance", "([^:.]*).*"
            ) and on (instance, device) label_replace(
              label_replace(
                ceph_disk_occupation_human{%(matchers)s, ceph_daemon=~"$osd"},
                "device", "$1", "device", "/dev/(.*)"
              ), "instance", "$1", "instance", "([^:.]*).*"
            )
          ||| % u.matchers(),
          |||
            label_replace(
              rate(node_disk_written_bytes_total{%(clusterMatcher)s}[$__rate_interval]), "instance", "$1", "instance", "([^:.]*).*"
            ) and on (instance, device) label_replace(
              label_replace(
                ceph_disk_occupation_human{%(matchers)s, ceph_daemon=~"$osd"},
                "device", "$1", "device", "/dev/(.*)"
              ), "instance", "$1", "instance", "([^:.]*).*"
            )
          ||| % u.matchers(),
          '{{instance}} {{device}} Reads',
          '{{instance}} {{device}} Writes',
          12,
          11,
          6,
          9
        )
        .addSeriesOverride(
          { alias: '/.*Reads/', transform: 'negative-Y' }
        ),
        u.graphPanelSchema(
          {},
          'Physical Device Util% for $osd',
          '',
          'null',
          false,
          'percentunit',
          'short',
          null,
          null,
          null,
          1,
          '$datasource'
        )
        .addTarget(u.addTargetSchema(
          |||
            label_replace(
              rate(node_disk_io_time_seconds_total{%(clusterMatcher)s}[$__rate_interval]),
              "instance", "$1", "instance", "([^:.]*).*"
            ) and on (instance, device) label_replace(
              label_replace(
                ceph_disk_occupation_human{%(matchers)s, ceph_daemon=~"$osd"}, "device", "$1", "device", "/dev/(.*)"
              ), "instance", "$1", "instance", "([^:.]*).*"
            )
          ||| % u.matchers(),
          '{{device}} on {{instance}}'
        )) + { gridPos: { x: 18, y: 11, w: 6, h: 9 } },
      ]),
  },
}
