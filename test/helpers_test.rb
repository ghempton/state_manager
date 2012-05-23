require 'helper'

class ItemStates < StateManager::Base
  state :default do
    event :do_inner, :transitions_to => 'root.outer1.inner'
  end
  state :root do
    state :outer1 do
      event :next, :transitions_to => 'outer2.inner'
      state :inner do
        event :next, :transitions_to => 'inner2'
      end
      state :inner2
    end
    state :outer2 do
      state :inner do
      end
    end
  end
end

class Item
  attr_accessor :state
  extend StateManager::Helpers

  stateful :state, ItemStates
end

class HelpersTest < Test::Unit::TestCase

  def setup
    @item = Item.new
    @item_states = ItemStates.new(@item)
  end

  def helpers_test(target)
    assert target.default?
    assert !target.root?
    assert !target.root_outer1?
    assert !target.root_outer1_inner?
    assert target.can_do_inner?
    assert !target.can_next?

    target.do_inner!

    assert target.root?
    assert target.root_outer1?
    assert target.root_outer1_inner?
    assert !target.root_outer2_inner?
    assert target.can_next?
    
    target.next!

    assert target.root_outer1_inner2?
    assert target.can_next?

    target.next!

    assert target.root_outer2_inner?
    assert !target.can_next?
  end
  
  def test_base_helpers
    helpers_test(@item_states)
  end

  def test_object_helpers
    helpers_test(@item)
  end

end
