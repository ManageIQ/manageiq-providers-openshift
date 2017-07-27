# Runs a refresh of 1 specified manager
#
# Requirements:
# 1. Add 'manageiq_performance' gem into your dev gemfile
# 2. Add OpenShift gem as a plugin
# 3. Add OpenShift provider into your ManageIQ
#
# Run from the the root ManageIQ repository as:
# bundle exec rails r plugins/manageiq-providers-openshift/spec/tools/benchmarking/refresh_manager.rb <manager_name>
#
# Parameters:
# ARGV[0] - name of the manager
# ARGV[1] - "true" if we want disconnect all the data from the manager, which simulates the first refresh
# ARGV[2] - "true" if we want to run also profiling, results wil lbe stored under tmp dir

require 'manageiq_performance'

manager_name   = ARGV[0] || "10.16.31.50"
disconnect_all = ARGV[1] == "true"
profile        = ARGV[2] == "true"

def refresh(manager_name)
  ems = ExtManagementSystem.find_by(:name => manager_name)

  _, timings = Benchmark.realtime_block(:ems_total_refresh) do
    EmsRefresh.refresh(ems)
  end

  timings
end

# Show all the SQL queries on the STDERR, will show them even if we redirect the output with >
ActiveRecord::Base.logger = Logger.new(STDERR)

# Simulate first refresh by disconnecting all the records from the manager, by changing it's id
if disconnect_all
  ems = ExtManagementSystem.find_by(:name => manager_name)

  old_id = ems.id
  new_id = old_id + 1
  res_t  = ExtManagementSystem.to_s
  ExtManagementSystem.where(:id => old_id).update_all(:id => new_id)
  Endpoint.where(:resource_type => res_t, :resource_id => old_id).update_all(:resource_id => new_id)
  Authentication.where(:resource_type => res_t, :resource_id => old_id).update_all(:resource_id => new_id)
end

# Refresh and profile based on argv[2]
if profile
  ManageIQPerformance.profile do
    timings = refresh(manager_name)
  end
else
  timings = refresh(manager_name)
end

puts "Finished #{Time.now.utc} #{timings}"
