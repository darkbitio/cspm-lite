# frozen_string_literal: true

require 'pry'

class MetricsExporter

  def initialize
     puts "Metrics Export"

     list_to_export = get_list_to_export
     list_to_export = ["2021-05-12"]
     export_metrics(list_to_export)
  end

  private

  def export_metrics(list_to_export)
    # for each missing findings file,
    list_to_export.each do |export_date|
       # Get combined file path
       findings_file = get_findings_file_path(export_date)
       next unless File.exists?(findings_file)

       metrics_file = get_metrics_file_path(export_date)
       generate_metrics_export(findings_file, metrics_file, export_date)
    end
  end

  private
  def generate_metrics_export(findings_file, metrics_file, export_date)
    puts "Generating metrics file #{metrics_file} from #{findings_file}"
    metrics = "".dup
    timestamp = Time.parse(export_date).getutc.to_i
    json = JSON.parse(File.read(findings_file))
    raise "Invalid format" if json['results'].nil?

    json['results'].each do |result|
      control = result['control'].downcase ||= 'empty-control'
      platform = result['platform'].downcase ||= 'empty-platform'
      category = result['category'].downcase ||= 'empty-category'
      resource_type = result['resource'].downcase ||= 'empty-resource-type'
      title = result['title'] ||= 'empty-title'
      title = title .gsub(/\"/, '')
      severity = ((result['severity'] ||= 0) * 10).to_i
      effort = ((result['effort'] ||= 0) * 10).to_i
      resources = result['resources'] ||= []
      resources.each do |resource|
        resource_name = resource['resource'] ||= "Placeholder"
        numstatus = 2
        status = resource['status'] ||= 2
        if status == "passed"
          numstatus = 0
        elsif status == "failed"
          numstatus = 1
        end
        metrics.concat("opencspm_resource_export{control_id=\"#{control}\",platform=\"#{platform}\",category=\"#{category}\",resource_type=\"#{resource_type}\",title=\"#{title}\",severity=\"#{severity}\",effort=\"#{effort}\",resource_name=\"#{resource_name}\",status=\"#{status}\"} #{numstatus} #{timestamp}\n")
      end
    end
    File.open(metrics_file, 'w') { |file| file.write(metrics) }
  end

  def get_metrics_file_path(export_date)
    "#{Dir.pwd}/data/metrics/#{export_date}.metrics"
  end

  def get_findings_file_path(export_date)
    "#{Dir.pwd}/data/findings/#{export_date}.findings"
  end

  def get_list_to_export
     # look up combined export directory, get list of files not in the findings data directory
     findings_list = Dir.glob('./data/findings/*.findings').map {|item| File.basename(item).gsub(/.findings$/,"") }
     metrics_list = Dir.glob('./data/metrics/*.metrics').map {|item| File.basename(item).gsub(/.metrics$/,"") }
     # Return an array of the diff/missing metrics dates
     findings_list.sort - metrics_list.sort
  end

end
