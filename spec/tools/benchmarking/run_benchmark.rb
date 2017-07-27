# Runs refreshes wit all supported combinations of refresh settings and stores the peak memory and timings
# ========================================================================================================
#
# Requirements:
# 1. Add 'manageiq_performance' gem into your dev gemfile
# 2. Add OpenShift gem as a plugin
# 3. Add OpenShift provider into your ManageIQ
#
# Run from the the root ManageIQ repository as:
# bundle exec rails r plugins/manageiq-providers-openshift/spec/tools/benchmarking/run_benchmark.rb > benchmark_output
# Or with provider name specified as first arg:
# bundle exec rails r plugins/manageiq-providers-openshift/spec/tools/benchmarking/run_benchmark.rb <provider_name> > benchmark_output

memusg_script_name = "memusg_python"
manager_name       = ARGV[0] || "openshift_manager_name"
path               = File.dirname(__FILE__)

puts "Starting benchmark"

options_array = [
  {
    :inventory_object_refresh => true,
    :inventory_collections    => {:saver_strategy => :batch}
  }, {
    :inventory_object_refresh => true,
    :inventory_collections    => {:saver_strategy => :default}
  }, {
    :inventory_object_refresh => false,
    :inventory_collections    => {:saver_strategy => nil}
  }
]

options_array.each do |options|
  # change the settings
  settings = YAML.load(VMDB::Config.get_file)
  settings[:ems_refresh][:openshift].merge!(options)
  VMDB::Config.save_file(YAML.dump(settings))

  # # debug puts for verifying changed settings
  # manager = ExtManagementSystem.find_by(:name => manager_name)
  # settings = Settings.ems_refresh[manager.class.ems_type]
  # puts "Changed settings #{settings}"

  # 1st refresh
  puts "============================================================================="
  puts "--------- 1st refresh #{options} --------------------------------"
  system("./#{memusg_script_name} bundle exec rails r #{path}/refresh_manager.rb #{manager_name} true")

  # 2nd refresh
  sleep(10)
  puts "--------- 2nd refresh #{options} --------------------------------"
  system("./#{memusg_script_name} bundle exec rails r #{path}/refresh_manager.rb #{manager_name}")
end

puts "Finished"
