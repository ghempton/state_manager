require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'test/unit'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'pry'
require 'delayed_job_active_record'
require 'state_manager'
require 'timecop'

class Test::Unit::TestCase

  def assert_state(path, state_manager=nil, message=nil)
    if state_manager.is_a? String
      message = state_manager
      state_manager = nil
    end
    state_manager ||= @resource.state_manager
    assert_equal path, state_manager.current_state.path
  end

  def teardown
    ActiveRecord::Base.connection.disconnect!
    Timecop.return
  end

  # Convince delayed job that the duration has passed and perform any jobs that
  # need doing
  def time_warp(duration)
    Timecop.travel(duration.from_now)
    Delayed::Worker.new.work_off

    # Check for any errors inside the delayed job
    jobs = Delayed::Job.where('last_error IS NOT NULL')
    error = jobs.last && jobs.last.last_error
    raise "Delayed job error: #{error}" if error
  end

end