require 'pry'
require 'yaml'
require 'json'

class CspmFormatter < RSpec::Core::Formatters::BaseFormatter
  RSpec::Core::Formatters.register self, :close, :dump_summary

  attr_accessor :output_content

  def initialize(output)
    @output_content = output
  end

  def dump_summary(notification)
    findings = []
    notification.examples.each do |example|
      finding = Hash.new
      finding['control_pack'] = example.metadata[:example_group][:control_pack] || File.basename(File.dirname(example.metadata[:file_path]))
      finding['control_id'] = example.metadata[:example_group][:control_id]
      finding['resource'] = example.metadata[:example_group][:description]
      finding['status'] = example.metadata[:execution_result].status.to_s
      findings << finding
    end
    results = []
    findings.group_by{ |r| { "control_pack" => r['control_pack'], "control_id" => r['control_id']} }.each do |c,res|
      c['resources'] = res.map { |r| { "name" => r['resource'], "status" => r['status'] } }
      results << c
    end
    File.open('/tmp/results', 'w') { |file| file.write(results.to_json) }
  end

  def close(notification)
  end
end
