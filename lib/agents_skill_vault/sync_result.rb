# frozen_string_literal: true

module AgentsSkillVault
  # Immutable result object representing the outcome of a sync operation.
  #
  # Uses Ruby 3.2+ Data.define for a clean, immutable value object.
  #
  # @example Successful sync with changes
  #   result = SyncResult.new(success: true, changes: true)
  #   result.success?  # => true
  #   result.changes?  # => true
  #
  # @example Failed sync
  #   result = SyncResult.new(success: false, error: "Network error")
  #   result.success?  # => false
  #   result.error     # => "Network error"
  #
  # @!attribute [r] success
  #   @return [Boolean] Whether the sync operation succeeded
  #
  # @!attribute [r] changes
  #   @return [Boolean] Whether the sync resulted in changes (default: false)
  #
  # @!attribute [r] error
  #   @return [String, nil] Error message if sync failed (default: nil)
  #
  SyncResult = Data.define(:success, :changes, :error) do
    # Creates a new SyncResult with sensible defaults.
    #
    # @param success [Boolean] Whether the sync succeeded
    # @param changes [Boolean] Whether changes occurred (default: false)
    # @param error [String, nil] Error message if failed (default: nil)
    #
    def initialize(success:, changes: false, error: nil)
      super
    end

    # @return [Boolean] Whether the sync operation succeeded
    def success? = success

    # @return [Boolean] Whether the sync resulted in changes
    def changes? = changes
  end
end
