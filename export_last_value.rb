require "bundler"
Bundler.require
require "opencensus"
require "opencensus/stackdriver"
require "google/cloud/monitoring/v3"

# Plot対象のViewデータを設定する
sidekiq_processed_measure = OpenCensus::Stats.create_measure_int(
  name: "sidekiq_processed",
  unit: "COUNT",
#  description: "size of processed job"
)

# MEMO: ここのnameが最終的にtypeで使用されるもの
sidekiq_processed_view = OpenCensus::Stats::View.new(
  name: "sidekiq/processed",
  measure: sidekiq_processed_measure,
  aggregation: OpenCensus::Stats.create_last_value_aggregation,
#  description: "sidekiq job processed count.",
  columns: ["queue", "service"] #=> tagsのキーと紐づく
)

# ここで時系列データになる値を設定
# このとき、tagsのキーがviewとmeasureデータを紐付ける役割を担う
# tagsのvalueは対象の項目名(ターゲットと読み替えてもいいかも)
measurement = sidekiq_processed_view.measure.create_measurement(value: 74556639, tags: { "queue" => "default", "service"=>"metrics.pupupu.cafe" })
measurement_worker = sidekiq_processed_view.measure.create_measurement(value: 74566639, tags: { "queue" => "test_worker", "service"=>"metrics.pupupu.cafe" })

# 時系列データの紐付けを実施する
# 複数の登録を行うこともできる
sidekiq_processed_view_data = OpenCensus::Stats::ViewData.new(sidekiq_processed_view, start_time: Time.now.utc)
sidekiq_processed_view_data.record(measurement)
sidekiq_processed_view_data.record(measurement_worker)


# OpenCensusの時系列データをMonitoringAPIのTimeSeriesに変換する
# 1つめの引数は、OpenCensusのview名をTimeSeriesのmetricsに付与する名前に変換する際のprefixとなる(ほとんど固定値でよい)
# 2つめの引数は、対応するリソースタイプを設定するが、以下から決定する必要がある(該当するものがなければglobal)
# https://cloud.google.com/monitoring/api/resources
# 3つめの引数は、以下にあたるものっぽいが、最初の設定時点でデータがなければ実は登録できない(なんならAPI実行でエラーになる)
# この内容はReadOnlyっぽいので、すでに決まっている内容を使用するという形になる
# https://cloud.google.com/monitoring/api/ref_v3/rpc/google.api#google.api.MonitoredResource
# 4つめの引数は、変換対象のOpenCensusのViewData
converter = OpenCensus::Stats::Exporters::Stackdriver::Converter.new("sidekiq")
time_series = converter.convert_time_series "custom.googleapis.com", "global", { }, sidekiq_processed_view_data
p time_series
# API Clientは不変でよい
client = Google::Cloud::Monitoring::V3::MetricService::Client.new do |config|
  config.lib_name = "opencensus"
  config.lib_version = OpenCensus::Stackdriver::VERSION
end
project_name = client.project_path project: "pupupu-cafe"
client.create_time_series(name: project_name, time_series: time_series)
