require "bundler"
Bundler.require
require "opencensus"
require "opencensus/stackdriver"

sidekiq_processed_measure = OpenCensus::Stats.create_measure_int(
  name: "sidekiq_processed",
  unit: "COUNT",
  description: "size of processed job"
)

sidekiq_processed_distribution = OpenCensus::Stats.create_distribution_aggregation(
  [7822]
)
sidekiq_processed_last_value_aggregation = OpenCensus::Stats.create_last_value_aggregation

#a = OpenCensus::Stats.create_last_value_aggregation.create_aggregation_data
#p a
#p a.add(100, Time.now.utc)
#p a

# MEMO: ここのnameが最終的にtypeで使用されるもの
sidekiq_processed_view = OpenCensus::Stats::View.new(
  name: "sidekiq",
  measure: sidekiq_processed_measure,
  aggregation: sidekiq_processed_last_value_aggregation,#sidekiq_processed_distribution,
  description: "sidekiq job processed count.",
  columns: ["sidekiq/processed"]
)



sidekiq_processed_view_data = OpenCensus::Stats::ViewData.new sidekiq_processed_view, start_time: Time.now.utc
p sidekiq_processed_view_data
converter = OpenCensus::Stats::Exporters::Stackdriver::Converter.new("test")
# p "sidekiq_processed_view"
# p sidekiq_processed_view
# p ""
#  
# p "convert_metric_descriptor"
# p converter.convert_metric_descriptor(sidekiq_processed_view, nil)
# p ""
#  
# p "convert_time_series"
# p sidekiq_processed_view_data
# p ""
measurement = sidekiq_processed_view.measure.create_measurement value: 1000, tags: {  "sidekiq/processed" => "measure_column" }
p measurement
#sidekiq_processed_view_data.record measurement
#p sidekiq_processed_view_data.view
#p sidekiq_processed_view_data.data
#p ""
# MEMO
# metric_prefixは固定の内容で良さそう(なぜなら指定した内容で始める必要があるため)
p converter.convert_metric_value_type sidekiq_processed_view
time_series = converter.convert_time_series "custom.googleapis.com", "custom.googleapis.com/sidekiq", {"resource_labels" => "labels" }, sidekiq_processed_view_data
p time_series
time_data =  time_series.first
p time_data
#p time_data.metric
p time_data.resource
p time_data.metric_kind
p time_data.value_type
p time_data.points
p time_data.unit #=> metric_descriptorを作成した時点で不要になった系かな
