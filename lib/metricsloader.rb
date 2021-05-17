# frozen_string_literal: true

require 'pry'

class MetricsLoader

  def initialize
     puts "Metrics Load"

     list_to_load = get_list_to_load
     load_metrics(list_to_load)
  end

  private

  def load_metrics(list_to_load)
    list_to_load.each do |metrics_file|
      metrics = File.read(metrics_file)
      uri = URI.parse("http://victoria:8428/api/v1/import/prometheus")
      header = {'Content-Type': 'text/plain'}
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri.request_uri, header)
      request.body = metrics
      puts "Status: #{http.request(request).code} when loading: #{metrics.lines.count} metrics from #{metrics_file}"
    end
  end

  def get_list_to_load
     Dir.glob("#{Dir.pwd}/data/metrics/*.metrics")
  end  

end
