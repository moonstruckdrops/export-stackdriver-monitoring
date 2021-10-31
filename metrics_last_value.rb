require "bundler"
Bundler.require
require "opencensus"
require "opencensus/stackdriver"
require "google/cloud/monitoring/v3"

sidekiq_processed_measure = OpenCensus::Stats.create_measure_int(
  name: "sidekiq_processed",
  unit: "COUNT",
  description: "size of processed job"
)

sidekiq_processed_last_value_aggregation = OpenCensus::Stats.create_last_value_aggregation

# MEMO: ここのnameが最終的にtypeで使用されるもの
sidekiq_processed_view = OpenCensus::Stats::View.new(
  name: "sidekiq/processed",
  measure: sidekiq_processed_measure,
  aggregation: sidekiq_processed_last_value_aggregation,
  description: "sidekiq job processed count.",
  columns: ["queue"]
)

measurement = sidekiq_processed_view.measure.create_measurement(value: 73639, tags: { "queue" => "default" })

sidekiq_processed_view_data = OpenCensus::Stats::ViewData.new(sidekiq_processed_view, start_time: Time.now.utc)
sidekiq_processed_view_data.record(measurement)

converter = OpenCensus::Stats::Exporters::Stackdriver::Converter.new("sidekiq")
time_series = converter.convert_time_series "custom.googleapis.com", "global", { }, sidekiq_processed_view_data
time_data =  time_series.first
p time_data

p time_data.metric
p time_data.resource
p time_data.metric_kind
p time_data.value_type
p time_data.points
p time_data.unit #=> metric_descriptorを作成した時点で不要になった系かな

client = Google::Cloud::Monitoring::V3::MetricService::Client.new do |config|
  config.lib_name = "opencensus"
  config.lib_version = OpenCensus::Stackdriver::VERSION
end
project_name = client.project_path project: "pupupu-cafe"
p project_name
client.create_time_series(name: project_name, time_series: time_series)
