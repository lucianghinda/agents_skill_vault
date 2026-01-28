# frozen_string_literal: true

require "agents_skill_vault"

require "minitest/autorun"
require "mocha/minitest"

module TestHelper
  def self.temp_vault_path
    File.join(Dir.tmpdir, "vault_test_#{Time.now.to_i}_#{rand(1000)}")
  end
end
