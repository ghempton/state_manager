require 'helper'
require 'timecop'

class DelayedJobTest < Minitest::Test

  class ProjectStates < StateManager::Base
    initial_state 'unsubmitted.initial'
    state :unsubmitted do
      event :submit, :transitions_to => 'submitted'
      state :initial do
        event :remind, :transitions_to => 'reminded', :delay => 2.hours
      end
      state :reminded
    end
    state :submitted do
      event :accept, :transitions_to => 'accepted'
      event :auto_accept, :transitions_to => 'accepted', :delay => :delay
      event :reject, :transitions_to => 'rejected'
    end
    state :accepted do
      event :remind, :transitions_to => 'rejected'
    end
    state :rejected

    class Submitted
      def delay
        1.day
      end
    end
  end

  def exec(sql)
    ActiveRecord::Base.connection.execute sql
  end

  def setup
    ActiveRecord::Base.establish_connection(
      :adapter => "sqlite3",
      :database  => ":memory:" #"tmp/test"
    )

    ActiveRecord::Schema.define do
      create_table :projects do |t|
        t.string :title
        t.string :state
      end

      create_table :delayed_jobs, :force => true do |table|
        table.integer  :priority, :default => 0      # Allows some jobs to jump to the front of the queue
        table.integer  :attempts, :default => 0      # Provides for retries, but still fail eventually.
        table.text     :handler                      # YAML-encoded string of the object that will do work
        table.text     :last_error                   # reason for last failure (See Note below)
        table.datetime :run_at                       # When to run. Could be Time.zone.now for immediately, or sometime in the future.
        table.datetime :locked_at                    # Set when a client is working on this object
        table.datetime :failed_at                    # Set when all retries have failed (actually, by default, the record is deleted instead)
        table.string   :locked_by                    # Who is working on this object (if locked)
        table.string   :queue                        # The name of the queue this job is in
        table.timestamps
      end
    end

    exec "INSERT INTO projects VALUES(1, 'Project 1', NULL)"

  end

  class Project < ActiveRecord::Base
    extend StateManager::Resource
    state_manager
  end

  def test_delayed_event
    @resource = Project.find(1)
    assert_state 'unsubmitted.initial'
    assert_equal 0, Delayed::Job.count
    @resource.save
    assert_equal 1, Delayed::Job.count

    time_warp(4.hours)

    assert_equal 0, Delayed::Job.count
    @resource.reload
    assert_state 'unsubmitted.reminded'

    @resource.submit!

    assert_state 'submitted'

    time_warp(1.hour)

    assert_state 'submitted', 'should not have transitioned yet'
  end

  def test_expired_event
    @resource = Project.find(1)
    assert_state 'unsubmitted.initial'
    @resource.save
    assert_equal 1, Delayed::Job.count

    @resource.submit!

    assert_state 'submitted'

    time_warp(1.month)

    assert_equal 0, Delayed::Job.count
    assert_state 'submitted', 'should not have transitioned'
  end

  def test_event_name_clashes
    @resource = Project.find(1)
    @resource.save
    assert_state 'unsubmitted.initial'
    assert_equal 1, Delayed::Job.count

    @resource.submit!
    @resource.accept!

    assert_equal 2, Delayed::Job.count

    time_warp(1.month)

    assert_state 'accepted', 'remind event should not have been triggered'
  end

  def test_new_record
    @resource = Project.create
    assert_state 'unsubmitted.initial'
    time_warp(1.day)
    @resource.reload
    assert_state 'unsubmitted.reminded'
  end

end
