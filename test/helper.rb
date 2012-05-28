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
require 'statemanager'

class Test::Unit::TestCase

  def assert_state(path, state_manager=nil, message=nil)
    if state_manager.is_a? String
      message = state_manager
      state_manager = nil
    end
    state_manager ||= @state
    assert_equal path, state_manager.current_state.path
  end

end