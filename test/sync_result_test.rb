# frozen_string_literal: true

require "test_helper"
require "minitest/autorun"

class SyncResultTest < Minitest::Test
  def test_success_result
    result = AgentsSkillVault::SyncResult.new(success: true, changes: true)

    assert result.success?
    assert result.changes?
    assert_nil result.error
  end

  def test_failure_result
    result = AgentsSkillVault::SyncResult.new(success: false, error: "Network error")

    refute result.success?
    assert_equal "Network error", result.error
  end

  def test_success_without_changes
    result = AgentsSkillVault::SyncResult.new(success: true, changes: false)

    assert result.success?
    refute result.changes?
  end

  def test_success_result_with_error_nil
    result = AgentsSkillVault::SyncResult.new(success: true, changes: true)

    assert result.success?
    assert result.changes?
    assert_nil result.error
  end

  def test_failure_result_without_changes
    result = AgentsSkillVault::SyncResult.new(success: false, changes: false, error: "Failed")

    refute result.success?
    refute result.changes?
    assert_equal "Failed", result.error
  end

  def test_failure_result_with_changes
    result = AgentsSkillVault::SyncResult.new(success: false, changes: true, error: "Partial failure")

    refute result.success?
    assert result.changes?
    assert_equal "Partial failure", result.error
  end

  def test_default_changes_is_false
    result = AgentsSkillVault::SyncResult.new(success: true)

    assert result.success?
    refute result.changes?
  end

  def test_empty_error_message
    result = AgentsSkillVault::SyncResult.new(success: false, error: "")

    refute result.success?
    assert_equal "", result.error
  end

  def test_nil_error_on_failure
    result = AgentsSkillVault::SyncResult.new(success: false, error: nil)

    refute result.success?
    assert_nil result.error
  end

  def test_changes_true_explicitly
    result = AgentsSkillVault::SyncResult.new(success: true, changes: true)

    assert result.success?
    assert result.changes?
  end

  def test_access_all_attributes
    result = AgentsSkillVault::SyncResult.new(success: true, changes: true, error: nil)

    assert_equal true, result.success
    assert_equal true, result.changes
    assert_nil result.error
  end
end
