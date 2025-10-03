# frozen_string_literal: true

require 'active_record/base'

module Multidb
  module Connection
    def establish_connection(spec = nil)
      super(spec)
      config = connection_pool.db_config.configuration_hash

      Multidb.init(config)
    end

    def connection
      Multidb.balancer.current_connection
    rescue Multidb::NotInitializedError
      super
    end

    # Rails 7.2 compatibility: Override connection_handler to return the multidb candidate's handler
    # This prevents Rails from trying to use shard-aware lookups on the main handler
    def connection_handler
      Multidb.balancer.get(Multidb.balancer.current_connection_name).connection_handler
    rescue StandardError
      super
    end

    # Rails 7.2 compatibility: Override connection_pool to use multidb's handler
    def connection_pool
      connection_handler.retrieve_connection_pool('ActiveRecord::Base')
    rescue StandardError
      super
    end
  end

  module ModelExtensions
    extend ActiveSupport::Concern

    included do
      class << self
        prepend Multidb::Connection
      end
    end
  end
end

ActiveRecord::Base.class_eval do
  include Multidb::ModelExtensions
end
